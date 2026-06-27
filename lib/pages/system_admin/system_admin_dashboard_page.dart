import 'package:flutter/material.dart';

import '../../models/auth_models.dart';
import '../../services/api/modules/system_admin_api_service.dart';
import 'system_admin_logs_page.dart';
import 'system_admin_notifications_page.dart';
import 'system_admin_overview_page.dart';
import 'system_admin_users_page.dart';
import 'widgets/system_admin_common.dart';

class SystemAdminDashboardPage extends StatefulWidget {
  const SystemAdminDashboardPage({
    super.key,
    required this.session,
    required this.systemAdminApi,
    required this.onLogout,
  });

  final AuthSession session;
  final SystemAdminApiService systemAdminApi;
  final Future<void> Function() onLogout;

  @override
  State<SystemAdminDashboardPage> createState() =>
      _SystemAdminDashboardPageState();
}

class _SystemAdminDashboardPageState extends State<SystemAdminDashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final titles = ['Tổng quan', 'Thông báo', 'Log', 'Người dùng'];
    final pages = [
      SystemAdminOverviewPage(
        api: widget.systemAdminApi,
        onOpenNotifications: () => _selectTab(1),
        onOpenLogs: () => _selectTab(2),
        onOpenUsers: () => _selectTab(3),
      ),
      SystemAdminNotificationsPage(api: widget.systemAdminApi),
      SystemAdminLogsPage(api: widget.systemAdminApi),
      SystemAdminUsersPage(
        api: widget.systemAdminApi,
        currentUserId: widget.session.user.id,
      ),
    ];

    return Theme(
      data: _buildSystemAdminLightTheme(),
      child: Scaffold(
        backgroundColor: systemAdminBackground,
        appBar: AppBar(
          toolbarHeight: 64,
          titleSpacing: 14,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titles[_selectedIndex],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                'Quản trị viên • ${widget.session.user.fullName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: systemAdminMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: IndexedStack(index: _selectedIndex, children: pages),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: systemAdminSurface,
            indicatorColor: systemAdminAccent.withValues(alpha: 0.14),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                color: selected ? systemAdminAccent : systemAdminMuted,
              );
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 11,
                color: selected ? systemAdminText : systemAdminMuted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              );
            }),
          ),
          child: NavigationBar(
            height: systemAdminIsCompact(context) ? 66 : 74,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectTab,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Tổng quan',
              ),
              NavigationDestination(
                icon: Icon(Icons.campaign_outlined),
                selectedIcon: Icon(Icons.campaign),
                label: 'Thông báo',
              ),
              NavigationDestination(
                icon: Icon(Icons.terminal_outlined),
                selectedIcon: Icon(Icons.terminal),
                label: 'Log',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Người dùng',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
  }

  ThemeData _buildSystemAdminLightTheme() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: systemAdminAccent,
          brightness: Brightness.light,
        ).copyWith(
          primary: systemAdminAccent,
          secondary: systemAdminInfo,
          surface: systemAdminSurface,
          error: systemAdminDanger,
          onSurface: systemAdminText,
        );

    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: systemAdminBorder),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Roboto',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: systemAdminBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: systemAdminSurface,
        foregroundColor: systemAdminText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(color: systemAdminBorder),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: systemAdminSurfaceAlt,
        border: outlineBorder,
        enabledBorder: outlineBorder,
        focusedBorder: outlineBorder.copyWith(
          borderSide: const BorderSide(color: systemAdminAccent, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: systemAdminAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: systemAdminText,
          side: const BorderSide(color: systemAdminBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: systemAdminMutedStrong),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: systemAdminText,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );
  }
}
