import 'package:flutter/material.dart';

import '../../models/system_admin_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/system_admin_api_service.dart';
import 'widgets/system_admin_common.dart';

class SystemAdminOverviewPage extends StatefulWidget {
  const SystemAdminOverviewPage({
    super.key,
    required this.api,
    required this.onOpenNotifications,
    required this.onOpenLogs,
    required this.onOpenUsers,
  });

  final SystemAdminApiService api;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenLogs;
  final VoidCallback onOpenUsers;

  @override
  State<SystemAdminOverviewPage> createState() =>
      _SystemAdminOverviewPageState();
}

class _SystemAdminOverviewPageState extends State<SystemAdminOverviewPage> {
  late Future<_OverviewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_OverviewData> _load() async {
    final storage = await widget.api.getStorageUsage();
    final users = await widget.api.listUsers();
    final auditLogs = await widget.api.listAuditLogs(limit: 5);
    final errorLogs = await widget.api.listErrorLogs(limit: 5);

    return _OverviewData(
      storage: storage,
      users: users,
      auditLogs: auditLogs,
      errorLogs: errorLogs,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_OverviewData>(
      future: _future,
      builder: (context, snapshot) {
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: systemAdminPagePadding(context),
            children: [
              const SystemAdminSectionTitle(title: 'Tổng quan hệ thống'),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const SystemAdminLoading()
              else if (snapshot.hasError)
                SystemAdminErrorState(
                  message: _formatError(snapshot.error!),
                  onRetry: _refresh,
                )
              else
                _OverviewContent(
                  data: snapshot.data!,
                  onOpenNotifications: widget.onOpenNotifications,
                  onOpenLogs: widget.onOpenLogs,
                  onOpenUsers: widget.onOpenUsers,
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatError(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Không thể tải dữ liệu tổng quan.';
  }
}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent({
    required this.data,
    required this.onOpenNotifications,
    required this.onOpenLogs,
    required this.onOpenUsers,
  });

  final _OverviewData data;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenLogs;
  final VoidCallback onOpenUsers;

  @override
  Widget build(BuildContext context) {
    final lockedUsers = data.users
        .where((user) => user.status == ManagedUserStatus.locked)
        .length;
    final tempPasswordUsers = data.users
        .where(
          (user) => user.status == ManagedUserStatus.passwordChangeRequired,
        )
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final metricColumns = constraints.maxWidth < 460
            ? 1
            : (constraints.maxWidth >= 820 ? 4 : 2);
        final metricAspectRatio = metricColumns == 1
            ? 3.35
            : (constraints.maxWidth >= 820 ? 1.85 : 1.55);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GridView.count(
              crossAxisCount: metricColumns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: metricAspectRatio,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                SystemAdminMetricCard(
                  icon: Icons.people_outline,
                  label: 'Người dùng',
                  value: data.users.length.toString(),
                  caption: '$lockedUsers bị khóa',
                  accent: systemAdminInfo,
                ),
                SystemAdminMetricCard(
                  icon: Icons.lock_reset_outlined,
                  label: 'Mật khẩu tạm thời',
                  value: tempPasswordUsers.toString(),
                  caption: 'Chờ đổi mật khẩu',
                  accent: systemAdminMutedStrong,
                ),
                SystemAdminMetricCard(
                  icon: Icons.storage_outlined,
                  label: 'Lưu trữ',
                  value: formatBytes(data.storage.totalBytes),
                  caption: '${data.storage.documentFileCount} tài liệu',
                  accent: systemAdminAccent,
                ),
                SystemAdminMetricCard(
                  icon: Icons.report_problem_outlined,
                  label: 'Lỗi hệ thống',
                  value: data.errorLogs.total.toString(),
                  caption: 'ERROR / CRITICAL',
                  accent: systemAdminDanger,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _QuickActions(
              onOpenNotifications: onOpenNotifications,
              onOpenLogs: onOpenLogs,
              onOpenUsers: onOpenUsers,
            ),
            const SizedBox(height: 18),
            SystemAdminSectionTitle(
              title: 'Lưu trữ',
              trailing: Text(
                data.storage.firebase.configured
                    ? 'Firebase: bật'
                    : 'Firebase: chưa cấu hình',
                style: TextStyle(
                  color: data.storage.firebase.configured
                      ? systemAdminSuccess
                      : systemAdminMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SystemAdminCard(
              child: Column(
                children: [
                  _StorageRow(
                    label: 'PostgreSQL',
                    value: formatBytes(data.storage.databaseTotalBytes),
                  ),
                  const Divider(height: 18),
                  _StorageRow(
                    label: 'Tài liệu nội bộ',
                    value: formatBytes(data.storage.documentTotalBytes),
                  ),
                  const Divider(height: 18),
                  _StorageRow(
                    label: 'Firebase Storage',
                    value: formatBytes(data.storage.firebase.totalBytes),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SystemAdminSectionTitle(title: 'Nhật ký gần đây'),
            const SizedBox(height: 12),
            if (data.auditLogs.items.isEmpty)
              const SystemAdminEmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'Chưa có audit log để hiển thị.',
              )
            else
              ...data.auditLogs.items.map(
                (log) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LogPreview(log: log),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onOpenNotifications,
    required this.onOpenLogs,
    required this.onOpenUsers,
  });

  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenLogs;
  final VoidCallback onOpenUsers;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final actions = [
          FilledButton.icon(
            onPressed: onOpenNotifications,
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('Gửi thông báo'),
          ),
          OutlinedButton.icon(
            onPressed: onOpenLogs,
            icon: const Icon(Icons.terminal_outlined),
            label: const Text('Xem log'),
          ),
          OutlinedButton.icon(
            onPressed: onOpenUsers,
            icon: const Icon(Icons.people_outline),
            label: const Text('Quản lý người dùng'),
          ),
        ];

        if (!compact) {
          return Wrap(spacing: 10, runSpacing: 10, children: actions);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final action in actions) ...[
              action,
              if (action != actions.last) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: systemAdminMuted)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _LogPreview extends StatelessWidget {
  const _LogPreview({required this.log});

  final AuditLogEntry log;

  @override
  Widget build(BuildContext context) {
    final color = levelColor(log.level);

    return SystemAdminCard(
      child: Row(
        children: [
          Container(
            width: 10,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.action,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  log.message ?? log.actorEmail ?? 'Không có mô tả',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: systemAdminMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  formatDateTime(log.createdAt),
                  style: const TextStyle(fontSize: 12, color: systemAdminMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewData {
  const _OverviewData({
    required this.storage,
    required this.users,
    required this.auditLogs,
    required this.errorLogs,
  });

  final StorageUsage storage;
  final List<ManagedUser> users;
  final PaginatedAuditLogs auditLogs;
  final PaginatedAuditLogs errorLogs;
}
