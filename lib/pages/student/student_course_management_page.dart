import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/student_course_models.dart';
import '../../models/student_grade_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/student_api_service.dart';
import 'student_theme.dart';
import 'widgets/student_assistant_chat_sheet.dart';
import 'widgets/student_notification_dropdown.dart';

class StudentCourseManagementPage extends StatefulWidget {
  const StudentCourseManagementPage({
    super.key,
    required this.studentApi,
    required this.initialCourses,
    required this.initialGrades,
    this.onChanged,
    this.onViewAllNotifications,
  });

  final StudentApiService studentApi;
  final StudentCourseData initialCourses;
  final StudentGradeTranscriptData initialGrades;
  final Future<void> Function()? onChanged;
  final VoidCallback? onViewAllNotifications;

  @override
  State<StudentCourseManagementPage> createState() =>
      _StudentCourseManagementPageState();
}

class _StudentCourseManagementPageState
    extends State<StudentCourseManagementPage> {
  late StudentCourseData _courseData;
  late StudentGradeTranscriptData _grades;
  String? _selectedSemesterId;
  final TextEditingController _searchController = TextEditingController();

  double _targetGpa = 4.0;
  String _searchQuery = '';
  String _sortBy = 'grade-desc';
  bool _isLinearFormula = false;
  bool _isLoading = false;
  bool _isSavingSemester = false;
  bool _isSaving = false;
  bool _isProjecting = false;
  int _reloadRequestId = 0;
  String? _projectionAdvice;
  Timer? _projectionDebounce;

  @override
  void initState() {
    super.initState();
    _courseData = widget.initialCourses;
    _grades = widget.initialGrades;
    _selectedSemesterId = widget.initialCourses.selectedSemesterId;
    final currentGpa = _grades.summary.cumulativeGpa;
    if (currentGpa != null && currentGpa > 0) {
      _targetGpa = currentGpa.clamp(0, 4).toDouble();
    }
    _reload(showLoader: false);
  }

  @override
  void dispose() {
    _projectionDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final courses = _filteredCourses;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primaryStrong),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quản lý học phần',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.text,
              ),
            ),
            Text(
              'Quản lý Học tập & GPA Học kỳ',
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primaryStrong,
                    ),
                  )
                : Icon(Icons.refresh, color: colors.primaryStrong),
            onPressed: _isLoading
                ? null
                : () {
                    _searchController.clear();
                    setState(() {
                      _targetGpa = 4.0;
                      _searchQuery = '';
                    });
                    _reload();
                  },
          ),
          IconButton(
            icon: Icon(
              Icons.tips_and_updates_outlined,
              color: colors.primaryStrong,
            ),
            onPressed: _showAdviceDialog,
          ),
          IconButton(
            tooltip: 'Trợ lý học tập',
            icon: Icon(
              Icons.forum_outlined,
              color: colors.primaryStrong,
            ),
            onPressed: _moTroLyChat,
          ),
          StudentNotificationBell(
            studentApi: widget.studentApi,
            onViewAll: widget.onViewAllNotifications,
            icon: Icons.notifications_outlined,
            iconColor: colors.primaryStrong,
            backgroundColor: Colors.transparent,
            borderColor: Colors.transparent,
            margin: const EdgeInsets.symmetric(vertical: 8),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        color: colors.primaryStrong,
        backgroundColor: colors.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SemesterOverviewCard(
                semesters: _courseData.semesters,
                selectedSemesterId: _selectedSemesterId,
                isSaving: _isSavingSemester,
                onAddSemester: _openSemesterModal,
                onSelectSemester: _changeSemester,
                onEditSemester: (semester) =>
                    _openSemesterModal(semester: semester),
                onDeleteSemester: _deleteSemester,
              ),
              const SizedBox(height: 18),
              _GpaDashboard(
                courses: _allManagedCourses,
                targetGpa: _targetGpa,
                isLinearFormula: _isLinearFormula,
                isProjecting: _isProjecting,
                backendAdvice: _projectionAdvice,
                onTargetGpaChanged: (value) {
                  setState(() => _targetGpa = value);
                  _scheduleProjection();
                },
                onFormulaToggle: (isLinear) {
                  setState(() => _isLinearFormula = isLinear);
                },
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Học phần dự án',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF89CEFF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_allManagedCourses.length} môn',
                      style: TextStyle(
                        color: colors.info,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.surfaceAlt.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: colors.text),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm học phần...',
                          hintStyle: TextStyle(
                            color: colors.textSubtle,
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: colors.textSubtle,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: DropdownButton<String>(
                      value: _sortBy,
                      dropdownColor: colors.surface,
                      style: TextStyle(color: colors.text, fontSize: 13),
                      underline: const SizedBox(),
                      icon: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.arrow_drop_down,
                          color: colors.textMuted,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'grade-desc',
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Điểm cao nhất',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'grade-asc',
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Điểm thấp nhất',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'credits-desc',
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Số tín chỉ',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _sortBy = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (courses.isEmpty)
                _EmptyCourseState(message: _courseData.message)
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: courses.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final course = courses[index];
                    return _CourseCard(
                      course: course,
                      index: index,
                      onTap: () => _openCourseModal(course),
                      onGradeTap: () => _openGradeModal(course),
                    );
                  },
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFC0C1FF),
        onPressed: _isSaving ? null : () => _openCourseModal(null),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1000A9),
                ),
              )
            : const Icon(Icons.add, color: Color(0xFF1000A9), size: 30),
      ),
    );
  }

  List<_ManagedCourse> get _allManagedCourses {
    final gradesByCourseId = {
      for (final grade in _grades.items) grade.id: grade,
    };

    return _courseData.items
        .map(
          (course) =>
              _ManagedCourse.fromBackend(course, gradesByCourseId[course.id]),
        )
        .toList();
  }

  List<_ManagedCourse> get _filteredCourses {
    final query = _searchQuery.trim().toLowerCase();
    final courses = _allManagedCourses.where((course) {
      if (query.isEmpty) {
        return true;
      }
      return course.name.toLowerCase().contains(query) ||
          course.code.toLowerCase().contains(query);
    }).toList();

    courses.sort((a, b) {
      if (_sortBy == 'grade-desc') {
        return b.averageGrade.compareTo(a.averageGrade);
      }
      if (_sortBy == 'grade-asc') {
        return a.averageGrade.compareTo(b.averageGrade);
      }
      if (_sortBy == 'credits-desc') {
        return b.credits.compareTo(a.credits);
      }
      return a.name.compareTo(b.name);
    });

    return courses;
  }

  Future<void> _reload({bool showLoader = true}) async {
    await _reloadSemesterData(showLoader: showLoader);
  }

  Future<bool> _reloadSemesterData({
    bool showLoader = true,
    String? semesterId,
  }) async {
    final requestId = ++_reloadRequestId;

    if (showLoader) {
      setState(() => _isLoading = true);
    }

    try {
      final selectedSemesterId = semesterId ?? _selectedSemesterId;
      StudentCourseData courses;
      try {
        courses = await widget.studentApi.listCourses(
          maHocKy: selectedSemesterId,
        );
      } on ApiException catch (error) {
        if (error.statusCode != 404 || selectedSemesterId == null) {
          rethrow;
        }
        courses = await widget.studentApi.listCourses();
      }
      final grades = await _loadGrades(courses.selectedSemesterId);

      if (!mounted) {
        return false;
      }

      if (requestId != _reloadRequestId) {
        return true;
      }

      setState(() {
        _courseData = courses;
        _selectedSemesterId = courses.selectedSemesterId;
        _grades =
            grades ??
            StudentGradeTranscriptData.empty(
              'Không thể tải bảng điểm của học kỳ này lúc này.',
            );
      });
      if (grades == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể tải bảng điểm lúc này, đang giữ dữ liệu hiện có.',
            ),
          ),
        );
      }
      _scheduleProjection();
      return true;
    } on ApiException catch (error) {
      if (!mounted) {
        return false;
      }

      if (requestId != _reloadRequestId) {
        return true;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return false;
    } finally {
      if (mounted && showLoader && requestId == _reloadRequestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<StudentGradeTranscriptData?> _loadGrades(String? semesterId) async {
    try {
      return await widget.studentApi.getGradeTranscript(maHocKy: semesterId);
    } on ApiException {
      return null;
    }
  }

  Future<void> _changeSemester(String semesterId) async {
    if (semesterId == _selectedSemesterId || _isLoading) {
      return;
    }

    final previousSemesterId = _selectedSemesterId;
    setState(() => _selectedSemesterId = semesterId);
    final didReload = await _reloadSemesterData(semesterId: semesterId);

    if (!didReload && mounted && _selectedSemesterId == semesterId) {
      setState(() => _selectedSemesterId = previousSemesterId);
    }
  }

  void _scheduleProjection() {
    _projectionDebounce?.cancel();
    final semesterId = _selectedSemesterId;
    if (semesterId == null || _allManagedCourses.isEmpty) {
      setState(() {
        _projectionAdvice = null;
        _isProjecting = false;
      });
      return;
    }

    _projectionDebounce = Timer(
      const Duration(milliseconds: 650),
      () => _loadProjection(semesterId),
    );
  }

  Future<void> _loadProjection(String semesterId) async {
    if (!mounted) {
      return;
    }
    setState(() => _isProjecting = true);
    try {
      final projection = await widget.studentApi.projectGpa(
        maHocKy: semesterId,
        targetGpa: _targetGpa,
      );
      if (!mounted) {
        return;
      }
      setState(() => _projectionAdvice = _projectionText(projection));
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _projectionAdvice = error.message);
    } finally {
      if (mounted) {
        setState(() => _isProjecting = false);
      }
    }
  }

  Future<void> _moTroLyChat() async {
    await StudentAssistantChatSheet.show(
      context,
      studentApi: widget.studentApi,
    );
  }

  String _projectionText(StudentGpaProjectionData projection) {
    if (projection.suggestions.isEmpty) {
      return projection.message;
    }

    final first = projection.suggestions.first;
    final minimumScore = projection.minimumScore10 == null
        ? ''
        : ' khoảng ${projection.minimumScore10!.toStringAsFixed(1)}/10';
    return '${projection.message} Ưu tiên ${first.courseName}: cần tối thiểu ${first.requiredScore.toStringAsFixed(1)} điểm thành phần$minimumScore.';
  }

  Future<void> _openCourseModal(_ManagedCourse? course) async {
    final result = await showModalBottomSheet<_CourseModalResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CourseModal(course: course),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.deleteCourseId != null && course != null) {
      await _deleteCourse(course);
      return;
    }

    final draft = result.draft;
    if (draft != null) {
      await _saveCourse(course, draft);
    }
  }

  Future<void> _openGradeModal(_ManagedCourse course) async {
    if (course.components.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Môn học này chưa có cấu hình trọng số, hãy cấu hình trước rồi mới nhập điểm.',
          ),
        ),
      );
      return;
    }

    if (course.needsGradeConfigWarning) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            course.isAutoCreatedFromScheduleImport
                ? 'Môn này được tạo tự động từ thời khóa biểu và đang dùng cấu hình điểm mặc định. Hãy rà soát lại trước khi nhập điểm.'
                : 'Môn này vẫn cần rà soát lại cấu hình điểm trước khi nhập điểm.',
          ),
        ),
      );
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _GradeEntryModal(course: course, studentApi: widget.studentApi),
    );

    if (saved == true && mounted) {
      await _reload(showLoader: false);
      await widget.onChanged?.call();
    }
  }

  Future<void> _openSemesterModal({StudentSemester? semester}) async {
    if (_isSavingSemester) {
      return;
    }

    final isEditing = semester != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: semester?.name ?? '');
    final startYearController = TextEditingController(
      text: _yearFromSemesterValue(semester?.startDate),
    );
    final endYearController = TextEditingController(
      text: _yearFromSemesterValue(semester?.endDate),
    );
    final colors = StudentThemeScope.colorsOf(context);

    try {
      final draft = await showDialog<_SemesterDraft>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: colors.surface,
            title: Text(
              isEditing ? 'Sửa học kỳ' : 'Thêm học kỳ',
              style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      style: TextStyle(color: colors.text),
                      decoration: _semesterInputDecoration(
                        'Tên học kỳ',
                        colors,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập tên học kỳ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: startYearController,
                      style: TextStyle(color: colors.text),
                      decoration: _semesterInputDecoration(
                        'Năm bắt đầu',
                        colors,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final year = int.tryParse((value ?? '').trim());
                        if (year == null || year < 1900 || year > 2100) {
                          return 'Vui lòng nhập năm bắt đầu hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: endYearController,
                      style: TextStyle(color: colors.text),
                      decoration: _semesterInputDecoration(
                        'Năm kết thúc',
                        colors,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final year = int.tryParse((value ?? '').trim());
                        if (year == null || year < 1900 || year > 2100) {
                          return 'Vui lòng nhập năm kết thúc hợp lệ';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  FocusManager.instance.primaryFocus?.unfocus();
                  await Future<void>.delayed(
                    const Duration(milliseconds: 120),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState?.validate() != true) {
                    return;
                  }
                  FocusManager.instance.primaryFocus?.unfocus();
                  final draft = _SemesterDraft(
                    name: nameController.text.trim(),
                    startYear: startYearController.text.trim(),
                    endYear: endYearController.text.trim(),
                  );
                  await Future<void>.delayed(
                    const Duration(milliseconds: 120),
                  );
                  if (context.mounted) {
                    Navigator.pop(context, draft);
                  }
                },
                child: Text(isEditing ? 'Lưu thay đổi' : 'Lưu học kỳ'),
              ),
            ],
          );
        },
      );

      if (!mounted || draft == null) {
        return;
      }

      setState(() => _isSavingSemester = true);
      try {
        final startDate = draft.startYear.isEmpty
            ? null
            : '${draft.startYear.trim()}-01-01';
        final endDate = draft.endYear.isEmpty
            ? null
            : '${draft.endYear.trim()}-12-31';
        if (isEditing) {
          await widget.studentApi.updateSemester(
            semesterId: semester.id,
            name: draft.name,
            startDate: startDate,
            endDate: endDate,
          );
          await _afterMutation('Cập nhật học kỳ thành công.');
        } else {
          final createdSemester = await widget.studentApi.createSemester(
            name: draft.name,
            startDate: startDate,
            endDate: endDate,
          );
          _selectedSemesterId = createdSemester.id;
          await _afterMutation('Tạo học kỳ thành công.');
        }
      } on ApiException catch (error) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } finally {
        if (mounted) {
          setState(() => _isSavingSemester = false);
        }
      }
    } finally {
      nameController.dispose();
      startYearController.dispose();
      endYearController.dispose();
    }
  }

  Future<void> _deleteSemester(
    StudentSemester semester, {
    bool force = false,
  }) async {
    if (!force) {
      final confirmed = await _confirmDeleteSemester(
        'Bạn có chắc muốn xóa học kỳ "${semester.name}"?',
      );
      if (confirmed != true) {
        return;
      }
    }

    setState(() => _isSavingSemester = true);
    try {
      await widget.studentApi.deleteSemester(semester.id, force: force);
      if (mounted && semester.id == _selectedSemesterId) {
        setState(() => _selectedSemesterId = null);
      }
      await _afterMutation('Xóa học kỳ thành công.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      final details = error.details;
      final canForceDelete =
          details is Map<String, dynamic> &&
          details['canForceDelete'] == true &&
          !force;

      if (canForceDelete) {
        final confirmed = await _confirmForceDelete(
          details['messageForUser'] as String? ?? error.message,
        );
        if (confirmed == true && mounted) {
          await _deleteSemester(semester, force: true);
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingSemester = false);
      }
    }
  }

  Future<bool?> _confirmDeleteSemester(String message) {
    final colors = StudentThemeScope.colorsOf(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Xóa học kỳ?',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
        ),
        content: Text(message, style: TextStyle(color: colors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Xóa',
              style: TextStyle(color: Color(0xFFFFB4AB)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCourse(_ManagedCourse? course, _CourseDraft draft) async {
    final semesterId = course?.semesterId ?? _selectedSemesterId;
    if (semesterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn cần có học kỳ trước khi thêm học phần.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final savedCourse = course == null
          ? await widget.studentApi.createCourse(
              semesterId: semesterId,
              name: draft.name,
              credits: draft.credits,
              code: draft.code,
            )
          : await widget.studentApi.updateCourse(
              courseId: course.id,
              semesterId: semesterId,
              name: draft.name,
              credits: draft.credits,
              code: draft.code,
            );

      await widget.studentApi.configureGradeWeights(
        courseId: savedCourse.id,
        components: [
          StudentGradeWeightInput(
            name: course?.attendanceComponentName ?? 'Chuyên cần',
            weight: draft.attendanceWeight,
          ),
          StudentGradeWeightInput(
            name: course?.midtermComponentName ?? 'Giữa kỳ',
            weight: draft.midtermWeight,
          ),
          StudentGradeWeightInput(
            name: course?.finalComponentName ?? 'Cuối kỳ',
            weight: draft.finalWeight,
          ),
        ],
      );

      await _afterMutation(
        course == null
            ? 'Thêm học phần thành công.'
            : 'Cập nhật học phần thành công.',
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteCourse(
    _ManagedCourse course, {
    bool force = false,
  }) async {
    setState(() => _isSaving = true);
    try {
      await widget.studentApi.deleteCourse(course.id, force: force);
      await _afterMutation('Xóa học phần thành công.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      final details = error.details;
      final canForceDelete =
          details is Map<String, dynamic> &&
          details['canForceDelete'] == true &&
          !force;

      if (canForceDelete) {
        final confirmed = await _confirmForceDelete(
          details['messageForUser'] as String? ?? error.message,
        );
        if (confirmed == true && mounted) {
          await _deleteCourse(course, force: true);
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _afterMutation(String message) async {
    await _reload(showLoader: false);
    await widget.onChanged?.call();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool?> _confirmForceDelete(String message) {
    final colors = StudentThemeScope.colorsOf(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Xóa học phần?',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
        ),
        content: Text(message, style: TextStyle(color: colors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Vẫn xóa',
              style: TextStyle(color: Color(0xFFFFB4AB)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAdviceDialog() {
    final fallbackAdvice =
        'Để duy trì GPA tốt và đạt mục tiêu, hãy tập trung rèn luyện chuyên cần và gỡ điểm các môn học trọng số thi cuối kỳ cao nhé.';
    final colors = StudentThemeScope.colorsOf(context);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Trung tâm tư vấn học tập',
          style: TextStyle(color: colors.text),
        ),
        content: Text(
          _projectionAdvice ?? fallbackAdvice,
          style: TextStyle(color: colors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng', style: TextStyle(color: colors.primaryStrong)),
          ),
        ],
      ),
    );
  }
}

class _GpaDashboard extends StatelessWidget {
  const _GpaDashboard({
    required this.courses,
    required this.targetGpa,
    required this.isLinearFormula,
    required this.isProjecting,
    required this.backendAdvice,
    required this.onTargetGpaChanged,
    required this.onFormulaToggle,
  });

  final List<_ManagedCourse> courses;
  final double targetGpa;
  final bool isLinearFormula;
  final bool isProjecting;
  final String? backendAdvice;
  final ValueChanged<double> onTargetGpaChanged;
  final ValueChanged<bool> onFormulaToggle;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    double totalCredits = 0;
    double totalWeighted4 = 0;
    double totalWeighted10 = 0;

    for (final course in courses) {
      final avg10 = course.averageGrade;
      final avg4 = isLinearFormula ? (avg10 / 10) * 4 : course.gpa4;
      totalWeighted4 += avg4 * course.credits;
      totalWeighted10 += avg10 * course.credits;
      totalCredits += course.credits;
    }

    final finalGpa4 = totalCredits > 0 ? totalWeighted4 / totalCredits : 0.0;
    final finalGpa10 = totalCredits > 0 ? totalWeighted10 / totalCredits : 0.0;

    String honorText = 'Trung bình';
    Color honorColor = colors.textMuted;
    if (finalGpa4 >= 3.6) {
      honorText = 'Xuất sắc';
      honorColor = colors.danger;
    } else if (finalGpa4 >= 3.2) {
      honorText = 'Giỏi';
      honorColor = colors.primaryStrong;
    } else if (finalGpa4 >= 2.5) {
      honorText = 'Khá';
      honorColor = colors.info;
    }

    const simulatedUpcomingCredits = 15.0;
    final totalSimulatedCredits = totalCredits + simulatedUpcomingCredits;
    final requiredUpcomingWeighted4 =
        targetGpa * totalSimulatedCredits - totalWeighted4;
    final requiredUpcomingAvg4 = simulatedUpcomingCredits > 0
        ? requiredUpcomingWeighted4 / simulatedUpcomingCredits
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.surfaceAlt.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onFormulaToggle(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isLinearFormula
                          ? colors.primaryStrong
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Tuyến tính (10/10)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isLinearFormula
                              ? colors.onPrimary
                              : colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => onFormulaToggle(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: !isLinearFormula
                          ? colors.primaryStrong
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Theo quy chế trường',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: !isLinearFormula
                              ? colors.onPrimary
                              : colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.tint(colors.primaryStrong, lightAlpha: 0.12),
                colors.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'GPA HIỆN TẠI',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: honorColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  honorText,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: honorColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          textBaseline: TextBaseline.alphabetic,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          children: [
                            Text(
                              finalGpa4.toStringAsFixed(2),
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: colors.primaryStrong,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/ 4.0',
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hệ 10: ${finalGpa10.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.info,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.tint(colors.primaryStrong),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.primaryStrong.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Icon(
                      Icons.trending_up,
                      color: colors.primaryStrong,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: colors.border),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mục tiêu học kỳ này',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted,
                    ),
                  ),
                  Text(
                    targetGpa.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: colors.primaryStrong,
                  inactiveTrackColor: colors.surfaceMuted,
                  thumbColor: colors.primaryStrong,
                  overlayColor: colors.primaryStrong.withValues(alpha: 0.2),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: targetGpa,
                  min: 0,
                  max: 4,
                  onChanged: (value) => onTargetGpaChanged(
                    double.parse(value.toStringAsFixed(2)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kéo để giả lập điểm trung bình mục tiêu',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                  if (isProjecting)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.danger,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (targetGpa > finalGpa4 || backendAdvice != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.tint(colors.danger, lightAlpha: 0.09),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.danger.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.school, color: colors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          backendAdvice ??
                              (requiredUpcomingAvg4 > 4
                                  ? 'Mục tiêu rất cao! Bạn cần đăng ký thêm học phần hoặc hạ mục tiêu kỳ này để đạt tích lũy mong muốn.'
                                  : 'Kế hoạch học tập: Để đạt $targetGpa, bạn cần đạt trung bình tối thiểu ${requiredUpcomingAvg4.toStringAsFixed(2)} / 4.0 (khoảng ${(requiredUpcomingAvg4 * 2.5).toStringAsFixed(1)}/10) cho 15 tín chỉ tiếp theo.'),
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.danger,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.index,
    required this.onTap,
    required this.onGradeTap,
  });

  final _ManagedCourse course;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onGradeTap;

  Color get _gradeColor {
    final avg = course.averageGrade;
    if (avg >= 8.5) {
      return const Color(0xFFFFAFD3);
    }
    if (avg >= 7) {
      return const Color(0xFFC0C1FF);
    }
    return const Color(0xFF89CEFF);
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final isOdd = (index + 1) % 2 != 0;
    final cardBorderRadius = isOdd
        ? const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(8),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(24),
          );

    return InkWell(
      onTap: onTap,
      borderRadius: cardBorderRadius,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: cardBorderRadius,
          border: Border.all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colors.border),
                          ),
                          child: Text(
                            course.code.isEmpty ? '--' : course.code,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${course.credits} tín chỉ',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.info,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    course.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                    ),
                  ),
                  if (course.needsGradeConfigWarning) ...[
                    const SizedBox(height: 8),
                    _CourseWarningChip(
                      isAutoCreatedFromScheduleImport:
                          course.isAutoCreatedFromScheduleImport,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniGradeTag(
                        label: 'CC',
                        grade: course.attendance,
                        color: const Color(0xFF10B981),
                      ),
                      _MiniGradeTag(
                        label: 'GK',
                        grade: course.midterm,
                        color: const Color(0xFF3B82F6),
                      ),
                      _MiniGradeTag(
                        label: 'CK',
                        grade: course.finalGrade,
                        color: const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  textBaseline: TextBaseline.alphabetic,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  children: [
                    Text(
                      course.averageGrade.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _gradeColor,
                      ),
                    ),
                    Text(
                      '/10',
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'ĐIỂM TỔNG KẾT',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onGradeTap,
                  icon: Icon(
                    Icons.edit_note,
                    size: 16,
                    color: colors.primaryStrong,
                  ),
                  label: Text(
                    'Nhập điểm',
                    style: TextStyle(
                      color: colors.primaryStrong,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseWarningChip extends StatelessWidget {
  const _CourseWarningChip({required this.isAutoCreatedFromScheduleImport});

  final bool isAutoCreatedFromScheduleImport;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.tint(colors.danger, lightAlpha: 0.12, darkAlpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: colors.danger),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              isAutoCreatedFromScheduleImport
                  ? 'Môn tạo từ TKB, hãy rà soát trọng số điểm'
                  : 'Môn này cần rà soát cấu hình điểm',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: colors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniGradeTag extends StatelessWidget {
  const _MiniGradeTag({
    required this.label,
    required this.grade,
    required this.color,
  });

  final String label;
  final double grade;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.tint(color, lightAlpha: 0.1, darkAlpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            grade.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseModal extends StatefulWidget {
  const _CourseModal({this.course});

  final _ManagedCourse? course;

  @override
  State<_CourseModal> createState() => _CourseModalState();
}

class _CourseModalState extends State<_CourseModal> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _code;
  late int _credits;
  late double _attendanceWeight;
  late double _midtermWeight;
  late double _finalWeight;

  @override
  void initState() {
    super.initState();
    _name = widget.course?.name ?? '';
    _code = widget.course?.code ?? '';
    _credits = widget.course?.credits ?? 3;
    _attendanceWeight = widget.course?.attendanceWeight ?? 10;
    _midtermWeight = widget.course?.midtermWeight ?? 30;
    _finalWeight = widget.course?.finalWeight ?? 60;
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final totalWeight = _attendanceWeight + _midtermWeight + _finalWeight;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderStrong,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.course != null
                        ? 'Cập nhật trọng số học phần'
                        : 'Thêm môn học mới',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.primaryStrong,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.tint(colors.primaryStrong, lightAlpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tổng trọng số',
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${totalWeight.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: colors.danger,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Cơ cấu trọng số hiện tại',
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_attendanceWeight.toStringAsFixed(0)}% - ${_midtermWeight.toStringAsFixed(0)}% - ${_finalWeight.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _name,
                style: TextStyle(color: colors.text),
                decoration: _modalInputDecoration('Tên học phần'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên học phần';
                  }
                  return null;
                },
                onSaved: (value) => _name = value!.trim(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _code,
                      style: TextStyle(color: colors.text),
                      decoration: _modalInputDecoration('Mã môn học'),
                      onSaved: (value) =>
                          _code = (value ?? '').trim().toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _credits.toString(),
                      style: TextStyle(color: colors.text),
                      keyboardType: TextInputType.number,
                      decoration: _modalInputDecoration('Số tín chỉ'),
                      validator: (value) {
                        final credits = int.tryParse(value ?? '');
                        if (credits == null || credits <= 0 || credits > 30) {
                          return 'Tín chỉ 1-30';
                        }
                        return null;
                      },
                      onSaved: (value) =>
                          _credits = int.tryParse(value ?? '') ?? 3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Trọng số thành phần',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryStrong,
                ),
              ),
              const SizedBox(height: 12),
              _buildSliderRow('Chuyên cần (%)', _attendanceWeight, (value) {
                setState(() => _attendanceWeight = value);
              }),
              const SizedBox(height: 12),
              _buildSliderRow('Giữa kỳ (%)', _midtermWeight, (value) {
                setState(() => _midtermWeight = value);
              }),
              const SizedBox(height: 12),
              _buildSliderRow('Cuối kỳ (%)', _finalWeight, (value) {
                setState(() => _finalWeight = value);
              }),
              const SizedBox(height: 8),
              Text(
                'Tổng hiện tại: ${totalWeight.toStringAsFixed(1)}%',
                style: TextStyle(color: colors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'Lưu học phần',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primaryStrong,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
              if (widget.course != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      _CourseModalResult.delete(widget.course!.id),
                    ),
                    icon: Icon(Icons.delete_outline, color: colors.danger),
                    label: Text(
                      'Xóa môn học này',
                      style: TextStyle(color: colors.danger),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.danger, width: 0.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _modalInputDecoration(String label) {
    final colors = StudentThemeScope.colorsOf(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.textMuted),
      filled: true,
      fillColor: colors.surfaceAlt.withValues(alpha: 0.75),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.primaryStrong, width: 1.2),
      ),
      errorStyle: TextStyle(color: colors.danger, fontSize: 11),
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    final colors = StudentThemeScope.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colors.info,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colors.info,
            thumbColor: colors.info,
            trackHeight: 2,
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final totalWeight = _attendanceWeight + _midtermWeight + _finalWeight;
    if ((totalWeight - 100).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tổng trọng số phải bằng 100%')),
      );
      return;
    }
    _formKey.currentState!.save();
    Navigator.pop(
      context,
      _CourseModalResult.save(
        _CourseDraft(
          code: _code,
          name: _name,
          credits: _credits,
          attendanceWeight: _attendanceWeight,
          midtermWeight: _midtermWeight,
          finalWeight: _finalWeight,
        ),
      ),
    );
  }
}

class _EmptyCourseState extends StatelessWidget {
  const _EmptyCourseState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        message,
        style: TextStyle(color: colors.textMuted, fontSize: 13),
      ),
    );
  }
}

class _ManagedCourse {
  const _ManagedCourse({
    required this.id,
    required this.semesterId,
    required this.code,
    required this.name,
    required this.credits,
    required this.semesterName,
    required this.isAutoCreatedFromScheduleImport,
    required this.needsGradeConfigWarning,
    required this.components,
    required this.attendance,
    required this.midterm,
    required this.finalGrade,
    required this.attendanceWeight,
    required this.midtermWeight,
    required this.finalWeight,
    required this.attendanceComponentName,
    required this.midtermComponentName,
    required this.finalComponentName,
    required this.backendAverage10,
    required this.backendGpa4,
  });

  final String id;
  final String semesterId;
  final String code;
  final String name;
  final int credits;
  final String semesterName;
  final bool isAutoCreatedFromScheduleImport;
  final bool needsGradeConfigWarning;
  final List<StudentGradeComponent> components;
  final double attendance;
  final double midterm;
  final double finalGrade;
  final double attendanceWeight;
  final double midtermWeight;
  final double finalWeight;
  final String attendanceComponentName;
  final String midtermComponentName;
  final String finalComponentName;
  final double? backendAverage10;
  final double? backendGpa4;

  double get averageGrade {
    if (backendAverage10 != null) {
      return backendAverage10!;
    }

    final totalWeight = attendanceWeight + midtermWeight + finalWeight;
    if (totalWeight <= 0) {
      return 0;
    }

    return ((attendance * attendanceWeight) +
            (midterm * midtermWeight) +
            (finalGrade * finalWeight)) /
        totalWeight;
  }

  double get gpa4 => backendGpa4 ?? _convert10To4(averageGrade);

  factory _ManagedCourse.fromBackend(
    StudentCourseItem course,
    StudentGradeCourse? grade,
  ) {
    final components = grade?.components ?? const <StudentGradeComponent>[];
    final attendance = _findComponent(components, _isAttendanceComponent);
    final midterm = _findComponent(components, _isMidtermComponent);
    final finalScore = _findComponent(components, _isFinalComponent);

    return _ManagedCourse(
      id: course.id,
      semesterId: course.semesterId,
      code: course.code ?? '',
      name: course.name,
      credits: course.credits,
      semesterName: course.semesterName,
      isAutoCreatedFromScheduleImport: course.isAutoCreatedFromScheduleImport,
      needsGradeConfigWarning: course.needsGradeConfigWarning,
      components: components,
      attendance: attendance?.score ?? 0,
      midterm: midterm?.score ?? 0,
      finalGrade: finalScore?.score ?? 0,
      attendanceWeight: attendance?.weight ?? 10,
      midtermWeight: midterm?.weight ?? 30,
      finalWeight: finalScore?.weight ?? 60,
      attendanceComponentName: attendance?.name ?? 'Chuyên cần',
      midtermComponentName: midterm?.name ?? 'Giữa kỳ',
      finalComponentName: finalScore?.name ?? 'Cuối kỳ',
      backendAverage10: grade?.result.finalScore10,
      backendGpa4: grade?.result.score4,
    );
  }
}

class _CourseDraft {
  const _CourseDraft({
    required this.code,
    required this.name,
    required this.credits,
    required this.attendanceWeight,
    required this.midtermWeight,
    required this.finalWeight,
  });

  final String code;
  final String name;
  final int credits;
  final double attendanceWeight;
  final double midtermWeight;
  final double finalWeight;
}

class _CourseModalResult {
  const _CourseModalResult._({this.draft, this.deleteCourseId});

  final _CourseDraft? draft;
  final String? deleteCourseId;

  factory _CourseModalResult.save(_CourseDraft draft) {
    return _CourseModalResult._(draft: draft);
  }

  factory _CourseModalResult.delete(String courseId) {
    return _CourseModalResult._(deleteCourseId: courseId);
  }
}

class _GradeEntryModal extends StatefulWidget {
  const _GradeEntryModal({required this.course, required this.studentApi});

  final _ManagedCourse course;
  final StudentApiService studentApi;

  @override
  State<_GradeEntryModal> createState() => _GradeEntryModalState();
}

class _GradeEntryModalState extends State<_GradeEntryModal> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final component in _sortedComponents(widget.course.components)) {
      _controllers[component.id] = TextEditingController(
        text: component.score?.toStringAsFixed(1) ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final components = _sortedComponents(widget.course.components);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderStrong,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nhập điểm thành phần',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.primaryStrong,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textMuted),
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Chỉ nhập điểm, trọng số đã được cấu hình riêng.',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ...components.map((component) {
                final controller = _controllers[component.id]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              component.name,
                              style: TextStyle(
                                color: colors.text,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Trọng số: ${component.weight.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          enabled: !_isSaving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(color: colors.text),
                          decoration: _gradeInputDecoration('Điểm', colors),
                          validator: (value) {
                            final parsed = double.tryParse(
                              (value ?? '').trim(),
                            );
                            if (parsed == null || parsed < 0 || parsed > 10) {
                              return '0-10';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isSaving ? 'Đang lưu...' : 'Lưu điểm',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primaryStrong,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<StudentGradeComponent> _sortedComponents(
    List<StudentGradeComponent> components,
  ) {
    final priority = <String, int>{'Chuyên cần': 0, 'Giữa kỳ': 1, 'Cuối kỳ': 2};

    final sorted = [...components];
    sorted.sort((left, right) {
      final leftPriority = priority[left.name.trim()] ?? 99;
      final rightPriority = priority[right.name.trim()] ?? 99;

      if (leftPriority != rightPriority) {
        return leftPriority.compareTo(rightPriority);
      }

      return left.name.compareTo(right.name);
    });

    return sorted;
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      for (final component in widget.course.components) {
        final value = double.parse(_controllers[component.id]!.text.trim());
        if (component.id.isNotEmpty) {
          await widget.studentApi.updateGradeComponent(
            componentId: component.id,
            score: value,
          );
        } else {
          await widget.studentApi.createGradeComponent(
            courseId: widget.course.id,
            name: component.name,
            weight: component.weight,
            score: value,
          );
        }
      }

      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _gradeInputDecoration(
    String label,
    StudentThemeColors colors,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.textMuted),
      filled: true,
      fillColor: colors.surfaceAlt.withValues(alpha: 0.75),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.primaryStrong, width: 1.2),
      ),
      errorStyle: TextStyle(color: colors.danger, fontSize: 11),
    );
  }
}

InputDecoration _semesterInputDecoration(
  String label,
  StudentThemeColors colors,
) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: colors.textMuted),
    filled: true,
    fillColor: colors.surfaceAlt.withValues(alpha: 0.75),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.primaryStrong, width: 1.2),
    ),
    errorStyle: TextStyle(color: colors.danger, fontSize: 11),
  );
}

class _SemesterDraft {
  const _SemesterDraft({
    required this.name,
    required this.startYear,
    required this.endYear,
  });

  final String name;
  final String startYear;
  final String endYear;
}

class _SemesterOverviewCard extends StatelessWidget {
  const _SemesterOverviewCard({
    required this.semesters,
    required this.selectedSemesterId,
    required this.isSaving,
    required this.onAddSemester,
    required this.onSelectSemester,
    required this.onEditSemester,
    required this.onDeleteSemester,
  });

  final List<StudentSemester> semesters;
  final String? selectedSemesterId;
  final bool isSaving;
  final VoidCallback onAddSemester;
  final ValueChanged<String> onSelectSemester;
  final ValueChanged<StudentSemester> onEditSemester;
  final ValueChanged<StudentSemester> onDeleteSemester;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final selectedSemester = semesters.isEmpty
        ? null
        : semesters.firstWhere(
            (item) => item.id == selectedSemesterId,
            orElse: () => semesters.first,
          );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Học kỳ',
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      semesters.isEmpty
                          ? 'Chưa có học kỳ nào. Thêm học kỳ trước để bắt đầu thêm môn học.'
                          : selectedSemester == null
                          ? 'Đã có ${semesters.length} học kỳ.'
                          : 'Đang dùng: ${selectedSemester.name}',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: isSaving ? null : onAddSemester,
                icon: isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Thêm học kỳ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primaryStrong,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
          if (semesters.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: semesters.map((semester) {
                final isSelected = semester.id == selectedSemesterId;
                return InkWell(
                  onTap: () => onSelectSemester(semester.id),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primaryStrong.withValues(alpha: 0.12)
                          : colors.surfaceAlt.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? colors.primaryStrong
                            : colors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              semester.name,
                              style: TextStyle(
                                color: colors.text,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: isSaving
                                  ? null
                                  : () => onEditSemester(semester),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 15,
                                  color: colors.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            InkWell(
                              onTap: isSaving
                                  ? null
                                  : () => onDeleteSemester(semester),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.delete_outline,
                                  size: 15,
                                  color: colors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _semesterDateRange(semester),
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

String _semesterDateRange(StudentSemester semester) {
  final start = semester.startDate?.trim();
  final end = semester.endDate?.trim();
  if ((start == null || start.isEmpty) && (end == null || end.isEmpty)) {
    return 'Chưa có ngày';
  }
  if (start == null || start.isEmpty) {
    return 'Đến ${_yearFromSemesterValue(end)}';
  }
  if (end == null || end.isEmpty) {
    return 'Từ ${_yearFromSemesterValue(start)}';
  }
  return '${_yearFromSemesterValue(start)} - ${_yearFromSemesterValue(end)}';
}

String _yearFromSemesterValue(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.length >= 4) {
    return trimmed.substring(0, 4);
  }
  return trimmed;
}

StudentGradeComponent? _findComponent(
  List<StudentGradeComponent> components,
  bool Function(String normalizedName) test,
) {
  for (final component in components) {
    if (test(_normalizeComponentName(component.name))) {
      return component;
    }
  }
  return null;
}

String _normalizeComponentName(String value) {
  return value.toLowerCase().trim();
}

bool _isAttendanceComponent(String value) {
  return value == 'cc' ||
      value.contains('chuyên') ||
      value.contains('chuyen') ||
      value.contains('attendance');
}

bool _isMidtermComponent(String value) {
  return value == 'gk' ||
      value.contains('giữa') ||
      value.contains('giua') ||
      value.contains('mid');
}

bool _isFinalComponent(String value) {
  return value == 'ck' ||
      value.contains('cuối') ||
      value.contains('cuoi') ||
      value.contains('final');
}

double _convert10To4(double score10) {
  if (score10 >= 8.5) {
    return 4;
  }
  if (score10 >= 8) {
    return 3.5;
  }
  if (score10 >= 7) {
    return 3;
  }
  if (score10 >= 6.5) {
    return 2.5;
  }
  if (score10 >= 5.5) {
    return 2;
  }
  if (score10 >= 5) {
    return 1.5;
  }
  if (score10 >= 4) {
    return 1;
  }
  return 0;
}
