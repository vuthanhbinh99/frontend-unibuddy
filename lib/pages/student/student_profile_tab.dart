import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/auth_models.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/student_api_service.dart';
import 'student_theme.dart';
import 'widgets/student_notification_dropdown.dart';

class StudentProfileTab extends StatefulWidget {
  const StudentProfileTab({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onRefresh,
    required this.studentApi,
    required this.onViewAllNotifications,
    this.showAppBar = false,
  });

  final PublicUser user;
  final Future<void> Function() onLogout;
  final Future<void> Function() onRefresh;
  final StudentApiService studentApi;
  final VoidCallback onViewAllNotifications;
  final bool showAppBar;

  @override
  State<StudentProfileTab> createState() => _StudentProfileTabState();
}

class _StudentProfileTabState extends State<StudentProfileTab> {
  final _formKey = GlobalKey<FormState>();
  late String _fullName;
  late String _email;
  late String _phone;
  bool _uploadingAvatar = false;
  bool _savingProfile = false;

  static const int _avatarMaxBytes = 10 * 1024 * 1024;
  static const Map<String, String> _avatarMimeByExtension = {
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
  };

  @override
  void initState() {
    super.initState();
    _syncFromUser();
  }

  @override
  void didUpdateWidget(covariant StudentProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.updatedAt != widget.user.updatedAt) {
      _syncFromUser();
    }
  }

  void _syncFromUser() {
    _fullName = widget.user.fullName;
    _email = widget.user.email;
    _phone = widget.user.phoneNumber ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: widget.showAppBar
            ? AppBar(
                backgroundColor: colors.background,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: colors.text),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Text(
                  l10n.t('student.profile.title'),
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  StudentNotificationBell(
                    studentApi: widget.studentApi,
                    onViewAll: widget.onViewAllNotifications,
                  ),
                  const SizedBox(width: 8),
                ],
              )
            : null,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.showAppBar) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 40),
                        Text(
                          l10n.t('student.profile.headerTitle'),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                            letterSpacing: -0.5,
                          ),
                        ),
                        StudentNotificationBell(
                          studentApi: widget.studentApi,
                          onViewAll: widget.onViewAllNotifications,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ] else
                    const SizedBox(height: 12),
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                          child: Stack(
                            children: [
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  image: widget.user.avatarUrl == null
                                      ? null
                                      : DecorationImage(
                                          image: NetworkImage(
                                            widget.user.avatarUrl!,
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                  color: colors.surface,
                                  border: Border.all(
                                    color: const Color(
                                      0xFF6366F1,
                                    ).withValues(alpha: 0.2),
                                    width: 2,
                                  ),
                                ),
                                child: widget.user.avatarUrl == null
                                    ? Center(
                                        child: Text(
                                          _avatarInitial(widget.user.fullName),
                                          style: TextStyle(
                                            color: colors.text,
                                            fontSize: 46,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: colors.primaryStrong,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.background,
                                      width: 2,
                                    ),
                                  ),
                                  child: _uploadingAvatar
                                      ? const Padding(
                                          padding: EdgeInsets.all(9),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt_outlined,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _fullName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.user.role.displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF818CF8),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildInputField(
                    label: l10n.t('student.profile.fullName'),
                    initialValue: _fullName,
                    icon: Icons.person_outline,
                    onChanged: (value) => setState(() => _fullName = value),
                  ),
                  const SizedBox(height: 18),
                  _buildInputField(
                    label: l10n.t('student.profile.email'),
                    initialValue: _email,
                    icon: Icons.mail_outline,
                    enabled: false,
                    onChanged: (value) => setState(() => _email = value),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.t('student.profile.emailReadonly'),
                    style: TextStyle(
                      color: colors.textSubtle,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildInputField(
                    label: l10n.t('student.profile.phone'),
                    initialValue: _phone,
                    icon: Icons.phone_outlined,
                    onChanged: (value) => setState(() => _phone = value),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _labelWithFallback(
                                l10n,
                                'student.profile.dataSection',
                                vietnamese: 'Dữ liệu cá nhân',
                                english: 'Personal data',
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.textMuted,
                                letterSpacing: 0.4,
                              ),
                            ),
                            Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: colors.textSubtle,
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: colors.border),
                        ),
                        _buildInfoRow(
                          l10n.t('student.profile.status'),
                          widget.user.statusLabel,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          l10n.t('student.profile.role'),
                          widget.user.role.displayName,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _savingProfile ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Text(
                        _labelWithFallback(
                          l10n,
                          'student.profile.updateButton',
                          vietnamese: 'Cập nhật',
                          english: 'Update',
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String initialValue,
    required IconData icon,
    bool enabled = true,
    required ValueChanged<String> onChanged,
  }) {
    final colors = StudentThemeScope.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: colors.textSubtle,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initialValue,
          enabled: enabled,
          onChanged: onChanged,
          style: TextStyle(fontSize: 15, color: colors.text),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: colors.textSubtle, size: 18),
            filled: true,
            fillColor: colors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.primaryStrong, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final colors = StudentThemeScope.colorsOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: colors.textSubtle, fontSize: 13)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: colors.text,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final l10n = context.l10n;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _avatarMimeByExtension.keys.toList(),
      withData: false,
    );

    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }

    final file = picked.files.single;
    final extension = (file.extension ?? '').toLowerCase();
    final mimeType = _avatarMimeByExtension[extension];

    if (mimeType == null) {
      _showSnack(l10n.t('student.profile.avatar.invalidType'));
      return;
    }

    if (file.size <= 0 || file.size > _avatarMaxBytes) {
      _showSnack(l10n.t('student.profile.avatar.tooLarge'));
      return;
    }

    setState(() => _uploadingAvatar = true);

    try {
      final bytes = await _readPickedFileBytes(file);
      await widget.studentApi.uploadAvatar(
        bytes: bytes,
        fileName: file.name,
        mimeType: mimeType,
      );
      await widget.onRefresh();
      if (mounted) {
        _showSnack(l10n.t('student.profile.avatar.updated'));
      }
    } on ApiException catch (error) {
      if (mounted) {
        _showSnack(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showSnack(l10n.t('student.profile.avatar.readFailed'));
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  Future<List<int>> _readPickedFileBytes(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes != null) {
      return bytes;
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      throw FileSystemException(
        context.l10n.t('student.profile.avatar.missingPath'),
      );
    }

    return File(path).readAsBytes();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _saveProfile() async {
    final l10n = context.l10n;
    final nextFullName = _fullName.trim();
    final nextPhone = _phone.trim();

    if (nextFullName.isEmpty) {
      _showSnack(l10n.t('student.profile.fullNameRequired'));
      return;
    }

    setState(() => _savingProfile = true);

    try {
      final updatedUser = await widget.studentApi.updateCurrentUserProfile(
        fullName: nextFullName,
        phoneNumber: nextPhone.isEmpty ? null : nextPhone,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _fullName = updatedUser.fullName;
        _phone = updatedUser.phoneNumber ?? '';
        _email = updatedUser.email;
      });

      await widget.onRefresh();
      _showSnack(l10n.t('student.profile.updated'));
    } catch (error) {
      if (mounted) {
        final message = error is ApiException
            ? error.message
            : l10n.t('student.profile.updateFailed');
        _showSnack(message);
      }
    } finally {
      if (mounted) {
        setState(() => _savingProfile = false);
      }
    }
  }
}

String _labelWithFallback(
  AppLocalizationController l10n,
  String key, {
  required String vietnamese,
  required String english,
}) {
  final value = l10n.t(key);
  if (value != key) {
    return value;
  }

  return l10n.languageCode == 'en' ? english : vietnamese;
}

String _avatarInitial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? 'U' : trimmed.characters.first.toUpperCase();
}
