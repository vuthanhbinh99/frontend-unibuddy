import 'package:flutter/material.dart';

import 'models/auth_models.dart';
import 'pages/admin/admin_dashboard_page.dart';
import 'pages/auth/forgot_password_page.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/register_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/system_admin/system_admin_dashboard_page.dart';
import 'services/api/api_client.dart';
import 'services/api/modules/auth_api_service.dart';
import 'services/api/modules/student_api_service.dart';

class UniBuddyApp extends StatefulWidget {
  const UniBuddyApp({super.key});

  @override
  State<UniBuddyApp> createState() => _UniBuddyAppState();
}

class _UniBuddyAppState extends State<UniBuddyApp> {
  late final ApiClient _apiClient;
  late final AuthApiService _authApi;
  late final StudentApiService _studentApi;
  AuthSession? _session;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _authApi = AuthApiService(_apiClient);
    _studentApi = StudentApiService(_apiClient);
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniBuddy',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: Builder(
        builder: (context) =>
            _session == null ? _buildAuthHome(context) : _buildRoleHome(),
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
        return AdminDashboardPage(session: session, onLogout: _logout);
      case UserRoleCode.systemAdmin:
        return SystemAdminDashboardPage(session: session, onLogout: _logout);
      case null:
        return _UnsupportedRolePage(session: session, onLogout: _logout);
    }
  }

  Widget _buildStudentDashboard(AuthSession session) {
    return DashboardPage(
      session: session,
      studentApi: _studentApi,
      onLogout: _logout,
    );
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
        title: const Text('UniBuddy'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
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
                'Vai trò ${session.user.role.code} chưa được hỗ trợ trên frontend.',
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
