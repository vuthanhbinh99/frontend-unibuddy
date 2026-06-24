import 'package:flutter/material.dart';

import '../../services/api/api_exception.dart';
import '../../services/api/modules/auth_api_service.dart';
import 'otp_verification_page.dart';
import 'widgets/auth_scaffold.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.authApi});

  final AuthApiService authApi;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
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
              showBackButton: true,
              title: 'Quên mật khẩu',
              subtitle:
                  'Nhập email tài khoản để nhận mã xác thực đặt lại mật khẩu.',
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.mail_outline),
                labelText: 'Email',
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              AuthMessage(message: _errorMessage!, kind: AuthMessageKind.error),
              const SizedBox(height: 14),
            ],
            AuthActionButton(
              label: 'Gửi mã xác thực',
              loading: _loading,
              icon: Icons.mark_email_read_outlined,
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
    });

    try {
      final email = _emailController.text.trim();
      await widget.authApi.requestForgotPasswordCode(email);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              OtpVerificationPage(authApi: widget.authApi, email: email),
        ),
      );
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(
        () => _errorMessage = 'Không thể gửi mã xác thực, vui lòng thử lại.',
      );
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
}
