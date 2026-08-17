import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/auth_models.dart' as auth;
import '../../../models/student_course_models.dart';
import '../../../models/student_deadline_models.dart';
import '../../../models/student_grade_models.dart';
import '../../../models/student_home_models.dart';
import '../../../models/student_schedule_models.dart';
import '../../../services/api/core/api_exception.dart';
import '../../../services/api/modules/student/student_api_service.dart';
import '../../../services/local/frontend_preferences_service.dart';
import '../../../services/notifications/push_notification_service.dart';
import '../../../l10n/app_localizations.dart';
import '../home/home_screen.dart';
import '../exam_management/student_exam_management_page.dart';
import '../catalog/student_catalog_tab.dart';
import '../notifications/student_notifications_tab.dart';
import '../profile/student_profile_tab.dart';
import '../settings/student_settings_tab.dart';
import '../schedule/student_schedule_tab.dart';
import '../theme/student_theme.dart';
part 'student_dashboard_schedule_import.dart';
part 'student_dashboard_schedule_actions.dart';

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

  /// Khởi tạo state ban đầu và đăng ký dữ liệu/listener cần thiết cho màn hình.
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

  /// Giải phóng controller, listener hoặc tài nguyên khi widget bị hủy.
  @override
  void dispose() {
    _studentThemeController.dispose();
    super.dispose();
  }

  /// Xử lý thao tác update dashboard state và đồng bộ kết quả với UI.
  void _updateDashboardState(VoidCallback fn) {
    setState(fn);
  }

  /// Đồng bộ state khi widget cha truyền cấu hình mới xuống.
  @override
  void didUpdateWidget(covariant StudentDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLanguageCode != widget.currentLanguageCode) {
      _languageCode = widget.currentLanguageCode;
      widget.studentApi.setAcceptLanguageCode(_languageCode);
    }
  }

  /// Tải hoặc lấy dữ liệu reload all để cập nhật UI.
  void _reloadAll() {
    _homeDataFuture = widget.studentApi.getStudentHomeData();
    _scheduleBundleFuture = _loadScheduleBundle();
    _catalogBundleFuture = _loadCatalogBundle();
    _profileFuture = widget.studentApi.getCurrentUser();
  }

  /// Thực hiện tác vụ bất đồng bộ restore frontend preferences cho màn hình hiện tại.
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

  /// Xử lý sự kiện change language từ người dùng hoặc hệ thống.
  void _changeLanguage(String code) {
    if (code == _languageCode) {
      return;
    }
    setState(() => _languageCode = code);
    widget.studentApi.setAcceptLanguageCode(code);
    unawaited(_frontendPreferences.saveStudentLanguageCode(code));
    widget.onLanguageChanged(code);
  }

  /// Xử lý sự kiện select tab từ người dùng hoặc hệ thống.
  void _selectTab(int index) {
    if (index < 0 || index > 4 || index == _currentIndex) {
      return;
    }
    setState(() => _currentIndex = index);
    unawaited(_frontendPreferences.saveStudentDashboardTabIndex(index));
  }

  /// Tải hoặc lấy dữ liệu load schedule bundle để cập nhật UI.
  Future<_ScheduleBundle> _loadScheduleBundle() async {
    final schedules = await widget.studentApi.listSchedules();
    final deadlines = await widget.studentApi.listDeadlines();
    return _ScheduleBundle(schedules: schedules, deadlines: deadlines);
  }

  /// Tải hoặc lấy dữ liệu load catalog bundle để cập nhật UI.
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

  /// Tải hoặc lấy dữ liệu refresh home để cập nhật UI.
  Future<void> _refreshHome() async {
    final next = widget.studentApi.getStudentHomeData();
    setState(() => _homeDataFuture = next);
    await next;
  }

  /// Tải hoặc lấy dữ liệu refresh schedule để cập nhật UI.
  Future<void> _refreshSchedule() async {
    final next = _loadScheduleBundle();
    setState(() => _scheduleBundleFuture = next);
    await next;
  }

  /// Tải hoặc lấy dữ liệu refresh catalog để cập nhật UI.
  Future<void> _refreshCatalog() async {
    final next = _loadCatalogBundle();
    setState(() => _catalogBundleFuture = next);
    await next;
  }

  /// Tải hoặc lấy dữ liệu refresh profile để cập nhật UI.
  Future<void> _refreshProfile() async {
    final next = widget.studentApi.getCurrentUser();
    setState(() => _profileFuture = next);
    await next;
  }

  /// Tải hoặc lấy dữ liệu refresh academic data để cập nhật UI.
  Future<void> _refreshAcademicData() async {
    await _refreshStudentDashboardData(labelPrefix: 'academic');
  }

  /// Tải hoặc lấy dữ liệu refresh after schedule import để cập nhật UI.
  Future<void> _refreshAfterScheduleImport() async {
    await _refreshStudentDashboardData(labelPrefix: 'schedule import');
  }

  /// Tải hoặc lấy dữ liệu refresh student dashboard data để cập nhật UI.
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

  /// Xử lý sự kiện toggle deadline từ người dùng hoặc hệ thống.
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

  /// Hiển thị hoặc mở phần giao diện open exam management cho người dùng.
  void _openExamManagement() {
    Navigator.of(context).push(
      buildStudentThemedRoute<void>(
        controller: _studentThemeController,
        builder: (_) =>
            StudentExamManagementPage(studentApi: widget.studentApi),
      ),
    );
  }

  /// Hiển thị hoặc mở phần giao diện open notifications cho người dùng.
  void _openNotifications() {
    _selectTab(3);
  }

  /// Hiển thị hoặc mở phần giao diện open profile cho người dùng.
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

  /// Dựng phần giao diện build screens cho màn hình hiện tại.
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

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
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

  /// Hàm hỗ trợ semester names cho màn hình trong file này.
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
