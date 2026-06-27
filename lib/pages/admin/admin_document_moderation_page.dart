import 'package:flutter/material.dart';

import '../../models/admin_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/admin_api_service.dart';
import 'widgets/admin_common.dart';

class AdminDocumentModerationPage extends StatefulWidget {
  const AdminDocumentModerationPage({super.key, required this.api});

  final AdminApiService api;

  @override
  State<AdminDocumentModerationPage> createState() =>
      _AdminDocumentModerationPageState();
}

class _AdminDocumentModerationPageState
    extends State<AdminDocumentModerationPage> {
  late Future<_ModerationData> _future;
  int _activeTab = 0;
  String _query = '';
  String _fileType = _allFileTypes;
  String? _busyReportId;
  String? _expandedReportId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ModerationData> _load() async {
    final pending = await widget.api.listReports(
      status: AdminReportStatus.pending,
    );
    final approved = await widget.api.listReports(
      status: AdminReportStatus.approved,
    );
    final rejected = await widget.api.listReports(
      status: AdminReportStatus.rejected,
    );

    return _ModerationData(
      pending: pending,
      history: [...approved, ...rejected]..sort(_sortNewestFirst),
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ModerationData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final activeReports = data == null
            ? const <AdminDocumentReport>[]
            : (_activeTab == 0 ? data.pending : data.history);
        final filteredReports = _filterReports(activeReports);
        final fileTypes = data == null
            ? const <String>[_allFileTypes]
            : _availableFileTypes([...data.pending, ...data.history]);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: adminPagePadding(context),
            children: [
              const AdminSectionHeader(
                title: 'Kiểm duyệt tài liệu',
                subtitle: 'Xử lý báo cáo vi phạm từ sinh viên.',
              ),
              const SizedBox(height: 14),
              if (data != null)
                _ModerationFilters(
                  activeTab: _activeTab,
                  pendingCount: data.pending.length,
                  historyCount: data.history.length,
                  query: _query,
                  fileType: _fileType,
                  fileTypes: fileTypes,
                  onTabChanged: (index) => setState(() => _activeTab = index),
                  onQueryChanged: (value) => setState(() => _query = value),
                  onFileTypeChanged: (value) {
                    setState(() => _fileType = value ?? _allFileTypes);
                  },
                ),
              if (data != null) const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const AdminLoading()
              else if (snapshot.hasError)
                AdminErrorState(
                  message: _formatError(snapshot.error!),
                  onRetry: _refresh,
                )
              else if (filteredReports.isEmpty)
                AdminEmptyState(
                  icon: _activeTab == 0
                      ? Icons.task_alt_outlined
                      : Icons.history_outlined,
                  message: _activeTab == 0
                      ? 'Không có báo cáo đang chờ xử lý.'
                      : 'Không có lịch sử phù hợp.',
                )
              else
                ...filteredReports.map(
                  (report) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _activeTab == 0
                        ? _PendingReportCard(
                            report: report,
                            busy: _busyReportId == report.id,
                            expanded: _expandedReportId == report.id,
                            onToggleExpanded: () => _toggleExpanded(report.id),
                            onReject: () => _confirmReject(report),
                            onApprove: () => _confirmApprove(report),
                          )
                        : _HistoryReportCard(report: report),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<AdminDocumentReport> _filterReports(List<AdminDocumentReport> reports) {
    final normalizedQuery = _query.trim().toLowerCase();
    return reports.where((report) {
      final extension = fileExtensionFromName(report.documentName);
      final matchesType = _fileType == _allFileTypes || extension == _fileType;
      final matchesQuery =
          normalizedQuery.isEmpty ||
          report.documentName.toLowerCase().contains(normalizedQuery) ||
          report.reason.toLowerCase().contains(normalizedQuery) ||
          report.id.toLowerCase().contains(normalizedQuery) ||
          (report.reporterEmail?.toLowerCase().contains(normalizedQuery) ??
              false) ||
          (report.reporterName?.toLowerCase().contains(normalizedQuery) ??
              false);

      return matchesType && matchesQuery;
    }).toList();
  }

  void _toggleExpanded(String reportId) {
    setState(() {
      _expandedReportId = _expandedReportId == reportId ? null : reportId;
    });
  }

  Future<void> _confirmApprove(AdminDocumentReport report) async {
    final confirmed = await _confirmAction(
      title: 'Ẩn / xóa tài liệu?',
      message:
          'Báo cáo sẽ được duyệt và tài liệu "${report.documentName}" sẽ chuyển sang trạng thái ẩn/xóa trên backend.',
      confirmLabel: 'Ẩn / Xóa',
      danger: true,
    );

    if (confirmed) {
      await _runModerationAction(
        reportId: report.id,
        action: () => widget.api.approveReport(report.id),
        successMessage: 'Đã duyệt báo cáo và ẩn tài liệu.',
      );
    }
  }

  Future<void> _confirmReject(AdminDocumentReport report) async {
    final confirmed = await _confirmAction(
      title: 'Bác bỏ báo cáo?',
      message:
          'Báo cáo sẽ bị bác bỏ và tài liệu "${report.documentName}" được giữ ở trạng thái khả dụng.',
      confirmLabel: 'Bác bỏ',
      danger: false,
    );

    if (confirmed) {
      await _runModerationAction(
        reportId: report.id,
        action: () => widget.api.rejectReport(report.id),
        successMessage: 'Đã bác bỏ báo cáo.',
      );
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    required bool danger,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: adminDanger)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _runModerationAction({
    required String reportId,
    required Future<AdminDocumentReport> Function() action,
    required String successMessage,
  }) async {
    setState(() => _busyReportId = reportId);

    try {
      await action();

      if (!mounted) {
        return;
      }

      await _refresh();
      _showMessage(successMessage);
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Không thể xử lý báo cáo tài liệu.');
    } finally {
      if (mounted) {
        setState(() => _busyReportId = null);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: adminDanger),
    );
  }

  String _formatError(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Không thể tải danh sách báo cáo tài liệu.';
  }
}

class _ModerationFilters extends StatelessWidget {
  const _ModerationFilters({
    required this.activeTab,
    required this.pendingCount,
    required this.historyCount,
    required this.query,
    required this.fileType,
    required this.fileTypes,
    required this.onTabChanged,
    required this.onQueryChanged,
    required this.onFileTypeChanged,
  });

  final int activeTab;
  final int pendingCount;
  final int historyCount;
  final String query;
  final String fileType;
  final List<String> fileTypes;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onFileTypeChanged;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _TabButton(
                  selected: activeTab == 0,
                  label: 'Báo cáo',
                  count: pendingCount,
                  icon: Icons.report_problem_outlined,
                  onTap: () => onTabChanged(0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TabButton(
                  selected: activeTab == 1,
                  label: 'Lịch sử',
                  count: historyCount,
                  icon: Icons.history_outlined,
                  onTap: () => onTabChanged(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: onQueryChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Tìm tài liệu, lý do, người báo cáo',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: fileTypes.contains(fileType)
                ? fileType
                : _allFileTypes,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.filter_alt_outlined),
              labelText: 'Loại tệp',
            ),
            items: fileTypes
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(type == _allFileTypes ? 'Tất cả' : type),
                  ),
                )
                .toList(),
            onChanged: onFileTypeChanged,
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.selected,
    required this.label,
    required this.count,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final int count;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? adminPrimary : adminMuted;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? adminPrimary.withValues(alpha: 0.1)
              : adminSurfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? adminPrimary : adminBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                '$label ($count)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingReportCard extends StatelessWidget {
  const _PendingReportCard({
    required this.report,
    required this.busy,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onReject,
    required this.onApprove,
  });

  final AdminDocumentReport report;
  final bool busy;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      borderColor: adminWarning.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportHeader(report: report),
          const SizedBox(height: 12),
          _ReasonBox(reason: report.reason),
          const SizedBox(height: 12),
          if (expanded) ...[
            _ReportDetails(report: report),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              TextButton.icon(
                onPressed: onToggleExpanded,
                icon: Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
                label: Text(expanded ? 'Thu gọn' : 'Chi tiết'),
              ),
              const Spacer(),
              if (busy)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  icon: const Icon(Icons.close),
                  label: const Text('Bác bỏ'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: adminDanger),
                  onPressed: busy ? null : onApprove,
                  icon: const Icon(Icons.visibility_off_outlined),
                  label: const Text('Ẩn / Xóa'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryReportCard extends StatelessWidget {
  const _HistoryReportCard({required this.report});

  final AdminDocumentReport report;

  @override
  Widget build(BuildContext context) {
    final color = adminReportStatusColor(report.status);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportHeader(report: report),
          const SizedBox(height: 12),
          AdminCard(
            padding: const EdgeInsets.all(12),
            backgroundColor: color.withValues(alpha: 0.08),
            borderColor: color.withValues(alpha: 0.18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminPill(
                  label: adminReportStatusLabel(report.status),
                  color: color,
                ),
                const SizedBox(height: 10),
                Text(
                  report.moderationResult ?? _defaultResult(report.status),
                  style: const TextStyle(
                    color: adminText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Người xử lý: ${report.moderatorName ?? report.moderatorEmail ?? report.moderatorId ?? 'Không rõ'}',
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

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.report});

  final AdminDocumentReport report;

  @override
  Widget build(BuildContext context) {
    final statusColor = adminReportStatusColor(report.status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: adminBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.description_outlined, color: adminBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.documentName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: adminText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Báo cáo bởi ${report.reporterName ?? report.reporterEmail ?? report.reporterId}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: adminMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AdminPill(
                    label: adminReportStatusLabel(report.status),
                    color: statusColor,
                  ),
                  AdminPill(
                    label: fileExtensionFromName(report.documentName),
                    color: adminBlue,
                  ),
                  AdminPill(
                    label: adminDocumentStatusLabel(report.documentStatus),
                    color: adminMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReasonBox extends StatelessWidget {
  const _ReasonBox({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: adminDanger.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lý do báo cáo',
            style: TextStyle(color: adminDanger, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(reason, style: const TextStyle(color: adminText, height: 1.35)),
        ],
      ),
    );
  }
}

class _ReportDetails extends StatelessWidget {
  const _ReportDetails({required this.report});

  final AdminDocumentReport report;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(12),
      backgroundColor: adminSurfaceSoft,
      child: Column(
        children: [
          _DetailRow(label: 'Mã báo cáo', value: report.id),
          const Divider(height: 18),
          _DetailRow(label: 'Mã tài liệu', value: report.documentId),
          const Divider(height: 18),
          _DetailRow(
            label: 'Người báo cáo',
            value: report.reporterEmail ?? report.reporterId,
          ),
          const Divider(height: 18),
          _DetailRow(
            label: 'Ngày gửi',
            value: formatAdminDateTime(report.createdAt),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(color: adminMuted, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: adminText,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModerationData {
  const _ModerationData({required this.pending, required this.history});

  final List<AdminDocumentReport> pending;
  final List<AdminDocumentReport> history;
}

List<String> _availableFileTypes(List<AdminDocumentReport> reports) {
  final types =
      reports
          .map((report) => fileExtensionFromName(report.documentName))
          .toSet()
          .toList()
        ..sort();
  return [_allFileTypes, ...types];
}

int _sortNewestFirst(AdminDocumentReport a, AdminDocumentReport b) {
  final aTime =
      a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final bTime =
      b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return bTime.compareTo(aTime);
}

String _defaultResult(AdminReportStatus status) {
  return switch (status) {
    AdminReportStatus.approved => 'Báo cáo hợp lệ, tài liệu đã được ẩn/xóa.',
    AdminReportStatus.rejected =>
      'Báo cáo không hợp lệ, tài liệu được giữ lại.',
    AdminReportStatus.pending => 'Báo cáo đang chờ xử lý.',
  };
}

const _allFileTypes = 'ALL';
