import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/student_course_models.dart';
import '../../../models/student_grade_models.dart';
import '../../../services/api/core/api_exception.dart';
import '../../../services/api/modules/student/student_api_service.dart';
import '../theme/student_theme.dart';
import '../widgets/student_assistant_chat_sheet.dart';
import '../widgets/student_notification_dropdown.dart';
part 'student_course_management_widgets.dart';
part 'student_course_overview_widgets.dart';
part 'student_course_form_sheet.dart';
part 'student_course_grade_sheet.dart';
part 'student_course_semester_widgets.dart';
part 'student_course_management_actions.dart';

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

  /// Khởi tạo state ban đầu và đăng ký dữ liệu/listener cần thiết cho màn hình.
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

  /// Giải phóng controller, listener hoặc tài nguyên khi widget bị hủy.
  @override
  void dispose() {
    _projectionDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Xử lý thao tác update course state và đồng bộ kết quả với UI.
  void _updateCourseState(VoidCallback fn) {
    setState(fn);
  }

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
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
            icon: Icon(Icons.forum_outlined, color: colors.primaryStrong),
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

  /// Tải hoặc lấy dữ liệu reload để cập nhật UI.
  Future<void> _reload({bool showLoader = true}) async {
    await _reloadSemesterData(showLoader: showLoader);
  }

  /// Tải hoặc lấy dữ liệu reload semester data để cập nhật UI.
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

  /// Tải hoặc lấy dữ liệu load grades để cập nhật UI.
  Future<StudentGradeTranscriptData?> _loadGrades(String? semesterId) async {
    try {
      return await widget.studentApi.getGradeTranscript(maHocKy: semesterId);
    } on ApiException {
      return null;
    }
  }

  /// Xử lý sự kiện change semester từ người dùng hoặc hệ thống.
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

  /// Xử lý thao tác schedule projection và đồng bộ kết quả với UI.
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

  /// Tải hoặc lấy dữ liệu load projection để cập nhật UI.
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

  /// Thực hiện tác vụ bất đồng bộ mo tro ly chat cho màn hình hiện tại.
  Future<void> _moTroLyChat() async {
    await StudentAssistantChatSheet.show(
      context,
      studentApi: widget.studentApi,
    );
  }

  /// Hàm hỗ trợ projection text cho màn hình trong file này.
  String _projectionText(StudentGpaProjectionData projection) {
    final parts = <String>[projection.message];
    if (projection.remainingCredits > 0 &&
        projection.requiredGpaPerCredit != null) {
      final score10 = projection.minimumScore10 == null
          ? ''
          : ' (khoảng ${projection.minimumScore10!.toStringAsFixed(1)}/10)';
      parts.add(
        'Còn ${projection.remainingCredits} tín chỉ cần trung bình ${projection.requiredGpaPerCredit!.toStringAsFixed(2)}/4.0$score10.',
      );
    }

    if (projection.suggestions.isEmpty) {
      return parts.join('\n');
    }

    parts.add('Chi tiết từng môn:');
    parts.addAll(
      projection.suggestions.map(
        (item) => _formatProjectionSuggestion(item, projection),
      ),
    );
    return parts.join('\n');
  }

  /// Tạo giá trị hiển thị format projection suggestion dùng trong giao diện.
  String _formatProjectionSuggestion(
    StudentGpaProjectionSuggestion item,
    StudentGpaProjectionData projection,
  ) {
    final code = item.courseCode == null || item.courseCode!.trim().isEmpty
        ? ''
        : '${item.courseCode!.trim()} - ';
    final credits = item.credits > 0 ? ' (${item.credits} tín chỉ)' : '';
    final requiredGpa = projection.requiredGpaPerCredit;

    if (requiredGpa != null && requiredGpa > 4) {
      final maxGpa = projection.maxPossibleGpa == null
          ? ''
          : ' Dù môn này đạt 10.0/10, GPA tối đa học kỳ chỉ ${projection.maxPossibleGpa!.toStringAsFixed(2)}.';
      return '- $code${item.courseName}$credits: cần trung bình ${requiredGpa.toStringAsFixed(2)}/4.0 nên không khả thi.$maxGpa';
    }

    final letter = item.expectedLetter == null || item.expectedLetter!.isEmpty
        ? ''
        : ', mốc ${item.expectedLetter}';
    final targetScore = item.minimumScore10 == null
        ? ''
        : 'tổng kết tối thiểu ${item.minimumScore10!.toStringAsFixed(1)}/10$letter';
    final missingWeight = item.missingWeight == null
        ? ''
        : ' cho ${item.missingWeight!.toStringAsFixed(0)}% trọng số còn thiếu';
    final requiredPart = item.status == 'DA_DU_AN_TOAN'
        ? 'đã đủ an toàn với điểm hiện tại'
        : 'phần còn thiếu cần khoảng ${item.requiredScore.toStringAsFixed(1)}/10$missingWeight';
    final feasibleWarning = item.isFeasible
        ? ''
        : ' Mức này vượt quá 10/10 nên không khả thi với điểm hiện tại.';
    final warning = item.warning == null || item.warning!.isEmpty
        ? ''
        : ' (${item.warning})';
    final separator = targetScore.isEmpty ? '' : '; ';

    return '- $code${item.courseName}$credits: $targetScore$separator$requiredPart$feasibleWarning$warning.';
  }

  /// Hiển thị hoặc mở phần giao diện open course modal cho người dùng.
  Future<void> _openCourseModal(_ManagedCourse? course) async {
    final result = await showModalBottomSheet<_CourseModalResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CourseModal(
        course: course,
        onSave: (draft) => _saveCourse(course, draft, showErrorSnack: false),
      ),
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

  /// Hiển thị hoặc mở phần giao diện open grade modal cho người dùng.
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật điểm thành công.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
