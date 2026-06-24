import 'package:flutter/material.dart';

import '../../models/auth_models.dart';
import '../shared/role_dashboard_shell.dart';

class SystemAdminDashboardPage extends StatelessWidget {
  const SystemAdminDashboardPage({
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
      title: 'Quản trị viên',
      subtitle: 'Không gian quản trị hệ thống',
      icon: Icons.security_outlined,
      accentColor: const Color(0xFFF59E0B),
      items: const [
        RoleDashboardItem(
          icon: Icons.campaign_outlined,
          title: 'Thông báo hệ thống',
          subtitle: 'Gửi thông báo đến sinh viên, admin hoặc toàn hệ thống.',
        ),
        RoleDashboardItem(
          icon: Icons.storage_outlined,
          title: 'Dung lượng lưu trữ',
          subtitle: 'Theo dõi PostgreSQL, tài liệu và Firebase Storage.',
        ),
        RoleDashboardItem(
          icon: Icons.receipt_long_outlined,
          title: 'Nhật ký hệ thống',
          subtitle:
              'Tra cứu audit log theo người dùng, hành động và thời gian.',
        ),
        RoleDashboardItem(
          icon: Icons.report_problem_outlined,
          title: 'Lỗi nghiêm trọng',
          subtitle: 'Theo dõi log ERROR và CRITICAL mới nhất.',
        ),
      ],
    );
  }
}
