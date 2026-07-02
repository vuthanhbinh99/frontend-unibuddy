import 'dart:async';

import 'package:flutter/material.dart';

import 'models/auth_models.dart';
import 'l10n/app_localizations.dart';
import 'pages/admin/admin_dashboard_page.dart';
import 'pages/auth/forgot_password_page.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/register_page.dart';
import 'pages/student/student_dashboard_page.dart';
import 'pages/system_admin/system_admin_dashboard_page.dart';
import 'services/api/api_client.dart';
import 'services/api/modules/admin_api_service.dart';
import 'services/api/modules/auth_api_service.dart';
import 'services/api/modules/student_api_service.dart';
import 'services/api/modules/system_admin_api_service.dart';
import 'services/auth/google_identity_service.dart';
import 'services/local/frontend_preferences_service.dart';

class UniBuddyApp extends StatefulWidget {
  const UniBuddyApp({super.key});

  @override
  State<UniBuddyApp> createState() => _UniBuddyAppState();
}

class _UniBuddyAppState extends State<UniBuddyApp> {
  late final ApiClient _apiClient;
  late final AuthApiService _authApi;
  late final AdminApiService _adminApi;
  late final StudentApiService _studentApi;
  late final SystemAdminApiService _systemAdminApi;
  late final GoogleIdentityService _googleIdentityService;
  late final FrontendPreferencesService _frontendPreferences;
  late final AppLocalizationController _localizationController;
  AuthSession? _session;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _authApi = AuthApiService(_apiClient);
    _adminApi = AdminApiService(_apiClient);
    _studentApi = StudentApiService(_apiClient);
    _systemAdminApi = SystemAdminApiService(_apiClient);
    _googleIdentityService = GoogleIdentityService();
    _frontendPreferences = FrontendPreferencesService();
    _localizationController = AppLocalizationController(
      preferences: _frontendPreferences,
    );
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _localizationController.load();
    _studentApi.setAcceptLanguageCode(_localizationController.languageCode);
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        title: 'UniBuddy',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const _AppLoadingPage(),
      );
    }

    return AppLocalizationScope(
      controller: _localizationController,
      child: AnimatedBuilder(
        animation: _localizationController,
        builder: (context, _) {
          return MaterialApp(
            title: context.l10n.t('app.title'),
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(),
            locale: _localizationController.locale,
            home: Builder(
              builder: (context) =>
                  _session == null ? _buildAuthHome(context) : _buildRoleHome(),
            ),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    const seed = Color(0xFF4F46E5);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF08111F),
      fontFamily: 'Roboto',
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111827),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF263244)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF263244)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF818CF8), width: 1.4),
        ),
      ),
    );
  }

  Widget _buildAuthHome(BuildContext navigatorContext) {
    return LoginPage(
      authApi: _authApi,
      googleIdentityService: _googleIdentityService,
      onLoginSuccess: (session) {
        setState(() => _session = session);
      },
      onRegisterTap: () {
        Navigator.of(navigatorContext).push(
          MaterialPageRoute(builder: (_) => RegisterPage(authApi: _authApi)),
        );
      },
      onForgotPasswordTap: () {
        Navigator.of(navigatorContext).push(
          MaterialPageRoute(
            builder: (_) => ForgotPasswordPage(authApi: _authApi),
          ),
        );
      },
    );
  }

  Widget _buildRoleHome() {
    final session = _session!;

    switch (session.user.role.roleCode) {
      case UserRoleCode.student:
        return _buildStudentDashboard(session);
      case UserRoleCode.admin:
        return AdminDashboardPage(
          session: session,
          adminApi: _adminApi,
          onLogout: _logout,
        );
      case UserRoleCode.systemAdmin:
        return SystemAdminDashboardPage(
          session: session,
          systemAdminApi: _systemAdminApi,
          onLogout: _logout,
        );
      case null:
        return _UnsupportedRolePage(session: session, onLogout: _logout);
    }
  }

  Widget _buildStudentDashboard(AuthSession session) {
    return StudentDashboardPage(
      session: session,
      studentApi: _studentApi,
      currentLanguageCode: _localizationController.languageCode,
      onLanguageChanged: _handleLanguageChanged,
      onLogout: _logout,
    );
  }

  Future<void> _handleLanguageChanged(String code) async {
    await _localizationController.setLanguage(code);
    _studentApi.setAcceptLanguageCode(_localizationController.languageCode);
  }

  Future<void> _logout() async {
    final currentSession = _session;
    setState(() => _session = null);
    if (currentSession != null) {
      try {
        await _authApi.logout(currentSession.refreshToken);
      } catch (_) {
        // Local logout should not be blocked by a transient network issue.
      }
    }
  }
}

class _UnsupportedRolePage extends StatelessWidget {
  const _UnsupportedRolePage({required this.session, required this.onLogout});

  final AuthSession session;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.t('app.title')),
        actions: [
          IconButton(
            tooltip: context.l10n.t('common.logout'),
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person_outlined, size: 44),
              const SizedBox(height: 14),
              Text(
                context.l10n.t(
                  'app.unsupportedRole.message',
                  arguments: {'role': session.user.role.code},
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppLoadingPage extends StatelessWidget {
  const _AppLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
