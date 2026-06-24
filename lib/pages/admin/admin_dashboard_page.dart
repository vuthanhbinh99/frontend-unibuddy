import 'package:flutter/material.dart';

import '../../models/auth_models.dart';
import '../shared/role_dashboard_shell.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return RoleDashboardShell(
      session: session,
      onLogout: onLogout,
      title: 'Admin',
      subtitle: 'Không gian quản trị học vụ',
      icon: Icons.admin_panel_settings_outlined,
      accentColor: const Color(0xFF38BDF8),
      items: const [
        RoleDashboardItem(
          icon: Icons.school_outlined,
          title: 'Danh mục trường',
          subtitle: 'Quản lý trường, ngành học và dữ liệu danh mục.',
        ),
        RoleDashboardItem(
          icon: Icons.description_outlined,
          title: 'Tài liệu',
          subtitle: 'Kiểm duyệt tài liệu và báo cáo vi phạm.',
        ),
        RoleDashboardItem(
          icon: Icons.groups_2_outlined,
          title: 'Người dùng',
          subtitle: 'Theo dõi sinh viên và tài khoản được phân quyền.',
        ),
        RoleDashboardItem(
          icon: Icons.fact_check_outlined,
          title: 'Quy chế',
          subtitle: 'Quản lý thang điểm, học lực và quy định học tập.',
        ),
      ],
    );
  }
}
