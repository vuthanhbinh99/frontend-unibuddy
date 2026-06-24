import 'package:flutter/material.dart';

import '../../models/auth_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/auth_api_service.dart';
import 'widgets/auth_scaffold.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.authApi,
    required this.onLoginSuccess,
    required this.onRegisterTap,
    required this.onForgotPasswordTap,
  });

  final AuthApiService authApi;
  final ValueChanged<AuthSession> onLoginSuccess;
  final VoidCallback onRegisterTap;
  final VoidCallback onForgotPasswordTap;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeader(
              title: 'Chào mừng bạn quay lại',
              subtitle:
                  'Đăng nhập bằng tài khoản UniBuddy.',
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.mail_outline),
                labelText: 'Email',
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline),
                labelText: 'Mật khẩu',
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Vui lòng nhập mật khẩu'
                  : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onForgotPasswordTap,
                child: const Text('Quên mật khẩu?'),
              ),
            ),
            if (_errorMessage != null) ...[
              AuthMessage(message: _errorMessage!, kind: AuthMessageKind.error),
              const SizedBox(height: 14),
            ],
            AuthActionButton(
              label: 'Đăng nhập',
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: widget.onRegisterTap,
              child: const Text('Tạo tài khoản người dùng mới'),
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
    });

    try {
      final result = await widget.authApi.login(
        email: _emailController.text,
        password: _passwordController.text,
        deviceType: 'flutter',
      );

      switch (result) {
        case AuthenticatedLoginResult(:final session):
          widget.onLoginSuccess(session);
        case PasswordChangeRequiredLoginResult(:final user):
          setState(() => _errorMessage = _passwordChangeMessageFor(user));
      }
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() => _errorMessage = 'Đăng nhập thất bại, vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Vui lòng nhập email';
    }
    if (!text.contains('@')) {
      return 'Email không hợp lệ';
    }
    return null;
  }

  String _passwordChangeMessageFor(PublicUser user) {
    if (user.role.isAdminOrSystemAdmin) {
      return 'Tài khoản quản trị đang dùng mật khẩu tạm thời. Vui lòng đổi mật khẩu trước khi tiếp tục.';
    }

    return 'Tài khoản cần đổi mật khẩu tạm thời trước khi tiếp tục.';
  }
}
