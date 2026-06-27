import 'package:flutter/material.dart';

import '../../models/auth_models.dart';
import '../../models/system_admin_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/system_admin_api_service.dart';
import 'widgets/system_admin_common.dart';

class SystemAdminUsersPage extends StatefulWidget {
  const SystemAdminUsersPage({
    super.key,
    required this.api,
    required this.currentUserId,
  });

  final SystemAdminApiService api;
  final String currentUserId;

  @override
  State<SystemAdminUsersPage> createState() => _SystemAdminUsersPageState();
}

class _SystemAdminUsersPageState extends State<SystemAdminUsersPage> {
  late Future<List<ManagedUser>> _future;
  String _query = '';
  UserRoleCode? _roleFilter;
  ManagedUserStatus? _statusFilter;
  String? _busyUserId;

  @override
  void initState() {
    super.initState();
    _future = widget.api.listUsers();
  }

  Future<void> _refresh() async {
    final next = widget.api.listUsers();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ManagedUser>>(
      future: _future,
      builder: (context, snapshot) {
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: systemAdminPagePadding(context),
            children: [
              _UsersHeader(onCreateUser: _openCreateUserDialog),
              const SizedBox(height: 14),
              _Filters(
                query: _query,
                roleFilter: _roleFilter,
                statusFilter: _statusFilter,
                onQueryChanged: (value) => setState(() => _query = value),
                onRoleChanged: (value) => setState(() => _roleFilter = value),
                onStatusChanged: (value) {
                  setState(() => _statusFilter = value);
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
                _UserList(
                  users: _filterUsers(snapshot.data ?? const []),
                  currentUserId: widget.currentUserId,
                  busyUserId: _busyUserId,
                  onStatusChanged: _updateStatus,
                  onRoleChanged: _updateRole,
                  onTemporaryPasswordRequested: _issueTemporaryPassword,
                ),
            ],
          ),
        );
      },
    );
  }

