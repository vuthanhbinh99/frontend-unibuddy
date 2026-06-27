import 'package:flutter/material.dart';

import '../../models/admin_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/admin_api_service.dart';
import 'widgets/admin_common.dart';

class AdminSchoolsPage extends StatefulWidget {
  const AdminSchoolsPage({super.key, required this.api});

  final AdminApiService api;

  @override
  State<AdminSchoolsPage> createState() => _AdminSchoolsPageState();
}

class _AdminSchoolsPageState extends State<AdminSchoolsPage> {
  late Future<List<AdminSchool>> _future;
  String _query = '';
  String? _busyCode;

  @override
  void initState() {
    super.initState();
    _future = widget.api.listSchools();
  }

  Future<void> _refresh() async {
    final next = widget.api.listSchools();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminSchool>>(
      future: _future,
      builder: (context, snapshot) {
        final schools = snapshot.data ?? const <AdminSchool>[];
        final filteredSchools = _filterSchools(schools);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: adminPagePadding(context),
            children: [
              _SchoolsHeader(onCreateSchool: () => _openSchoolDialog()),
              const SizedBox(height: 14),
              _SearchBox(
                query: _query,
                totalCount: schools.length,
                filteredCount: filteredSchools.length,
                onChanged: (value) => setState(() => _query = value),
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
              else if (filteredSchools.isEmpty)
                const AdminEmptyState(
                  icon: Icons.school_outlined,
                  message: 'Không có trường phù hợp.',
                )
              else
                ...filteredSchools.map(
                  (school) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SchoolCard(
                      school: school,
                      busy: _busyCode == school.code,
                      onEdit: () => _openSchoolDialog(school: school),
                      onDelete: () => _confirmDelete(school),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<AdminSchool> _filterSchools(List<AdminSchool> schools) {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return schools;
    }

    return schools.where((school) {
      return school.code.toLowerCase().contains(normalizedQuery) ||
          school.name.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  Future<void> _openSchoolDialog({AdminSchool? school}) async {
    final input = await showDialog<_SchoolInput>(
      context: context,
      builder: (context) => _SchoolDialog(school: school),
    );

    if (input == null) {
      return;
    }

    final code = input.code.toUpperCase();
    setState(() => _busyCode = code);

    try {
      if (school == null) {
        await widget.api.createSchool(code: code, name: input.name);
      } else {
        await widget.api.updateSchool(code: code, name: input.name);
      }

      if (!mounted) {
        return;
      }

      await _refresh();
      _showMessage(
        school == null ? 'Đã thêm trường mới.' : 'Đã cập nhật trường.',
      );
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Không thể lưu thông tin trường.');
    } finally {
      if (mounted) {
        setState(() => _busyCode = null);
      }
    }
  }

  Future<void> _confirmDelete(AdminSchool school) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa trường?'),
        content: Text(
          'Trường ${school.code} sẽ bị xóa nếu backend cho phép và không còn dữ liệu liên kết.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: adminDanger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _busyCode = school.code);

    try {
      await widget.api.deleteSchool(school.code);

      if (!mounted) {
        return;
      }

      await _refresh();
      _showMessage('Đã xóa ${school.code}.');
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Không thể xóa trường.');
    } finally {
      if (mounted) {
        setState(() => _busyCode = null);
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
    return 'Không thể tải danh mục trường.';
  }
}

class _SchoolsHeader extends StatelessWidget {
  const _SchoolsHeader({required this.onCreateSchool});

  final VoidCallback onCreateSchool;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: onCreateSchool,
      icon: const Icon(Icons.add),
      label: const Text('Thêm trường'),
    );

    if (adminIsCompact(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminSectionHeader(
            title: 'Danh mục trường',
            subtitle: 'Quản lý mã trường và tên trường từ backend.',
          ),
          const SizedBox(height: 12),
          button,
        ],
      );
    }

    return AdminSectionHeader(
      title: 'Danh mục trường',
      subtitle: 'Quản lý mã trường và tên trường từ backend.',
      trailing: button,
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.query,
    required this.totalCount,
    required this.filteredCount,
    required this.onChanged,
  });

  final String query;
  final int totalCount;
  final int filteredCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: onChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Tìm theo mã hoặc tên trường',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AdminPill(label: '$totalCount trường', color: adminPrimary),
              if (query.trim().isNotEmpty)
                AdminPill(label: '$filteredCount phù hợp', color: adminBlue),
            ],
          ),
        ],
      ),
    );
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({
    required this.school,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminSchool school;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: adminText,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      school.code,
                      style: const TextStyle(
                        color: adminMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                PopupMenuButton<_SchoolAction>(
                  tooltip: 'Thao tác',
                  onSelected: (action) {
                    switch (action) {
                      case _SchoolAction.edit:
                        onEdit();
                      case _SchoolAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _SchoolAction.edit,
                      child: Text('Chỉnh sửa'),
                    ),
                    PopupMenuItem(
                      value: _SchoolAction.delete,
                      child: Text('Xóa'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.update, color: adminMuted, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Cập nhật: ${formatAdminDateTime(school.updatedAt ?? school.createdAt)}',
                  style: const TextStyle(color: adminMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SchoolDialog extends StatefulWidget {
  const _SchoolDialog({this.school});

  final AdminSchool? school;

  @override
  State<_SchoolDialog> createState() => _SchoolDialogState();
}

class _SchoolDialogState extends State<_SchoolDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.school?.code ?? '');
    _nameController = TextEditingController(text: widget.school?.name ?? '');
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.school != null;

    return AlertDialog(
      title: Text(isEditing ? 'Chỉnh sửa trường' : 'Thêm trường'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codeController,
                enabled: !isEditing,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Mã trường'),
                validator: (value) {
                  final code = (value ?? '').trim();
                  if (code.isEmpty) {
                    return 'Vui lòng nhập mã trường';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Tên trường'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Vui lòng nhập tên trường';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            Navigator.of(context).pop(
              _SchoolInput(
                code: _codeController.text.trim(),
                name: _nameController.text.trim(),
              ),
            );
          },
          child: Text(isEditing ? 'Lưu' : 'Thêm'),
        ),
      ],
    );
  }
}

enum _SchoolAction { edit, delete }

class _SchoolInput {
  const _SchoolInput({required this.code, required this.name});

  final String code;
  final String name;
}
