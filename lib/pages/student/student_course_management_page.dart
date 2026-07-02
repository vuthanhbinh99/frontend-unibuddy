import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/student_course_models.dart';
import '../../models/student_grade_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/student_api_service.dart';
import 'student_theme.dart';
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
  final TextEditingController _searchController = TextEditingController();

  double _targetGpa = 4.0;
  String _searchQuery = '';
  String _sortBy = 'grade-desc';
  bool _isLinearFormula = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isProjecting = false;
  String? _projectionAdvice;
  Timer? _projectionDebounce;

  @override
  void initState() {
    super.initState();
    _courseData = widget.initialCourses;
    _grades = widget.initialGrades;
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
    if (showLoader) {
      setState(() => _isLoading = true);
    }
    try {
      final selectedSemesterId = _courseData.selectedSemesterId;
      final courses = await widget.studentApi.listCourses(
        maHocKy: selectedSemesterId,
      );
      final grades = await _loadGrades(courses.selectedSemesterId);

      if (!mounted) {
        return;
      }
      setState(() {
        _courseData = courses;
        _grades = grades;
      });
      _scheduleProjection();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted && showLoader) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<StudentGradeTranscriptData> _loadGrades(String? semesterId) async {
    try {
      return await widget.studentApi.getGradeTranscript(maHocKy: semesterId);
    } on ApiException catch (error) {
      return StudentGradeTranscriptData.empty(error.message);
    }
  }

  void _scheduleProjection() {
    _projectionDebounce?.cancel();
    final semesterId = _courseData.selectedSemesterId;
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

  Future<void> _saveCourse(_ManagedCourse? course, _CourseDraft draft) async {
    final semesterId = course?.semesterId ?? _courseData.selectedSemesterId;
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
            weight: 10,
            score: draft.attendance,
          ),
          StudentGradeWeightInput(
            name: course?.midtermComponentName ?? 'Giữa kỳ',
            weight: 30,
            score: draft.midterm,
          ),
          StudentGradeWeightInput(
            name: course?.finalComponentName ?? 'Cuối kỳ',
            weight: 60,
            score: draft.finalGrade,
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
                        'Mẫu ĐH Việt Nam',
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
  });

  final _ManagedCourse course;
  final int index;
  final VoidCallback onTap;

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
              ],
            ),
          ],
        ),
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
  late double _attendance;
  late double _midterm;
  late double _finalGrade;

  @override
  void initState() {
    super.initState();
    _name = widget.course?.name ?? '';
    _code = widget.course?.code ?? '';
    _credits = widget.course?.credits ?? 3;
    _attendance = widget.course?.attendance ?? 10;
    _midterm = widget.course?.midterm ?? 8;
    _finalGrade = widget.course?.finalGrade ?? 8;
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final computedAverage =
        (_attendance * 0.1) + (_midterm * 0.3) + (_finalGrade * 0.6);

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
                        ? 'Cập nhật học phần'
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
                          'Điểm tổng kết ước tính',
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          computedAverage.toStringAsFixed(1),
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
                          'Cơ cấu trọng số',
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '10% - 30% - 60%',
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
                'Điểm số thành phần',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryStrong,
                ),
              ),
              const SizedBox(height: 12),
              _buildSliderRow('Chuyên cần (10%)', _attendance, (value) {
                setState(() => _attendance = value);
              }),
              const SizedBox(height: 12),
              _buildSliderRow('Giữa kỳ (30%)', _midterm, (value) {
                setState(() => _midterm = value);
              }),
              const SizedBox(height: 12),
              _buildSliderRow('Cuối kỳ (60%)', _finalGrade, (value) {
                setState(() => _finalGrade = value);
              }),
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
            max: 10,
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
    _formKey.currentState!.save();
    Navigator.pop(
      context,
      _CourseModalResult.save(
        _CourseDraft(
          code: _code,
          name: _name,
          credits: _credits,
          attendance: _attendance,
          midterm: _midterm,
          finalGrade: _finalGrade,
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
    required this.attendance,
    required this.midterm,
    required this.finalGrade,
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
  final double attendance;
  final double midterm;
  final double finalGrade;
  final String attendanceComponentName;
  final String midtermComponentName;
  final String finalComponentName;
  final double? backendAverage10;
  final double? backendGpa4;

  double get averageGrade =>
      backendAverage10 ??
      (attendance * 0.1) + (midterm * 0.3) + (finalGrade * 0.6);

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
      attendance: attendance?.score ?? 0,
      midterm: midterm?.score ?? 0,
      finalGrade: finalScore?.score ?? 0,
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
    required this.attendance,
    required this.midterm,
    required this.finalGrade,
  });

  final String code;
  final String name;
  final int credits;
  final double attendance;
  final double midterm;
  final double finalGrade;
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
