import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/auth_api_service.dart';
import 'reset_password_page.dart';
import 'widgets/auth_scaffold.dart';

class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({
    super.key,
    required this.authApi,
    required this.email,
  });

  final AuthApiService authApi;
  final String email;

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _codeController.dispose();
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
              title: l10n.t('auth.otp.title'),
              subtitle: l10n.t(
                'auth.otp.subtitle',
                arguments: {'email': widget.email},
              ),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.w800,
              ),
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                counterText: '',
                labelText: l10n.t('auth.otp.code'),
                prefixIcon: Icon(Icons.pin_outlined),
              ),
              validator: _validateCode,
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
              label: l10n.t('auth.otp.button'),
              loading: _loading,
              icon: Icons.verified_outlined,
              onPressed: _submit,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _resending ? null : _resend,
              icon: _resending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(l10n.t('auth.otp.resend')),
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
      final token = await widget.authApi.verifyForgotPasswordCode(
        email: widget.email,
        code: _codeController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResetPasswordPage(
            authApi: widget.authApi,
            resetToken: token.resetToken,
          ),
        ),
      );
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() => _errorMessage = context.l10n.t('auth.otp.error'));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await widget.authApi.requestForgotPasswordCode(widget.email);
      setState(
        () => _successMessage = context.l10n.t('auth.otp.resendSuccess'),
      );
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() => _errorMessage = context.l10n.t('auth.otp.resendError'));
    } finally {
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  String? _validateCode(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\d{6}$').hasMatch(text)) {
      return context.l10n.t('auth.otp.validation');
    }
    return null;
  }
}
