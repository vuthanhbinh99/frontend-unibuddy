import 'package:flutter/material.dart';

import '../../models/admin_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/admin_api_service.dart';
import 'widgets/admin_common.dart';

class AdminOverviewPage extends StatefulWidget {
  const AdminOverviewPage({
    super.key,
    required this.api,
    required this.adminName,
    required this.onOpenSchools,
    required this.onOpenModeration,
  });

  final AdminApiService api;
  final String adminName;
  final VoidCallback onOpenSchools;
  final VoidCallback onOpenModeration;

  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<AdminOverviewPage> {
  late Future<AdminDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.loadDashboard();
  }

  Future<void> _refresh() async {
    final next = widget.api.loadDashboard();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminDashboardData>(
      future: _future,
      builder: (context, snapshot) {
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: adminPagePadding(context),
            children: [
              AdminSectionHeader(
                title: 'Tổng quan',
                subtitle:
                    'Xin chào ${widget.adminName}. Theo dõi danh mục trường và báo cáo tài liệu.',
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const AdminLoading()
              else if (snapshot.hasError)
                AdminErrorState(
                  message: _formatError(snapshot.error!),
                  onRetry: _refresh,
                )
              else
                _OverviewContent(
                  data: snapshot.data!,
                  onOpenSchools: widget.onOpenSchools,
                  onOpenModeration: widget.onOpenModeration,
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
    return 'Không thể tải dữ liệu tổng quan admin.';
  }
}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent({
    required this.data,
    required this.onOpenSchools,
    required this.onOpenModeration,
  });

  final AdminDashboardData data;
  final VoidCallback onOpenSchools;
  final VoidCallback onOpenModeration;

  @override
  Widget build(BuildContext context) {
    final totalReports = data.pendingReports.length + data.processedReportCount;
    final latestSchools = [...data.schools]
      ..sort((a, b) {
        final aTime =
            a.updatedAt ??
            a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.updatedAt ??
            b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 460
            ? 1
            : (constraints.maxWidth >= 820 ? 4 : 2);
        final aspectRatio = columns == 1 ? 3.25 : 1.75;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GridView.count(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: aspectRatio,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                AdminMetricCard(
                  icon: Icons.school_outlined,
                  label: 'Trường',
                  value: data.schools.length.toString(),
                  caption: 'Trong danh mục',
                  accent: adminPrimary,
                ),
                AdminMetricCard(
                  icon: Icons.pending_actions_outlined,
                  label: 'Chờ xử lý',
                  value: data.pendingReports.length.toString(),
                  caption: 'Báo cáo tài liệu',
                  accent: adminWarning,
                ),
                AdminMetricCard(
                  icon: Icons.fact_check_outlined,
                  label: 'Đã xử lý',
                  value: data.processedReportCount.toString(),
                  caption: '$totalReports tổng báo cáo',
                  accent: adminSuccess,
                ),
                AdminMetricCard(
                  icon: Icons.visibility_off_outlined,
                  label: 'Đã ẩn',
                  value: data.approvedReports.length.toString(),
                  caption: 'Tài liệu vi phạm',
                  accent: adminDanger,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _QuickActions(
              onOpenSchools: onOpenSchools,
              onOpenModeration: onOpenModeration,
            ),
            if (data.pendingReports.isNotEmpty) ...[
              const SizedBox(height: 18),
              _PendingNotice(count: data.pendingReports.length),
            ],
            const SizedBox(height: 18),
            const AdminSectionHeader(title: 'Báo cáo gần đây'),
            const SizedBox(height: 12),
            if (data.recentReports.isEmpty)
              const AdminEmptyState(
                icon: Icons.description_outlined,
                message: 'Chưa có báo cáo tài liệu để hiển thị.',
              )
            else
              ...data.recentReports.map(
                (report) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RecentReportTile(report: report),
                ),
              ),
            const SizedBox(height: 8),
            const AdminSectionHeader(title: 'Trường cập nhật gần đây'),
            const SizedBox(height: 12),
            if (latestSchools.isEmpty)
              const AdminEmptyState(
                icon: Icons.school_outlined,
                message: 'Chưa có trường nào trong danh mục.',
              )
            else
              ...latestSchools
                  .take(4)
                  .map(
                    (school) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SchoolPreview(school: school),
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
    required this.onOpenSchools,
    required this.onOpenModeration,
  });

  final VoidCallback onOpenSchools;
  final VoidCallback onOpenModeration;

  @override
  Widget build(BuildContext context) {
    final actions = [
      FilledButton.icon(
        onPressed: onOpenModeration,
        icon: const Icon(Icons.verified_outlined),
        label: const Text('Kiểm duyệt tài liệu'),
      ),
      OutlinedButton.icon(
        onPressed: onOpenSchools,
        icon: const Icon(Icons.school_outlined),
        label: const Text('Danh mục trường'),
      ),
    ];

    if (!adminIsCompact(context)) {
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
  }
}

class _PendingNotice extends StatelessWidget {
  const _PendingNotice({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      borderColor: adminWarning.withValues(alpha: 0.35),
      backgroundColor: const Color(0xFFFFFBEB),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: adminWarning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count báo cáo tài liệu đang chờ admin xử lý.',
              style: const TextStyle(
                color: adminText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentReportTile extends StatelessWidget {
  const _RecentReportTile({required this.report});

  final AdminDocumentReport report;

  @override
  Widget build(BuildContext context) {
    final color = adminReportStatusColor(report.status);

    return AdminCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.description_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.documentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  report.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: adminMuted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AdminPill(
                      label: adminReportStatusLabel(report.status),
                      color: color,
                    ),
                    AdminPill(
                      label: fileExtensionFromName(report.documentName),
                      color: adminBlue,
                    ),
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

class _SchoolPreview extends StatelessWidget {
  const _SchoolPreview({required this.school});

  final AdminSchool school;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: adminPrimary.withValues(alpha: 0.12),
            child: Text(
              school.code.characters.take(2).toString(),
              style: const TextStyle(
                color: adminPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  school.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${school.code} • ${formatAdminDateTime(school.updatedAt ?? school.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: adminMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
