import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/auth_api_service.dart';
import 'widgets/auth_scaffold.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.authApi});

  final AuthApiService authApi;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _maSinhVienController = TextEditingController();
  final _phoneController = TextEditingController();
  final _maTruongCodeController = TextEditingController();
  final _nganhHocController = TextEditingController();
  final _khoaHocController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _maSinhVienController.dispose();
    _phoneController.dispose();
    _maTruongCodeController.dispose();
    _nganhHocController.dispose();
    _khoaHocController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeader(
              showBackButton: true,
              title: l10n.t('auth.register.title'),
              subtitle: l10n.t('auth.register.subtitle'),
            ),
            const SizedBox(height: 26),
            TextFormField(
              controller: _fullNameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.person_outline),
                labelText: l10n.t('auth.register.fullName'),
              ),
              validator: _required(l10n.t('auth.register.requiredName')),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.mail_outline),
                labelText: l10n.t('auth.fields.email'),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _maSinhVienController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.badge_outlined),
                labelText: l10n.t('auth.register.studentId'),
              ),
              validator: _required(l10n.t('auth.register.requiredStudentId')),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.phone_outlined),
                labelText: l10n.t('auth.register.phone'),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nganhHocController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.menu_book_outlined),
                      labelText: l10n.t('auth.register.major'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _khoaHocController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      labelText: l10n.t('auth.register.cohort'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _maTruongCodeController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.apartment_outlined),
                labelText: l10n.t('auth.register.schoolCode'),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline),
                labelText: l10n.t('auth.fields.password'),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              validator: _validatePassword,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.lock_reset_outlined),
                labelText: l10n.t('auth.passwordChange.confirmPassword'),
              ),
              validator: _validateConfirmPassword,
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              AuthMessage(message: _errorMessage!, kind: AuthMessageKind.error),
              const SizedBox(height: 14),
            ],
            if (_successMessage != null) ...[
              AuthMessage(
                message: _successMessage!,
                kind: AuthMessageKind.success,
              ),
              const SizedBox(height: 14),
            ],
            AuthActionButton(
              label: l10n.t('auth.register.button'),
              loading: _loading,
              icon: Icons.person_add_alt_1,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _loading) {
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await widget.authApi.registerStudent(
        fullName: _fullNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        maSinhVien: _maSinhVienController.text,
        phoneNumber: _phoneController.text,
        maTruongCode: _maTruongCodeController.text,
        nganhHoc: _nganhHocController.text,
        khoaHoc: _khoaHocController.text,
      );

      setState(
        () => _successMessage = context.l10n.t(
          'auth.register.success',
          arguments: {'message': result.message},
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() => _errorMessage = context.l10n.t('auth.register.error'));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  FormFieldValidator<String> _required(String message) {
    return (value) => value == null || value.trim().isEmpty ? message : null;
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return context.l10n.t('auth.validation.emailRequired');
    }
    if (!text.contains('@')) {
      return context.l10n.t('auth.validation.emailInvalid');
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return context.l10n.t('auth.register.requiredPassword');
    }
    if (value.length < 8) {
      return context.l10n.t('auth.register.passwordMinLength');
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) {
      return context.l10n.t('auth.register.passwordMismatch');
    }
    return null;
  }
}
