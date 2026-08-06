import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/auth_models.dart' as auth;
import '../../models/student_course_models.dart';
import '../../models/student_deadline_models.dart';
import '../../models/student_grade_models.dart';
import '../../models/student_home_models.dart';
import '../../models/student_schedule_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/student_api_service.dart';
import '../../services/local/frontend_preferences_service.dart';
import '../../services/notifications/push_notification_service.dart';
import '../../l10n/app_localizations.dart';
import 'home_screen.dart';
import 'student_exam_management_page.dart';
import 'student_catalog_tab.dart';
import 'student_notifications_tab.dart';
import 'student_profile_tab.dart';
import 'student_settings_tab.dart';
import 'student_schedule_tab.dart';
import 'student_theme.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({
    super.key,
    required this.session,
    required this.studentApi,
    required this.pushService,
    required this.currentLanguageCode,
    required this.onLanguageChanged,
    required this.onLogout,
  });

  final auth.AuthSession session;
  final StudentApiService studentApi;
  final PushNotificationService pushService;
  final String currentLanguageCode;
  final ValueChanged<String> onLanguageChanged;
  final Future<void> Function() onLogout;

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  int _currentIndex = 0;
  bool _isImportingSchedule = false;
  bool _isSavingManualSchedule = false;
  late String _languageCode;
  late final FrontendPreferencesService _frontendPreferences;
  late final StudentThemeController _studentThemeController;
  late Future<StudentHomeData> _homeDataFuture;
  late Future<_ScheduleBundle> _scheduleBundleFuture;
  late Future<_CatalogBundle> _catalogBundleFuture;
  late Future<auth.PublicUser> _profileFuture;

  @override
  void initState() {
    super.initState();
    _frontendPreferences = FrontendPreferencesService();
    _studentThemeController = StudentThemeController(
      preferences: _frontendPreferences,
    );
    _languageCode = widget.currentLanguageCode;
    widget.studentApi.setAcceptLanguageCode(_languageCode);
    unawaited(_restoreFrontendPreferences());
    _reloadAll();
  }

  @override
  void dispose() {
    _studentThemeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StudentDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLanguageCode != widget.currentLanguageCode) {
      _languageCode = widget.currentLanguageCode;
      widget.studentApi.setAcceptLanguageCode(_languageCode);
    }
  }

  void _reloadAll() {
    _homeDataFuture = widget.studentApi.getStudentHomeData();
    _scheduleBundleFuture = _loadScheduleBundle();
    _catalogBundleFuture = _loadCatalogBundle();
    _profileFuture = widget.studentApi.getCurrentUser();
  }

  Future<void> _restoreFrontendPreferences() async {
    await _studentThemeController.loadSavedMode();
    final savedTabIndex = await _frontendPreferences
        .readStudentDashboardTabIndex();
    final savedLanguageCode = await _frontendPreferences
        .readStudentLanguageCode();
    if (!mounted) {
      return;
    }
    if (savedLanguageCode != null) {
      _languageCode = savedLanguageCode;
      widget.studentApi.setAcceptLanguageCode(savedLanguageCode);
    }
    if (savedTabIndex == null) {
      return;
    }
    if (savedTabIndex < 0 || savedTabIndex > 4) {
      return;
    }
    setState(() {
      _currentIndex = savedTabIndex;
      if (savedLanguageCode != null) {
        _languageCode = savedLanguageCode;
      }
    });
    if (savedLanguageCode != null) {
      widget.studentApi.setAcceptLanguageCode(savedLanguageCode);
    }
  }

  void _changeLanguage(String code) {
    if (code == _languageCode) {
      return;
    }
    setState(() => _languageCode = code);
    widget.studentApi.setAcceptLanguageCode(code);
    unawaited(_frontendPreferences.saveStudentLanguageCode(code));
    widget.onLanguageChanged(code);
  }

  void _selectTab(int index) {
    if (index < 0 || index > 4 || index == _currentIndex) {
      return;
    }
    setState(() => _currentIndex = index);
    unawaited(_frontendPreferences.saveStudentDashboardTabIndex(index));
  }

  Future<_ScheduleBundle> _loadScheduleBundle() async {
    final schedules = await widget.studentApi.listSchedules();
    final deadlines = await widget.studentApi.listDeadlines();
    return _ScheduleBundle(schedules: schedules, deadlines: deadlines);
  }

  Future<_CatalogBundle> _loadCatalogBundle() async {
    final courses = await widget.studentApi.listCourses();
    final grades = await _fallback(
      () => widget.studentApi.getGradeTranscript(
        maHocKy: courses.selectedSemesterId,
      ),
      StudentGradeTranscriptData.empty(),
    );
    return _CatalogBundle(courses: courses, grades: grades);
  }

  Future<void> _refreshHome() async {
    final next = widget.studentApi.getStudentHomeData();
    setState(() => _homeDataFuture = next);
    await next;
  }

  Future<void> _refreshSchedule() async {
    final next = _loadScheduleBundle();
    setState(() => _scheduleBundleFuture = next);
    await next;
  }

  Future<void> _refreshCatalog() async {
    final next = _loadCatalogBundle();
    setState(() => _catalogBundleFuture = next);
    await next;
  }

  Future<void> _refreshProfile() async {
    final next = widget.studentApi.getCurrentUser();
    setState(() => _profileFuture = next);
    await next;
  }

  Future<void> _refreshAcademicData() async {
    await _refreshStudentDashboardData(labelPrefix: 'academic');
  }

  Future<void> _refreshAfterScheduleImport() async {
    await _refreshStudentDashboardData(labelPrefix: 'schedule import');
  }

  Future<void> _refreshStudentDashboardData({
    required String labelPrefix,
  }) async {
    await Future.wait([
      _refreshFutureBestEffort<StudentHomeData>(
        label: '$labelPrefix home',
        loader: widget.studentApi.getStudentHomeData,
        assignFuture: (future) => _homeDataFuture = future,
      ),
      _refreshFutureBestEffort<_ScheduleBundle>(
        label: '$labelPrefix schedule',
        loader: _loadScheduleBundle,
        assignFuture: (future) => _scheduleBundleFuture = future,
      ),
      _refreshFutureBestEffort<_CatalogBundle>(
        label: '$labelPrefix catalog',
        loader: _loadCatalogBundle,
        assignFuture: (future) => _catalogBundleFuture = future,
      ),
    ]);
  }

  Future<void> _refreshFutureBestEffort<T>({
    required String label,
    required Future<T> Function() loader,
    required ValueChanged<Future<T>> assignFuture,
  }) async {
    try {
      final value = await loader();
      if (!mounted) {
        return;
      }
      setState(() => assignFuture(Future<T>.value(value)));
    } catch (error, stackTrace) {
      debugPrint(
        'Student dashboard refresh failed for $label: $error\n$stackTrace',
      );
    }
  }

  Future<void> _toggleDeadline(StudentDeadlineItem item) async {
    final nextStatus = item.completed
        ? StudentDeadlineStatus.todo
        : StudentDeadlineStatus.completed;
    await widget.studentApi.updateDeadlineStatus(
      deadlineId: item.id,
      status: nextStatus,
    );
    await _refreshSchedule();
    await _refreshHome();
  }

  void _openExamManagement() {
    Navigator.of(context).push(
      buildStudentThemedRoute<void>(
        controller: _studentThemeController,
        builder: (_) =>
            StudentExamManagementPage(studentApi: widget.studentApi),
      ),
    );
  }

  void _openNotifications() {
    _selectTab(3);
  }

  Future<void> _openProfile() async {
    final user = await _profileFuture;
    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      buildStudentThemedRoute<void>(
        controller: _studentThemeController,
        builder: (_) => StudentProfileTab(
          user: user,
          onLogout: widget.onLogout,
          onRefresh: _refreshProfile,
          studentApi: widget.studentApi,
          onViewAllNotifications: _openNotifications,
          showAppBar: true,
        ),
      ),
    );
  }

  Future<void> _importSchedule() async {
    final l10n = context.l10n;
    if (_isImportingSchedule) {
      return;
    }

    final pickedFile = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv', 'pdf'],
      withData: true,
    );
    if (!mounted || pickedFile == null || pickedFile.files.isEmpty) {
      return;
    }

    final file = pickedFile.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('student.dashboard.schedule.importReadError')),
        ),
      );
      return;
    }

    setState(() => _isImportingSchedule = true);
    try {
      final courses = await _fallback(
        () => widget.studentApi.listCourses(tatCa: true),
        StudentCourseData(
          message: l10n.t('student.dashboard.schedule.importNoCourses'),
          selectedSemesterId: null,
          semesters: [],
          items: [],
        ),
      );
      if (courses.semesters.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.tOr(
                'student.dashboard.schedule.importNoSemesters',
                fallbackVi: 'Bạn cần tạo học kỳ trước khi import TKB.',
                fallbackEn: 'Please create a semester before importing TKB.',
              ),
            ),
          ),
        );
        return;
      }

      final schedules = await widget.studentApi.listSchedules();
      if (!mounted) {
        return;
      }
      final semesterChoice = await _showScheduleImportSemesterDialog(
        courses: courses,
        schedules: schedules,
      );
      if (!mounted || semesterChoice == null) {
        return;
      }

      final headers = await widget.studentApi.extractScheduleImportHeaders(
        bytes: bytes,
        fileName: file.name,
      );
      var mapping = headers.suggestedMapping;
      try {
        mapping = await widget.studentApi.suggestScheduleImportMappingWithAi(
          headers: headers.headers,
          sampleRows: headers.rows.take(12).toList(),
        );
      } catch (error, stackTrace) {
        debugPrint('Schedule AI mapping fallback: $error\n$stackTrace');
        mapping = headers.suggestedMapping;
      }

      final preview = await widget.studentApi.previewScheduleImport(
        maHocKy: semesterChoice.semester.id,
        rows: headers.rows,
        mapping: mapping,
        replaceExistingCourseSchedules:
            semesterChoice.replaceExistingCourseSchedules,
      );

      if (!mounted) {
        return;
      }

      final confirmedPreview = await _showImportPreviewDialog(
        headers,
        preview,
        mapping: mapping,
        maHocKy: semesterChoice.semester.id,
        replaceExistingCourseSchedules:
            semesterChoice.replaceExistingCourseSchedules,
      );
      if (!mounted || confirmedPreview == null) {
        return;
      }

      final validItems = confirmedPreview.validItems;
      if (validItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.t('student.dashboard.schedule.importNoValidRows'),
            ),
          ),
        );
        return;
      }

      final result = await widget.studentApi.confirmScheduleImport(
        maHocKy: semesterChoice.semester.id,
        items: validItems,
        replaceExistingCourseSchedules:
            semesterChoice.replaceExistingCourseSchedules,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      await _refreshAfterScheduleImport();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error, stackTrace) {
      debugPrint('Schedule import failed: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('student.dashboard.schedule.importError')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isImportingSchedule = false);
      }
    }
  }

  Future<_ScheduleImportSemesterChoice?> _showScheduleImportSemesterDialog({
    required StudentCourseData courses,
    required StudentScheduleData schedules,
  }) {
    final l10n = context.l10n;
    final colors = _studentThemeController.colors;
    var selectedSemester = courses.semesters.firstWhere(
      (semester) => semester.id == courses.selectedSemesterId,
      orElse: () => courses.semesters.first,
    );

    int courseCount(String semesterId) {
      return courses.items
          .where((course) => course.semesterId == semesterId)
          .length;
    }

    int scheduleCount(String semesterId) {
      return schedules.items
          .where((schedule) => schedule.semesterId == semesterId)
          .length;
    }

    return showDialog<_ScheduleImportSemesterChoice>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedCourseCount = courseCount(selectedSemester.id);
            final selectedScheduleCount = scheduleCount(selectedSemester.id);
            final hasExistingAcademicData =
                selectedCourseCount > 0 || selectedScheduleCount > 0;

            return AlertDialog(
              backgroundColor: colors.surface,
              title: Text(
                l10n.tOr(
                  'student.dashboard.schedule.importSemesterTitle',
                  fallbackVi: 'Chọn học kỳ import',
                  fallbackEn: 'Choose import semester',
                ),
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedSemester.id,
                    isExpanded: true,
                    dropdownColor: colors.surface,
                    iconEnabledColor: colors.textMuted,
                    iconDisabledColor: colors.textSubtle,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: _manualInputDecoration(
                      l10n.tOr(
                        'student.dashboard.schedule.importSemesterLabel',
                        fallbackVi: 'Học kỳ',
                        fallbackEn: 'Semester',
                      ),
                      colors,
                    ),
                    items: courses.semesters
                        .map(
                          (semester) => DropdownMenuItem(
                            value: semester.id,
                            child: Text(
                              semester.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      final next = courses.semesters.firstWhere(
                        (semester) => semester.id == value,
                        orElse: () => selectedSemester,
                      );
                      setDialogState(() => selectedSemester = next);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.tOr(
                      'student.dashboard.schedule.importSemesterSummary',
                      fallbackVi:
                          'Đang có {courses} môn học và {schedules} lịch học.',
                      fallbackEn:
                          'Currently has {courses} courses and {schedules} schedules.',
                      arguments: {
                        'courses': selectedCourseCount,
                        'schedules': selectedScheduleCount,
                      },
                    ),
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                  if (hasExistingAcademicData) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.tOr(
                        'student.dashboard.schedule.importSemesterHasData',
                        fallbackVi:
                            'Học kỳ {semester} đã có môn học và lịch học cụ thể, bạn có muốn tiếp tục không?',
                        fallbackEn:
                            'Semester {semester} already has courses and detailed schedules. Do you want to continue?',
                        arguments: {'semester': selectedSemester.name},
                      ),
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    l10n.t('common.cancel'),
                    style: TextStyle(
                      color: colors.primaryStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(
                    _ScheduleImportSemesterChoice(
                      semester: selectedSemester,
                      replaceExistingCourseSchedules: hasExistingAcademicData,
                    ),
                  ),
                  child: Text(
                    hasExistingAcademicData
                        ? l10n.tOr(
                            'student.dashboard.schedule.importSemesterContinueWithReplace',
                            fallbackVi: 'Có, tiếp tục',
                            fallbackEn: 'Yes, continue',
                          )
                        : l10n.tOr(
                            'student.dashboard.schedule.importSemesterContinue',
                            fallbackVi: 'Tiếp tục',
                            fallbackEn: 'Continue',
                          ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<StudentScheduleImportPreviewData?> _showImportPreviewDialog(
    StudentScheduleImportHeadersData headers,
    StudentScheduleImportPreviewData preview, {
    required StudentScheduleImportMapping mapping,
    required String? maHocKy,
    required bool replaceExistingCourseSchedules,
  }) async {
    var currentPreview = preview;
    var currentMapping = mapping;

    while (mounted) {
      final result = await _showImportPreviewDialogStep(
        headers,
        currentPreview,
        mapping: currentMapping,
      );
      if (result is StudentScheduleImportPreviewData) {
        return result;
      }
      if (result is! _ScheduleImportMappingRefresh) {
        return null;
      }

      try {
        currentPreview = await widget.studentApi.previewScheduleImport(
          maHocKy: maHocKy,
          rows: headers.rows,
          mapping: result.mapping,
          replaceExistingCourseSchedules: replaceExistingCourseSchedules,
        );
        currentMapping = result.mapping;
      } on ApiException catch (error) {
        if (!mounted) {
          return null;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } catch (error, stackTrace) {
        debugPrint(
          'Schedule manual mapping preview failed: $error\n$stackTrace',
        );
        if (!mounted) {
          return null;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.t(
                'student.dashboard.schedule.importMappingPreviewError',
              ),
            ),
          ),
        );
      }
    }

    return null;
  }

  Future<Object?> _showImportPreviewDialogStep(
    StudentScheduleImportHeadersData headers,
    StudentScheduleImportPreviewData preview, {
    required StudentScheduleImportMapping mapping,
  }) {
    final l10n = context.l10n;
    final colors = _studentThemeController.colors;
    final currentPreview = preview;
    final selectedColumns = _scheduleMappingToSelections(mapping);

    final headerOptions = <String>[];
    for (final header in headers.headers) {
      if (!headerOptions.contains(header)) {
        headerOptions.add(header);
      }
    }
    for (final value in selectedColumns.values) {
      if (value != null && !headerOptions.contains(value)) {
        headerOptions.add(value);
      }
    }
    final invalidSamples = currentPreview.items
        .where((item) => !item.isValid && item.errors.isNotEmpty)
        .take(3)
        .toList();
    final canImport = currentPreview.validItems.isNotEmpty;

    return showDialog<Object?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            l10n.t('student.dashboard.schedule.importTitle'),
            style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${headers.sourceType} • ${headers.rows.length} dòng • ${headers.headers.length} cột',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ImportPreviewStat(
                    label: l10n.t('student.dashboard.schedule.importValidRows'),
                    value: currentPreview.validRows.toString(),
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(height: 8),
                  _ImportPreviewStat(
                    label: l10n.t(
                      'student.dashboard.schedule.importRowsToCheck',
                    ),
                    value: currentPreview.invalidRows.toString(),
                    color: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 8),
                  _ImportPreviewStat(
                    label: l10n.t(
                      'student.dashboard.schedule.importAutoCreatedCourses',
                    ),
                    value: currentPreview.autoCreateCourseRows.toString(),
                    color: const Color(0xFF818CF8),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.t(
                      'student.dashboard.schedule.importMappedColumnsTitle',
                    ),
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.t(
                      'student.dashboard.schedule.importMappedColumnsSubtitle',
                    ),
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  for (final field in _scheduleImportMappingFields(l10n))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ImportMappingSelector(
                        field: field,
                        headers: headerOptions,
                        selectedColumn: selectedColumns[field.key],
                        colors: colors,
                        onChanged: (value) {
                          selectedColumns[field.key] = value;
                        },
                      ),
                    ),
                  if (invalidSamples.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      l10n.t('student.dashboard.schedule.importSampleErrors'),
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...invalidSamples.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          l10n.t(
                            'student.dashboard.schedule.importRowError',
                            arguments: {
                              'row': item.rowIndex,
                              'errors': item.errors.join(', '),
                            },
                          ),
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l10n.t('common.cancel'),
                style: TextStyle(
                  color: colors.primaryStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                _ScheduleImportMappingRefresh(
                  _scheduleMappingFromSelections(selectedColumns),
                ),
              ),
              child: Text(
                l10n.t('student.dashboard.schedule.importMappingRefresh'),
                style: TextStyle(
                  color: colors.primaryStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primaryStrong,
                disabledBackgroundColor: colors.surfaceAlt,
                foregroundColor: colors.onPrimary,
                disabledForegroundColor: colors.textMuted,
              ),
              onPressed: canImport
                  ? () {
                      final selectedMapping = _scheduleMappingFromSelections(
                        selectedColumns,
                      );
                      if (!_scheduleMappingsEqual(mapping, selectedMapping)) {
                        Navigator.of(
                          context,
                        ).pop(_ScheduleImportMappingRefresh(selectedMapping));
                        return;
                      }
                      Navigator.of(context).pop(currentPreview);
                    }
                  : null,
              child: Text(
                l10n.t(
                  'student.dashboard.schedule.importDialogImport',
                  arguments: {'count': currentPreview.validItems.length},
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addScheduleManually() async {
    final l10n = context.l10n;
    if (_isSavingManualSchedule) {
      return;
    }

    try {
      final courses = await widget.studentApi.listCourses();
      if (!mounted) {
        return;
      }

      if (courses.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('student.dashboard.schedule.manualNoCourses')),
          ),
        );
        return;
      }

      final input = await _showManualScheduleDialog(courses.items);
      if (!mounted || input == null) {
        return;
      }

      setState(() => _isSavingManualSchedule = true);
      await widget.studentApi.createSchedule(
        courseId: input.courseId,
        dayOfWeek: input.dayOfWeek,
        startPeriod: input.startPeriod,
        periodCount: input.periodCount,
        room: input.room,
        startDate: input.startDate,
        endDate: input.endDate,
      );
      await _refreshSchedule();
      await _refreshHome();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('student.dashboard.schedule.manualSuccess')),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('student.dashboard.schedule.manualError')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingManualSchedule = false);
      }
    }
  }

  Future<void> _editSchedule(StudentScheduleItem item) async {
    final l10n = context.l10n;
    if (_isSavingManualSchedule) {
      return;
    }

    try {
      final courses = await widget.studentApi.listCourses();
      if (!mounted) {
        return;
      }

      if (courses.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('student.dashboard.schedule.manualNoCourses')),
          ),
        );
        return;
      }

      final input = await _showManualScheduleDialog(
        courses.items,
        initial: item,
      );
      if (!mounted || input == null) {
        return;
      }

      setState(() => _isSavingManualSchedule = true);
      await widget.studentApi.updateSchedule(
        scheduleId: item.id,
        courseId: input.courseId,
        dayOfWeek: input.dayOfWeek,
        startPeriod: input.startPeriod,
        periodCount: input.periodCount,
        room: input.room,
        startDate: input.startDate,
        endDate: input.endDate,
      );
      unawaited(_refreshSchedule());
      unawaited(_refreshHome());

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('student.dashboard.schedule.editSuccess')),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('student.dashboard.schedule.editError'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingManualSchedule = false);
      }
    }
  }

  Future<void> _deleteSchedule(StudentScheduleItem item) async {
    final l10n = context.l10n;
    final colors = _studentThemeController.colors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            l10n.t('student.dashboard.schedule.deleteTitle'),
            style: TextStyle(
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            l10n.t(
              'student.dashboard.schedule.deleteConfirm',
              arguments: {'course': item.courseName},
            ),
            style: TextStyle(color: colors.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('common.cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF809F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                l10n.t('student.dashboard.schedule.deleteConfirmAction'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.studentApi.deleteSchedule(scheduleId: item.id);
      await _refreshSchedule();
      await _refreshHome();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('student.dashboard.schedule.deleteSuccess')),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('student.dashboard.schedule.deleteError')),
        ),
      );
    }
  }

  Future<_ManualScheduleInput?> _showManualScheduleDialog(
    List<StudentCourseItem> courses, {
    StudentScheduleItem? initial,
  }) {
    final l10n = context.l10n;
    final colors = _studentThemeController.colors;

    return showDialog<_ManualScheduleInput>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => _ManualScheduleDialog(
        courses: courses,
        initial: initial,
        l10n: l10n,
        colors: colors,
      ),
    );
  }

  List<Widget> _buildScreens() {
    return [
      FutureBuilder<StudentHomeData>(
        future: _homeDataFuture,
        initialData: StudentHomeData.fromCurrentUser(widget.session.user),
        builder: (context, snapshot) {
          return RefreshIndicator(
            onRefresh: _refreshHome,
            child: HomeScreen(
              showAppBar: false,
              profile:
                  snapshot.data?.profile ??
                  StudentHomeData.fromCurrentUser(widget.session.user).profile,
              courses: snapshot.data?.courses ?? const [],
              projects: snapshot.data?.projects ?? const [],
              schedule: snapshot.data?.schedule ?? const [],
              onOpenExamManagement: _openExamManagement,
              onOpenProfile: _openProfile,
              onLogout: widget.onLogout,
            ),
          );
        },
      ),
      FutureBuilder<_ScheduleBundle>(
        future: _scheduleBundleFuture,
        builder: (context, snapshot) {
          final bundle = snapshot.data ?? _ScheduleBundle.empty();
          return FutureBuilder<_CatalogBundle>(
            future: _catalogBundleFuture,
            builder: (context, catalogSnapshot) {
              final catalog = catalogSnapshot.data ?? _CatalogBundle.empty();
              return StudentScheduleTab(
                data: bundle.schedules,
                deadlines: bundle.deadlines,
                onRefresh: _refreshAcademicData,
                onToggleDeadline: _toggleDeadline,
                onImportSchedule: _importSchedule,
                onAddScheduleManually: _addScheduleManually,
                onEditSchedule: _editSchedule,
                onDeleteSchedule: _deleteSchedule,
                studentApi: widget.studentApi,
                onViewAllNotifications: _openNotifications,
                isImportingSchedule: _isImportingSchedule,
                isSavingManualSchedule: _isSavingManualSchedule,
                preferredSemesterName: _selectedSemesterName(catalog.courses),
                semesterOptions: _semesterNames(catalog.courses),
              );
            },
          );
        },
      ),
      FutureBuilder<_CatalogBundle>(
        future: _catalogBundleFuture,
        builder: (context, snapshot) {
          final bundle = snapshot.data ?? _CatalogBundle.empty();
          return StudentCatalogTab(
            data: bundle.courses,
            grades: bundle.grades,
            currentUserId: widget.session.user.id,
            studentName: widget.session.user.fullName,
            studentMajor: widget.session.user.role.name,
            studentApi: widget.studentApi,
            onChangeTab: _selectTab,
            onAcademicDataChanged: _refreshAcademicData,
            onOpenExamManagement: _openExamManagement,
            onKanbanChanged: () => unawaited(_refreshHome()),
            onRefresh: _refreshCatalog,
          );
        },
      ),
      StudentNotificationsTab(studentApi: widget.studentApi),
      FutureBuilder<auth.PublicUser>(
        future: _profileFuture,
        initialData: widget.session.user,
        builder: (context, snapshot) {
          return StudentSettingsTab(
            user: snapshot.data ?? widget.session.user,
            studentApi: widget.studentApi,
            preferences: _frontendPreferences,
            pushService: widget.pushService,
            currentSessionRefreshToken: widget.session.refreshToken,
            isDarkMode: !_studentThemeController.isLight,
            currentLanguageCode: _languageCode,
            onToggleTheme: (value) {
              if (value != !_studentThemeController.isLight) {
                _studentThemeController.toggle();
              }
            },
            onLanguageChanged: _changeLanguage,
            onOpenProfile: _openProfile,
            onLogout: widget.onLogout,
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _studentThemeController,
      builder: (context, _) {
        final colors = _studentThemeController.colors;
        final screens = _buildScreens();
        return StudentThemeScope(
          controller: _studentThemeController,
          child: Theme(
            data: buildStudentMaterialTheme(colors),
            child: Scaffold(
              backgroundColor: colors.background,
              body: SafeArea(
                child: Stack(
                  children: [
                    Positioned(
                      top: -100,
                      left: -50,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primaryStrong.withValues(
                            alpha: colors.isLight ? 0.08 : 0.06,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 50,
                      right: -100,
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(
                            0xFF0EA5E9,
                          ).withValues(alpha: colors.isLight ? 0.08 : 0.04),
                        ),
                      ),
                    ),
                    IndexedStack(index: _currentIndex, children: screens),
                  ],
                ),
              ),
              bottomNavigationBar: _StudentBottomBar(
                currentIndex: _currentIndex,
                onSelected: _selectTab,
              ),
            ),
          ),
        );
      },
    );
  }

  List<String> _semesterNames(StudentCourseData courses) {
    final names = <String>{
      for (final semester in courses.semesters)
        if (semester.name.trim().isNotEmpty && semester.name.trim() != '--')
          semester.name.trim(),
    }.toList();
    names.sort();
    return names;
  }

  String? _selectedSemesterName(StudentCourseData courses) {
    final selectedId = courses.selectedSemesterId;
    if (selectedId == null) {
      return null;
    }
    for (final semester in courses.semesters) {
      if (semester.id == selectedId) {
        final name = semester.name.trim();
        return name.isEmpty || name == '--' ? null : name;
      }
    }
    return null;
  }

  Future<T> _fallback<T>(Future<T> Function() loader, T fallback) async {
    try {
      return await loader();
    } catch (_) {
      return fallback;
    }
  }
}

class _ManualScheduleInput {
  const _ManualScheduleInput({
    required this.courseId,
    required this.dayOfWeek,
    required this.startPeriod,
    required this.periodCount,
    required this.room,
    required this.startDate,
    required this.endDate,
  });

  final String courseId;
  final int dayOfWeek;
  final int startPeriod;
  final int periodCount;
  final String room;
  final String? startDate;
  final String? endDate;
}

class _ManualScheduleDialog extends StatefulWidget {
  const _ManualScheduleDialog({
    required this.courses,
    required this.l10n,
    required this.colors,
    this.initial,
  });

  final List<StudentCourseItem> courses;
  final StudentScheduleItem? initial;
  final AppLocalizationController l10n;
  final StudentThemeColors colors;

  @override
  State<_ManualScheduleDialog> createState() => _ManualScheduleDialogState();
}

class _ManualScheduleDialogState extends State<_ManualScheduleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _roomController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late String _selectedCourseId;
  late int _selectedDay;
  late int _selectedStartPeriod;
  late int _selectedPeriodCount;

  bool get _isEditing => widget.initial != null;

  bool get _periodIsValid =>
      _selectedStartPeriod + _selectedPeriodCount - 1 <= 12;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final hasInitialCourse =
        initial != null &&
        widget.courses.any((course) => course.id == initial.courseId);
    _selectedCourseId = hasInitialCourse
        ? initial.courseId
        : widget.courses.first.id;
    _selectedDay = initial?.dayOfWeek ?? 2;
    _selectedStartPeriod = initial?.startPeriod ?? 1;
    _selectedPeriodCount = initial?.periodCount ?? 3;
    _roomController = TextEditingController(text: initial?.room ?? '');
    _startDateController = TextEditingController(
      text: _dateInputValue(initial?.startDate),
    );
    _endDateController = TextEditingController(
      text: _dateInputValue(initial?.endDate),
    );
  }

  @override
  void dispose() {
    _roomController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _close([_ManualScheduleInput? input]) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(input);
    }
  }

  void _submit() {
    if (!_periodIsValid || _formKey.currentState?.validate() != true) {
      return;
    }

    unawaited(
      _close(
        _ManualScheduleInput(
          courseId: _selectedCourseId,
          dayOfWeek: _selectedDay,
          startPeriod: _selectedStartPeriod,
          periodCount: _selectedPeriodCount,
          room: _roomController.text,
          startDate: _normalizedDateOrNull(_startDateController.text),
          endDate: _normalizedDateOrNull(_endDateController.text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final colors = widget.colors;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(
            _isEditing ? Icons.edit_outlined : Icons.add_circle_outline,
            color: colors.primaryStrong,
          ),
          const SizedBox(width: 8),
          Text(
            l10n.t(
              _isEditing
                  ? 'student.dashboard.schedule.editTitle'
                  : 'student.dashboard.schedule.manualTitle',
            ),
            style: TextStyle(
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedCourseId,
                dropdownColor: colors.surface,
                iconEnabledColor: colors.textMuted,
                iconDisabledColor: colors.textSubtle,
                isExpanded: true,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _manualInputDecoration(
                  l10n.t('student.dashboard.schedule.manualCourse'),
                  colors,
                ),
                items: widget.courses.map((course) {
                  return DropdownMenuItem(
                    value: course.id,
                    child: Text(
                      course.code == null
                          ? course.name
                          : '${course.code} - ${course.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCourseId = value);
                  }
                },
                validator: (value) => value == null
                    ? l10n.t('student.dashboard.schedule.manualChooseCourse')
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _selectedDay,
                dropdownColor: colors.surface,
                iconEnabledColor: colors.textMuted,
                iconDisabledColor: colors.textSubtle,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _manualInputDecoration(
                  l10n.t('student.dashboard.schedule.manualDay'),
                  colors,
                ),
                items: _manualDayOptions(l10n).map((day) {
                  return DropdownMenuItem(
                    value: day.value,
                    child: Text(day.label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedDay = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedStartPeriod,
                      dropdownColor: colors.surface,
                      iconEnabledColor: colors.textMuted,
                      iconDisabledColor: colors.textSubtle,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _manualInputDecoration(
                        l10n.t('student.dashboard.schedule.manualStartPeriod'),
                        colors,
                      ),
                      items: List.generate(12, (index) => index + 1)
                          .map(
                            (period) => DropdownMenuItem(
                              value: period,
                              child: Text('$period'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedStartPeriod = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedPeriodCount,
                      dropdownColor: colors.surface,
                      iconEnabledColor: colors.textMuted,
                      iconDisabledColor: colors.textSubtle,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _manualInputDecoration(
                        l10n.t('student.dashboard.schedule.manualPeriodCount'),
                        colors,
                      ),
                      items: List.generate(12, (index) => index + 1)
                          .map(
                            (count) => DropdownMenuItem(
                              value: count,
                              child: Text('$count'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedPeriodCount = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (!_periodIsValid) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.t('student.dashboard.schedule.manualPeriodOverflow'),
                    style: TextStyle(color: colors.danger, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startDateController,
                      style: TextStyle(color: colors.text),
                      keyboardType: TextInputType.datetime,
                      decoration: _manualInputDecoration(
                        'Ngày bắt đầu',
                        colors,
                        hintText: 'YYYY-MM-DD',
                      ),
                      validator: (value) =>
                          _manualScheduleDateValidator(value, 'Ngày bắt đầu'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _endDateController,
                      style: TextStyle(color: colors.text),
                      keyboardType: TextInputType.datetime,
                      decoration: _manualInputDecoration(
                        'Ngày kết thúc',
                        colors,
                        hintText: 'YYYY-MM-DD',
                      ),
                      validator: (value) {
                        final message = _manualScheduleDateValidator(
                          value,
                          'Ngày kết thúc',
                        );
                        if (message != null) {
                          return message;
                        }
                        final start = _normalizedDateOrNull(
                          _startDateController.text,
                        );
                        final end = _normalizedDateOrNull(value);
                        if (start != null &&
                            end != null &&
                            start.compareTo(end) > 0) {
                          return 'Ngày kết thúc phải sau ngày bắt đầu';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roomController,
                style: TextStyle(color: colors.text),
                decoration: _manualInputDecoration(
                  l10n.t('student.dashboard.schedule.manualRoom'),
                  colors,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => unawaited(_close()),
          child: Text(
            l10n.t('common.cancel'),
            style: TextStyle(
              color: colors.primaryStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primaryStrong,
            foregroundColor: colors.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _periodIsValid ? _submit : null,
          child: Text(
            l10n.t(
              _isEditing
                  ? 'student.dashboard.schedule.editSave'
                  : 'student.dashboard.schedule.manualSave',
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _ScheduleImportSemesterChoice {
  const _ScheduleImportSemesterChoice({
    required this.semester,
    required this.replaceExistingCourseSchedules,
  });

  final StudentSemester semester;
  final bool replaceExistingCourseSchedules;
}

class _ManualDayOption {
  const _ManualDayOption({required this.value, required this.label});

  final int value;
  final String label;
}

class _ImportMappingField {
  const _ImportMappingField({required this.key, required this.label});

  final String key;
  final String label;
}

class _ScheduleImportMappingRefresh {
  const _ScheduleImportMappingRefresh(this.mapping);

  final StudentScheduleImportMapping mapping;
}

const _unmappedScheduleColumnValue = '__unmapped__';

List<_ImportMappingField> _scheduleImportMappingFields(
  AppLocalizationController l10n,
) {
  return [
    _ImportMappingField(
      key: 'maMonHoc',
      label: l10n.t('student.dashboard.schedule.importMappingMaMonHoc'),
    ),
    _ImportMappingField(
      key: 'maMon',
      label: l10n.t('student.dashboard.schedule.importMappingMaMon'),
    ),
    _ImportMappingField(
      key: 'tenMon',
      label: l10n.t('student.dashboard.schedule.importMappingTenMon'),
    ),
    _ImportMappingField(
      key: 'thu',
      label: l10n.t('student.dashboard.schedule.importMappingThu'),
    ),
    _ImportMappingField(
      key: 'tietBatDau',
      label: l10n.t('student.dashboard.schedule.importMappingTietBatDau'),
    ),
    _ImportMappingField(
      key: 'soTiet',
      label: l10n.t('student.dashboard.schedule.importMappingSoTiet'),
    ),
    _ImportMappingField(
      key: 'soTinChi',
      label: l10n.t('student.dashboard.schedule.importMappingSoTinChi'),
    ),
    _ImportMappingField(
      key: 'phongHoc',
      label: l10n.t('student.dashboard.schedule.importMappingPhongHoc'),
    ),
    _ImportMappingField(
      key: 'ngayBatDau',
      label: l10n.t('student.dashboard.schedule.importMappingNgayBatDau'),
    ),
    _ImportMappingField(
      key: 'ngayKetThuc',
      label: l10n.t('student.dashboard.schedule.importMappingNgayKetThuc'),
    ),
  ];
}

Map<String, String?> _scheduleMappingToSelections(
  StudentScheduleImportMapping mapping,
) {
  return {
    'maMonHoc': mapping.maMonHoc,
    'maMon': mapping.maMon,
    'tenMon': mapping.tenMon,
    'thu': mapping.thu,
    'tietBatDau': mapping.tietBatDau,
    'soTiet': mapping.soTiet,
    'soTinChi': mapping.soTinChi,
    'phongHoc': mapping.phongHoc,
    'ngayBatDau': mapping.ngayBatDau,
    'ngayKetThuc': mapping.ngayKetThuc,
  };
}

StudentScheduleImportMapping _scheduleMappingFromSelections(
  Map<String, String?> selections,
) {
  return StudentScheduleImportMapping(
    maMonHoc: selections['maMonHoc'],
    maMon: selections['maMon'],
    tenMon: selections['tenMon'],
    thu: selections['thu'],
    tietBatDau: selections['tietBatDau'],
    soTiet: selections['soTiet'],
    soTinChi: selections['soTinChi'],
    phongHoc: selections['phongHoc'],
    ngayBatDau: selections['ngayBatDau'],
    ngayKetThuc: selections['ngayKetThuc'],
  );
}

bool _scheduleMappingsEqual(
  StudentScheduleImportMapping first,
  StudentScheduleImportMapping second,
) {
  return first.toJson().toString() == second.toJson().toString();
}

List<_ManualDayOption> _manualDayOptions(AppLocalizationController l10n) {
  return [
    _ManualDayOption(
      value: 2,
      label: l10n.t('student.dashboard.schedule.day.mon'),
    ),
    _ManualDayOption(
      value: 3,
      label: l10n.t('student.dashboard.schedule.day.tue'),
    ),
    _ManualDayOption(
      value: 4,
      label: l10n.t('student.dashboard.schedule.day.wed'),
    ),
    _ManualDayOption(
      value: 5,
      label: l10n.t('student.dashboard.schedule.day.thu'),
    ),
    _ManualDayOption(
      value: 6,
      label: l10n.t('student.dashboard.schedule.day.fri'),
    ),
    _ManualDayOption(
      value: 7,
      label: l10n.t('student.dashboard.schedule.day.sat'),
    ),
    _ManualDayOption(
      value: 8,
      label: l10n.t('student.dashboard.schedule.day.sun'),
    ),
  ];
}

String _dateInputValue(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.length >= 10) {
    return trimmed.substring(0, 10);
  }
  return trimmed;
}

String? _normalizedDateOrNull(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }

  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) {
    return null;
  }

  final year = parsed.year.toString().padLeft(4, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String? _manualScheduleDateValidator(String? value, String label) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  if (_normalizedDateOrNull(trimmed) == null) {
    return '$label phải đúng định dạng YYYY-MM-DD';
  }
  return null;
}

InputDecoration _manualInputDecoration(
  String label,
  StudentThemeColors colors, {
  String? hintText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    labelStyle: TextStyle(
      color: colors.textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    floatingLabelStyle: TextStyle(
      color: colors.primaryStrong,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
    hintStyle: TextStyle(
      color: colors.isLight ? colors.textMuted : colors.textSubtle,
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: colors.surfaceAlt,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.borderStrong),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.primaryStrong, width: 1.4),
    ),
  );
}

class _ImportMappingSelector extends StatelessWidget {
  const _ImportMappingSelector({
    required this.field,
    required this.headers,
    required this.selectedColumn,
    required this.colors,
    required this.onChanged,
  });

  final _ImportMappingField field;
  final List<String> headers;
  final String? selectedColumn;
  final StudentThemeColors colors;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedValue = selectedColumn ?? _unmappedScheduleColumnValue;
    return DropdownButtonFormField<String>(
      key: ValueKey('${field.key}-$selectedValue'),
      initialValue: selectedValue,
      isExpanded: true,
      dropdownColor: colors.surface,
      iconEnabledColor: colors.textMuted,
      iconDisabledColor: colors.textSubtle,
      style: TextStyle(
        color: colors.text,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: field.label,
        labelStyle: TextStyle(
          color: colors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: TextStyle(
          color: colors.primaryStrong,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: colors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primaryStrong, width: 1.3),
        ),
      ),
      items: [
        DropdownMenuItem(
          value: _unmappedScheduleColumnValue,
          child: Text(
            l10n.t('student.dashboard.schedule.importMappingUnmapped'),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textMuted),
          ),
        ),
        for (final header in headers)
          DropdownMenuItem(
            value: header,
            child: Text(
              header,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.text),
            ),
          ),
      ],
      onChanged: (value) {
        onChanged(value == _unmappedScheduleColumnValue ? null : value);
      },
    );
  }
}

class _ImportPreviewStat extends StatelessWidget {
  const _ImportPreviewStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceAlt.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _StudentBottomBar extends StatelessWidget {
  const _StudentBottomBar({
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    final menuItems = [
      _StudentMenuItem(
        l10n.t('student.dashboard.menu.home'),
        Icons.home_rounded,
      ),
      _StudentMenuItem(
        l10n.t('student.dashboard.menu.schedule'),
        Icons.calendar_today_rounded,
      ),
      _StudentMenuItem(
        l10n.t('student.dashboard.menu.catalog'),
        Icons.grid_view_rounded,
      ),
      _StudentMenuItem(
        l10n.t('student.dashboard.menu.notifications'),
        Icons.notifications_rounded,
      ),
      _StudentMenuItem(
        l10n.t('student.dashboard.menu.settings'),
        Icons.settings_rounded,
      ),
    ];

    return Container(
      height: 85,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.bottomBar,
        border: Border(top: BorderSide(color: colors.border, width: 1.5)),
        boxShadow: [
          if (colors.isLight)
            BoxShadow(
              color: colors.shadow,
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var index = 0; index < menuItems.length; index++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(index),
                child: currentIndex == index
                    ? AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.primaryStrong,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primaryStrong.withValues(
                                alpha: 0.28,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              menuItems[index].icon,
                              size: 20,
                              color: colors.onPrimary,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              menuItems[index].label,
                              style: TextStyle(
                                color: colors.onPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            menuItems[index].icon,
                            size: 20,
                            color: colors.textSubtle,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            menuItems[index].label,
                            style: TextStyle(
                              color: colors.textSubtle,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StudentMenuItem {
  const _StudentMenuItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _ScheduleBundle {
  const _ScheduleBundle({required this.schedules, required this.deadlines});

  final StudentScheduleData schedules;
  final StudentDeadlineData deadlines;

  factory _ScheduleBundle.empty() {
    return _ScheduleBundle(
      schedules: const StudentScheduleData(
        message: 'Đang tải lịch học...',
        warning: null,
        items: [],
      ),
      deadlines: StudentDeadlineData.fromJson(const <dynamic>[]),
    );
  }
}

class _CatalogBundle {
  const _CatalogBundle({required this.courses, required this.grades});

  final StudentCourseData courses;
  final StudentGradeTranscriptData grades;

  factory _CatalogBundle.empty() {
    return _CatalogBundle(
      courses: const StudentCourseData(
        message: 'Đang tải danh mục...',
        selectedSemesterId: null,
        semesters: [],
        items: [],
      ),
      grades: StudentGradeTranscriptData.empty(),
    );
  }
}
