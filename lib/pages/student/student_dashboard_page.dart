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
import '../../l10n/app_localizations.dart';
import 'focus_mode_screen.dart';
import 'home_screen.dart';
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
    required this.currentLanguageCode,
    required this.onLanguageChanged,
    required this.onLogout,
  });

  final auth.AuthSession session;
  final StudentApiService studentApi;
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
    final home = widget.studentApi.getStudentHomeData();
    final schedule = _loadScheduleBundle();
    final catalog = _loadCatalogBundle();
    setState(() {
      _homeDataFuture = home;
      _scheduleBundleFuture = schedule;
      _catalogBundleFuture = catalog;
    });
    await Future.wait([home, schedule, catalog]);
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

  void _openFocusMode() {
    Navigator.of(context).push(
      buildStudentThemedRoute<void>(
        controller: _studentThemeController,
        builder: (_) => const FocusModeScreen(),
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
        () => widget.studentApi.listCourses(),
        StudentCourseData(
          message: l10n.t('student.dashboard.schedule.importNoCourses'),
          selectedSemesterId: null,
          semesters: [],
          items: [],
        ),
      );
      final headers = await widget.studentApi.extractScheduleImportHeaders(
        bytes: bytes,
        fileName: file.name,
      );
      final preview = await widget.studentApi.previewScheduleImport(
        maHocKy: courses.selectedSemesterId,
        rows: headers.rows,
        mapping: headers.suggestedMapping,
      );

      if (!mounted) {
        return;
      }

      final shouldImport = await _showImportPreviewDialog(headers, preview);
      if (!mounted || shouldImport != true) {
        return;
      }

      final validItems = preview.validItems;
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
        maHocKy: courses.selectedSemesterId,
        items: validItems,
      );
      await _refreshSchedule();
      await _refreshCatalog();
      await _refreshHome();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
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
          content: Text(l10n.t('student.dashboard.schedule.importError')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isImportingSchedule = false);
      }
    }
  }

  Future<bool?> _showImportPreviewDialog(
    StudentScheduleImportHeadersData headers,
    StudentScheduleImportPreviewData preview,
  ) {
    final l10n = context.l10n;
    final colors = _studentThemeController.colors;
    final invalidSamples = preview.items
        .where((item) => !item.isValid && item.errors.isNotEmpty)
        .take(3)
        .toList();
    final canImport = preview.validItems.isNotEmpty;

    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            l10n.t('student.dashboard.schedule.importTitle'),
            style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${headers.sourceType} • ${headers.rows.length} dòng • ${headers.headers.length} cột',
                  style: TextStyle(color: colors.textSubtle),
                ),
                const SizedBox(height: 14),
                _ImportPreviewStat(
                  label: l10n.t('student.dashboard.schedule.importValidRows'),
                  value: preview.validRows.toString(),
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(height: 8),
                _ImportPreviewStat(
                  label: l10n.t('student.dashboard.schedule.importRowsToCheck'),
                  value: preview.invalidRows.toString(),
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(height: 8),
                _ImportPreviewStat(
                  label: l10n.t(
                    'student.dashboard.schedule.importAutoCreatedCourses',
                  ),
                  value: preview.autoCreateCourseRows.toString(),
                  color: const Color(0xFF818CF8),
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
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.t('common.cancel')),
            ),
            ElevatedButton(
              onPressed: canImport
                  ? () => Navigator.of(context).pop(true)
                  : null,
              child: Text(
                l10n.t(
                  'student.dashboard.schedule.importDialogImport',
                  arguments: {'count': preview.validItems.length},
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

  Future<_ManualScheduleInput?> _showManualScheduleDialog(
    List<StudentCourseItem> courses,
  ) {
    final l10n = context.l10n;
    final colors = _studentThemeController.colors;
    final formKey = GlobalKey<FormState>();
    final roomController = TextEditingController();
    var selectedCourseId = courses.first.id;
    var selectedDay = 2;
    var selectedStartPeriod = 1;
    var selectedPeriodCount = 3;

    return showDialog<_ManualScheduleInput>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final lastPeriod = selectedStartPeriod + selectedPeriodCount - 1;
            final periodIsValid = lastPeriod <= 12;

            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Icon(Icons.add_circle_outline, color: colors.primaryStrong),
                  const SizedBox(width: 8),
                  Text(
                    l10n.t('student.dashboard.schedule.manualTitle'),
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedCourseId,
                        dropdownColor: colors.surface,
                        decoration: _manualInputDecoration(
                          l10n.t('student.dashboard.schedule.manualCourse'),
                          colors,
                        ),
                        items: courses.map((course) {
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
                            setDialogState(() => selectedCourseId = value);
                          }
                        },
                        validator: (value) => value == null
                            ? l10n.t(
                                'student.dashboard.schedule.manualChooseCourse',
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: selectedDay,
                        dropdownColor: colors.surface,
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
                            setDialogState(() => selectedDay = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: selectedStartPeriod,
                              dropdownColor: colors.surface,
                              decoration: _manualInputDecoration(
                                l10n.t(
                                  'student.dashboard.schedule.manualStartPeriod',
                                ),
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
                                  setDialogState(
                                    () => selectedStartPeriod = value,
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: selectedPeriodCount,
                              dropdownColor: colors.surface,
                              decoration: _manualInputDecoration(
                                l10n.t(
                                  'student.dashboard.schedule.manualPeriodCount',
                                ),
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
                                  setDialogState(
                                    () => selectedPeriodCount = value,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      if (!periodIsValid) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.t(
                              'student.dashboard.schedule.manualPeriodOverflow',
                            ),
                            style: const TextStyle(
                              color: Color(0xFFFF809F),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: roomController,
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
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.t('common.cancel')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primaryStrong,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: periodIsValid
                      ? () {
                          if (formKey.currentState?.validate() != true) {
                            return;
                          }
                          Navigator.of(context).pop(
                            _ManualScheduleInput(
                              courseId: selectedCourseId,
                              dayOfWeek: selectedDay,
                              startPeriod: selectedStartPeriod,
                              periodCount: selectedPeriodCount,
                              room: roomController.text,
                            ),
                          );
                        }
                      : null,
                  child: Text(
                    l10n.t('student.dashboard.schedule.manualSave'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(roomController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
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
              onOpenFocusMode: _openFocusMode,
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
          return StudentScheduleTab(
            data: bundle.schedules,
            deadlines: bundle.deadlines,
            onRefresh: _refreshSchedule,
            onToggleDeadline: _toggleDeadline,
            onImportSchedule: _importSchedule,
            onAddScheduleManually: _addScheduleManually,
            studentApi: widget.studentApi,
            onViewAllNotifications: _openNotifications,
            isImportingSchedule: _isImportingSchedule,
            isSavingManualSchedule: _isSavingManualSchedule,
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
            studentName: widget.session.user.fullName,
            studentMajor: widget.session.user.role.name,
            studentApi: widget.studentApi,
            onChangeTab: _selectTab,
            onAcademicDataChanged: _refreshAcademicData,
            onOpenFocusMode: _openFocusMode,
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

    return AnimatedBuilder(
      animation: _studentThemeController,
      builder: (context, _) {
        final colors = _studentThemeController.colors;
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
  });

  final String courseId;
  final int dayOfWeek;
  final int startPeriod;
  final int periodCount;
  final String room;
}

class _ManualDayOption {
  const _ManualDayOption({required this.value, required this.label});

  final int value;
  final String label;
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

InputDecoration _manualInputDecoration(
  String label,
  StudentThemeColors colors,
) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: colors.textSubtle, fontSize: 12),
    filled: true,
    fillColor: colors.surfaceAlt,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.primaryStrong, width: 1.4),
    ),
  );
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
              style: TextStyle(color: colors.textMuted, fontSize: 12),
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