  List<ManagedUser> _filterUsers(List<ManagedUser> users) {
    final normalizedQuery = _query.trim().toLowerCase();

    return users.where((user) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          user.fullName.toLowerCase().contains(normalizedQuery) ||
          user.email.toLowerCase().contains(normalizedQuery) ||
          user.id.toLowerCase().contains(normalizedQuery);

      final matchesRole =
          _roleFilter == null || user.role.roleCode == _roleFilter;
      final matchesStatus =
          _statusFilter == null || user.status == _statusFilter;

      return matchesQuery && matchesRole && matchesStatus;
    }).toList();
  }

  Future<void> _openCreateUserDialog() async {
    final input = await showDialog<_CreateUserInput>(
      context: context,
      builder: (context) => const _CreateUserDialog(),
    );

    if (input == null) {
      return;
    }

    try {
      final result = await widget.api.createAdminUser(
        email: input.email,
        fullName: input.fullName,
        roleCode: input.roleCode,
      );

      if (!mounted) {
        return;
      }

      _showTemporaryPassword(
        userName: result.user.fullName,
        password: result.temporaryPassword,
        expiresAt: result.temporaryPasswordExpiresAt,
      );

      final currentData = await _future.then(
        (list) => list,
        onError: (_) => <ManagedUser>[],
      );
      setState(() {
        _future = Future.value([...currentData, result.user]);
      });

      // Refresh ngầm để đồng bộ dữ liệu chính xác từ server
      _refresh().catchError((_) {});
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Không thể tạo tài khoản quản trị.');
    }
  }

  Future<void> _updateStatus(ManagedUser user, ManagedUserStatus status) async {
    setState(() => _busyUserId = user.id);

    try {
      final result = await widget.api.updateUserStatus(
        userId: user.id,
        status: status,
      );

      if (!mounted) {
        return;
      }

      final currentData = await _future.then(
        (list) => list,
        onError: (_) => <ManagedUser>[],
      );

      setState(() {
        _future = Future.value(
          currentData
              .map((item) => item.id == result.user.id ? result.user : item)
              .toList(),
        );
      });

      // Refresh ngầm để đồng bộ lại từ server.
      // Nếu refresh lỗi thì không báo "không thể cập nhật trạng thái",
      // vì cập nhật trạng thái thực tế đã thành công.
      _refresh().catchError((error) {
        debugPrint('Refresh users after status update failed: $error');
      });

      if (result.temporaryPassword != null) {
        _showTemporaryPassword(
          userName: result.user.fullName,
          password: result.temporaryPassword!,
          expiresAt: result.temporaryPasswordExpiresAt,
        );
      }
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Không thể cập nhật trạng thái người dùng: $error');
    } finally {
      if (mounted) {
        setState(() => _busyUserId = null);
      }
    }
  }

  Future<void> _issueTemporaryPassword(ManagedUser user) {
    return _updateStatus(user, ManagedUserStatus.passwordChangeRequired);
  }

  Future<void> _updateRole(ManagedUser user, UserRoleCode roleCode) async {
    setState(() => _busyUserId = user.id);

    try {
      final result = await widget.api.updateUserRole(
        userId: user.id,
        roleCode: roleCode,
      );

      if (!mounted) {
        return;
      }

      final currentData = await _future.then(
        (list) => list,
        onError: (_) => <ManagedUser>[],
      );

      setState(() {
        _future = Future.value(
          currentData
              .map((item) => item.id == result.id ? result : item)
              .toList(),
        );
      });

      _refresh().catchError((error) {
        debugPrint('Refresh users after role update failed: $error');
      });
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Không thể cập nhật vai trò người dùng: $error');
    } finally {
      if (mounted) {
        setState(() => _busyUserId = null);
      }
    }
  }

  void _showTemporaryPassword({
    required String userName,
    required String password,
    required DateTime? expiresAt,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mật khẩu tạm thời'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tài khoản: $userName'),
            const SizedBox(height: 12),
            SelectableText(
              password,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text('Hết hạn: ${formatDateTime(expiresAt)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đã ghi nhận'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  String _formatError(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Không thể tải danh sách người dùng.';
  }
}

class _UsersHeader extends StatelessWidget {
  const _UsersHeader({required this.onCreateUser});

  final VoidCallback onCreateUser;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: onCreateUser,
      icon: const Icon(Icons.person_add_alt_1_outlined),
      label: const Text('Tạo tài khoản'),
    );

    if (systemAdminIsCompact(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SystemAdminSectionTitle(title: 'Quản lý người dùng'),
          const SizedBox(height: 12),
          button,
        ],
      );
    }

    return SystemAdminSectionTitle(
      title: 'Quản lý người dùng',
      trailing: button,
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.query,
    required this.roleFilter,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onRoleChanged,
    required this.onStatusChanged,
  });

  final String query;
  final UserRoleCode? roleFilter;
  final ManagedUserStatus? statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<UserRoleCode?> onRoleChanged;
  final ValueChanged<ManagedUserStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return SystemAdminCard(
      child: Column(
        children: [
          TextField(
            onChanged: onQueryChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Tìm theo tên, email hoặc ID',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<UserRoleCode>(
                  key: ValueKey(roleFilter),
                  initialValue: roleFilter,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    labelText: 'Vai trò',
                  ),
                  items: UserRoleCode.values
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(_roleLabel(role)),
                        ),
                      )
                      .toList(),
                  onChanged: onRoleChanged,
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Xóa lọc vai trò',
                onPressed: roleFilter == null
                    ? null
                    : () => onRoleChanged(null),
                icon: const Icon(Icons.filter_alt_off_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ManagedUserStatus>(
                  key: ValueKey(statusFilter),
                  initialValue: statusFilter,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.verified_user_outlined),
                    labelText: 'Trạng thái',
                  ),
                  items: ManagedUserStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(statusLabel(status)),
                        ),
                      )
                      .toList(),
                  onChanged: onStatusChanged,
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Xóa lọc trạng thái',
                onPressed: statusFilter == null
                    ? null
                    : () => onStatusChanged(null),
                icon: const Icon(Icons.filter_alt_off_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  const _UserList({
    required this.users,
    required this.currentUserId,
    required this.busyUserId,
    required this.onStatusChanged,
    required this.onRoleChanged,
    required this.onTemporaryPasswordRequested,
  });

  final List<ManagedUser> users;
  final String currentUserId;
  final String? busyUserId;
  final void Function(ManagedUser user, ManagedUserStatus status)
  onStatusChanged;
  final void Function(ManagedUser user, UserRoleCode roleCode) onRoleChanged;
  final ValueChanged<ManagedUser> onTemporaryPasswordRequested;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const SystemAdminEmptyState(
        icon: Icons.people_outline,
        message: 'Không có người dùng phù hợp.',
      );
    }

    return Column(
      children: users
          .map(
            (user) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _UserTile(
                user: user,
                currentUserId: currentUserId,
                busy: busyUserId == user.id,
                onStatusChanged: onStatusChanged,
                onRoleChanged: onRoleChanged,
                onTemporaryPasswordRequested: onTemporaryPasswordRequested,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.currentUserId,
    required this.busy,
    required this.onStatusChanged,
    required this.onRoleChanged,
    required this.onTemporaryPasswordRequested,
  });

  final ManagedUser user;
  final String currentUserId;
  final bool busy;
  final void Function(ManagedUser user, ManagedUserStatus status)
  onStatusChanged;
  final void Function(ManagedUser user, UserRoleCode roleCode) onRoleChanged;
  final ValueChanged<ManagedUser> onTemporaryPasswordRequested;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(user.status);
    final isActive = user.status == ManagedUserStatus.active;
    final roleCode = user.role.roleCode;
    final isSelf = user.id == currentUserId;
    final isSelfSystemAdmin = isSelf && roleCode == UserRoleCode.systemAdmin;

    return SystemAdminCard(
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.16),
                child: Text(
                  user.fullName.isNotEmpty
                      ? user.fullName.characters.first.toUpperCase()
                      : 'U',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: systemAdminMuted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(
                          label: _roleLabel(roleCode),
                          color: systemAdminAccent,
                        ),
                        _Pill(label: statusLabel(user.status), color: color),
                      ],
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
                Switch(
                  value: isActive,
                  onChanged: isSelfSystemAdmin
                      ? null
                      : (value) => onStatusChanged(
                          user,
                          value
                              ? ManagedUserStatus.active
                              : ManagedUserStatus.locked,
                        ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<UserRoleCode>(
                  key: ValueKey('${user.id}-${roleCode?.value ?? 'unknown'}'),
                  initialValue: roleCode,
                  decoration: const InputDecoration(labelText: 'Vai trò'),
                  items: UserRoleCode.values
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(_roleLabel(role)),
                        ),
                      )
                      .toList(),
                  onChanged: busy || roleCode == null
                      ? null
                      : (value) {
                          if (value != null && value != roleCode) {
                            onRoleChanged(user, value);
                          }
                        },
                ),
              ),
              if (user.role.roleCode == UserRoleCode.admin) ...[
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: 'Cấp mật khẩu tạm',
                  onPressed: busy
                      ? null
                      : () => onTemporaryPasswordRequested(user),
                  icon: const Icon(Icons.password_outlined),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  UserRoleCode _roleCode = UserRoleCode.admin;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tạo tài khoản quản trị'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Họ tên'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Vui lòng nhập họ tên';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (!email.contains('@')) {
                    return 'Email không hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRoleCode>(
                initialValue: _roleCode,
                decoration: const InputDecoration(labelText: 'Vai trò'),
                items: const [
                  DropdownMenuItem(
                    value: UserRoleCode.admin,
                    child: Text('Admin'),
                  ),
                  DropdownMenuItem(
                    value: UserRoleCode.systemAdmin,
                    child: Text('Quản trị viên'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _roleCode = value);
                  }
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
              _CreateUserInput(
                fullName: _fullNameController.text.trim(),
                email: _emailController.text.trim(),
                roleCode: _roleCode,
              ),
            );
          },
          child: const Text('Tạo'),
        ),
      ],
    );
  }
}

class _CreateUserInput {
  const _CreateUserInput({
    required this.fullName,
    required this.email,
    required this.roleCode,
  });

  final String fullName;
  final String email;
  final UserRoleCode roleCode;
}

String _roleLabel(UserRoleCode? roleCode) {
  return switch (roleCode) {
    UserRoleCode.student => 'Sinh viên',
    UserRoleCode.admin => 'Admin',
    UserRoleCode.systemAdmin => 'Quản trị viên',
    null => 'Không rõ',
  };
}
