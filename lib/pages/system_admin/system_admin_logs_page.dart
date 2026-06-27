import 'package:flutter/material.dart';

import '../../models/system_admin_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/system_admin_api_service.dart';
import 'widgets/system_admin_common.dart';

class SystemAdminLogsPage extends StatefulWidget {
  const SystemAdminLogsPage({super.key, required this.api});

  final SystemAdminApiService api;

  @override
  State<SystemAdminLogsPage> createState() => _SystemAdminLogsPageState();
}

class _SystemAdminLogsPageState extends State<SystemAdminLogsPage> {
  bool _showErrors = false;
  bool _isRefreshing = false;
  int _page = 1;
  AuditLogLevel? _level;
  late Future<PaginatedAuditLogs> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<PaginatedAuditLogs> _load() {
    if (_showErrors) {
      return widget.api.listErrorLogs(page: _page);
    }

    return widget.api.listAuditLogs(page: _page, level: _level);
  }

  Future<void> _refresh({bool resetPage = false}) async {
    final oldPage = _page;

    if (resetPage) {
      _page = 1;
    }

    try {
      final result = await _load();

      if (!mounted) {
        return;
      }

      setState(() {
        _future = Future.value(result);
      });
    } catch (error) {
      _page = oldPage;
      rethrow;
    }
  }

    Future<void> _refreshFromButton() async {
    if (_isRefreshing) {
      return;
    }

    setState(() => _isRefreshing = true);

    try {
      await _refresh();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể làm mới log hệ thống: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _reload({bool resetPage = false}) {
    setState(() {
      if (resetPage) {
        _page = 1;
      }
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PaginatedAuditLogs>(
      future: _future,
      builder: (context, snapshot) {
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: systemAdminPagePadding(context),
            children: [
              SystemAdminSectionTitle(
                title: 'Log hệ thống',
                trailing: IconButton(
                  tooltip: 'Làm mới',
                  onPressed: _isRefreshing ? null : _refreshFromButton,
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ),
              const SizedBox(height: 12),
              _LogToolbar(
                showErrors: _showErrors,
                level: _level,
                onModeChanged: (showErrors) {
                  setState(() {
                    _showErrors = showErrors;
                    _page = 1;
                    _future = _load();
                  });
                },
                onLevelChanged: (level) {
                  setState(() {
                    _level = level;
                    _page = 1;
                    _future = _load();
                  });
                },
              ),
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
                _LogList(
                  result: snapshot.data!,
                  showErrors: _showErrors,
                  onPreviousPage: _page > 1
                      ? () {
                          _page -= 1;
                          _reload();
                        }
                      : null,
                  onNextPage: _page < snapshot.data!.totalPages
                      ? () {
                          _page += 1;
                          _reload();
                        }
                      : null,
                  onSelectLog: _showLogDetail,
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showLogDetail(AuditLogEntry log) async {
    var detail = log;

    if (_showErrors) {
      try {
        detail = await widget.api.getErrorLogDetail(log.id);
      } catch (_) {
        detail = log;
      }
    }

    if (!mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => _LogDetailDialog(log: detail),
    );
  }

  String _formatError(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Không thể tải log hệ thống.';
  }
}

class _LogToolbar extends StatelessWidget {
  const _LogToolbar({
    required this.showErrors,
    required this.level,
    required this.onModeChanged,
    required this.onLevelChanged,
  });

  final bool showErrors;
  final AuditLogLevel? level;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<AuditLogLevel?> onLevelChanged;

  @override
  Widget build(BuildContext context) {
    return SystemAdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.receipt_long_outlined),
                label: Text('Audit'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.report_problem_outlined),
                label: Text('Lỗi'),
              ),
            ],
            selected: {showErrors},
            onSelectionChanged: (values) => onModeChanged(values.first),
          ),
          if (!showErrors) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<AuditLogLevel>(
                    key: ValueKey(level),
                    initialValue: level,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.filter_alt_outlined),
                      labelText: 'Lọc mức độ',
                    ),
                    items: AuditLogLevel.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.value),
                          ),
                        )
                        .toList(),
                    onChanged: onLevelChanged,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: 'Xóa lọc',
                  onPressed: level == null ? null : () => onLevelChanged(null),
                  icon: const Icon(Icons.filter_alt_off_outlined),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  const _LogList({
    required this.result,
    required this.showErrors,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onSelectLog,
  });

  final PaginatedAuditLogs result;
  final bool showErrors;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<AuditLogEntry> onSelectLog;

  @override
  Widget build(BuildContext context) {
    if (result.items.isEmpty) {
      return SystemAdminEmptyState(
        icon: showErrors
            ? Icons.report_problem_outlined
            : Icons.receipt_long_outlined,
        message: showErrors
            ? 'Chưa có log lỗi nghiêm trọng.'
            : 'Chưa có audit log phù hợp.',
      );
    }

    return Column(
      children: [
        ...result.items.map(
          (log) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LogTile(log: log, onTap: () => onSelectLog(log)),
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final pageLabel =
                'Trang ${result.page}/${result.totalPages == 0 ? 1 : result.totalPages} • ${result.total} bản ghi';
            final controls = Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPreviousPage,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Trước'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onNextPage,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Sau'),
                  ),
                ),
              ],
            );

            if (constraints.maxWidth < 430) {
              return Column(
                children: [
                  Text(
                    pageLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: systemAdminMuted),
                  ),
                  const SizedBox(height: 10),
                  controls,
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPreviousPage,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Trước'),
                  ),
                ),
                Expanded(
                  child: Text(
                    pageLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: systemAdminMuted),
                  ),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onNextPage,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Sau'),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log, required this.onTap});

  final AuditLogEntry log;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = levelColor(log.level);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SystemAdminCard(
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Text(
                log.level.value.characters.first,
                style: TextStyle(fontWeight: FontWeight.w900, color: color),
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
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log.message ?? log.actorEmail ?? log.tableName ?? '--',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: systemAdminMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatDateTime(log.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: systemAdminMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _LogDetailDialog extends StatelessWidget {
  const _LogDetailDialog({required this.log});

  final AuditLogEntry log;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chi tiết log'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(label: 'ID', value: log.id),
            _DetailRow(label: 'Mức độ', value: log.level.value),
            _DetailRow(label: 'Hành động', value: log.action),
            _DetailRow(label: 'Người thực hiện', value: log.actorEmail ?? '--'),
            _DetailRow(label: 'Bảng', value: log.tableName ?? '--'),
            _DetailRow(label: 'Record', value: log.recordId ?? '--'),
            _DetailRow(
              label: 'Thời gian',
              value: formatDateTime(log.createdAt),
            ),
            _DetailRow(label: 'Nội dung', value: log.message ?? '--'),
            if (log.metadata != null)
              _DetailRow(label: 'Metadata', value: log.metadata.toString()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: systemAdminMuted),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
