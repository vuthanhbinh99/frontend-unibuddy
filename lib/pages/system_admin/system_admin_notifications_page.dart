import 'package:flutter/material.dart';

import '../../models/system_admin_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/system_admin_api_service.dart';
import 'widgets/system_admin_common.dart';

class SystemAdminNotificationsPage extends StatefulWidget {
  const SystemAdminNotificationsPage({super.key, required this.api});

  final SystemAdminApiService api;

  @override
  State<SystemAdminNotificationsPage> createState() =>
      _SystemAdminNotificationsPageState();
}

class _SystemAdminNotificationsPageState
    extends State<SystemAdminNotificationsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  SystemNotificationAudience _audience = SystemNotificationAudience.all;
  SystemNotificationResult? _lastResult;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: systemAdminPagePadding(context),
      children: [
        const SystemAdminSectionTitle(title: 'Thông báo hệ thống'),
        const SizedBox(height: 14),
        SystemAdminCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.title),
                    labelText: 'Tiêu đề',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return 'Vui lòng nhập tiêu đề';
                    }
                    if (text.length > 150) {
                      return 'Tiêu đề tối đa 150 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contentController,
                  minLines: 5,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.notes_outlined),
                    labelText: 'Nội dung',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return 'Vui lòng nhập nội dung';
                    }
                    if (text.length > 4000) {
                      return 'Nội dung tối đa 4000 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<SystemNotificationAudience>(
                  initialValue: _audience,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.groups_2_outlined),
                    labelText: 'Đối tượng nhận',
                  ),
                  items: SystemNotificationAudience.values
                      .map(
                        (audience) => DropdownMenuItem(
                          value: audience,
                          child: Text(audience.label),
                        ),
                      )
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _audience = value);
                          }
                        },
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(_submitting ? 'Đang gửi...' : 'Phát hành'),
                ),
              ],
            ),
          ),
        ),
        if (_lastResult != null) ...[
          const SizedBox(height: 18),
          _DispatchResultCard(result: _lastResult!),
        ],
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) {
      return;
    }

    setState(() => _submitting = true);

    try {
      final result = await widget.api.sendSystemNotification(
        title: _titleController.text,
        content: _contentController.text,
        audience: _audience,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastResult = result;
        _titleController.clear();
        _contentController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã tạo ${result.notificationCount} thông báo cho ${result.recipientCount} người nhận.',
          ),
        ),
      );
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Không thể gửi thông báo hệ thống.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }
}

class _DispatchResultCard extends StatelessWidget {
  const _DispatchResultCard({required this.result});

  final SystemNotificationResult result;

  @override
  Widget build(BuildContext context) {
    return SystemAdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kết quả phát hành',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ResultPill(
                label: 'Người nhận',
                value: result.recipientCount.toString(),
                color: systemAdminInfo,
              ),
              _ResultPill(
                label: 'Bản ghi',
                value: result.notificationCount.toString(),
                color: systemAdminAccent,
              ),
              _ResultPill(
                label: 'Token FCM',
                value: result.fcm.tokenCount.toString(),
                color: systemAdminMutedStrong,
              ),
              _ResultPill(
                label: 'Thành công',
                value: result.fcm.successCount.toString(),
                color: systemAdminSuccess,
              ),
              _ResultPill(
                label: 'Thất bại',
                value: result.fcm.failureCount.toString(),
                color: systemAdminDanger,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
