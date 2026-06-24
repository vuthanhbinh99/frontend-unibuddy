import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../services/api/api_exception.dart';
import '../services/api/modules/student_api_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.session,
    required this.studentApi,
    required this.onLogout,
  });

  final AuthSession session;
  final StudentApiService studentApi;
  final Future<void> Function() onLogout;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<PublicUser> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = widget.studentApi.getCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UniBuddy'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<PublicUser>(
        future: _userFuture,
        initialData: widget.session.user,
        builder: (context, snapshot) {
          final user = snapshot.data ?? widget.session.user;
          final error = snapshot.error;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _userFuture = widget.studentApi.getCurrentUser());
              await _userFuture;
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _ProfileCard(user: user),
                if (error != null) ...[
                  const SizedBox(height: 14),
                  _InlineWarning(message: _formatError(error)),
                ],
                const SizedBox(height: 20),
                const _MetricGrid(),
                const SizedBox(height: 20),
                const _NextActions(),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatError(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Không thể làm mới hồ sơ từ backend.';
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final PublicUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF172033)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF4F46E5),
            child: Text(
              user.fullName.isNotEmpty
                  ? user.fullName.characters.first.toUpperCase()
                  : 'U',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(color: Colors.blueGrey.shade100),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(label: user.role.name),
                    _Pill(label: user.status),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.75,
      children: const [
        _MetricTile(icon: Icons.auto_graph, label: 'GPA', value: '--'),
        _MetricTile(
          icon: Icons.calendar_month_outlined,
          label: 'Lịch học',
          value: '--',
        ),
        _MetricTile(
          icon: Icons.task_alt_outlined,
          label: 'Deadline',
          value: '--',
        ),
        _MetricTile(
          icon: Icons.groups_2_outlined,
          label: 'Nhóm học',
          value: '--',
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF93C5FD)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: TextStyle(color: Colors.blueGrey.shade100)),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NextActions extends StatelessWidget {
  const _NextActions();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: const Row(
        children: [
          Icon(Icons.extension_outlined, color: Color(0xFF818CF8)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Dữ liệu học tập sẽ xuất hiện khi tài khoản có học kỳ, môn học, lịch học và deadline.',
              style: TextStyle(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.amber),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
