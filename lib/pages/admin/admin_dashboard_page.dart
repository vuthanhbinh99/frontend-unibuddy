import 'package:flutter/material.dart';

import '../../models/auth_models.dart';
import '../../services/api/modules/admin_api_service.dart';
import 'admin_document_moderation_page.dart';
import 'admin_overview_page.dart';
import 'admin_schools_page.dart';
import 'widgets/admin_common.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.session,
    required this.adminApi,
    required this.onLogout,
  });

  final AuthSession session;
  final AdminApiService adminApi;
  final Future<void> Function() onLogout;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      AdminOverviewPage(
        api: widget.adminApi,
        adminName: widget.session.user.fullName,
        onOpenSchools: () => _selectTab(1),
        onOpenModeration: () => _selectTab(2),
      ),
      AdminSchoolsPage(api: widget.adminApi),
      AdminDocumentModerationPage(api: widget.adminApi),
    ];

    return Theme(
      data: buildAdminLightTheme(),
      child: Scaffold(
        backgroundColor: adminBackground,
        appBar: AppBar(
          titleSpacing: 18,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'UniBuddy',
                style: TextStyle(
                  color: adminPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                widget.session.user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: adminMuted,
                  fontSize: 12,
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
            backgroundColor: adminSurface,
            indicatorColor: adminPrimary.withValues(alpha: 0.12),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(color: selected ? adminPrimary : adminMuted);
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 11,
                color: selected ? adminText : adminMuted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              );
            }),
          ),
          child: NavigationBar(
            height: adminIsCompact(context) ? 66 : 74,
            selectedIndex: _selectedIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: _selectTab,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Tổng quan',
              ),
              NavigationDestination(
                icon: Icon(Icons.school_outlined),
                selectedIcon: Icon(Icons.school),
                label: 'Trường',
              ),
              NavigationDestination(
                icon: Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description),
                label: 'Tài liệu',
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
}
