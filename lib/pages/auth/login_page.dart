import 'package:flutter/material.dart';

import '../../models/auth_models.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/auth_api_service.dart';
import '../../services/auth/google_identity_service.dart';
import 'widgets/auth_scaffold.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.authApi,
    required this.googleIdentityService,
    required this.onLoginSuccess,
    required this.onRegisterTap,
    required this.onForgotPasswordTap,
  });

  final AuthApiService authApi;
  final GoogleIdentityService googleIdentityService;
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
  bool _googleLoading = false;
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
    final l10n = context.l10n;
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeader(
              title: l10n.t('auth.login.title'),
              subtitle: l10n.t('auth.login.subtitle'),
            ),
            const SizedBox(height: 28),
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
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
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
              validator: (value) => value == null || value.isEmpty
                  ? l10n.t('auth.validation.passwordRequired')
                  : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onForgotPasswordTap,
                child: Text(l10n.t('auth.login.forgotPassword')),
              ),
            ),
            if (_errorMessage != null) ...[
              AuthMessage(message: _errorMessage!, kind: AuthMessageKind.error),
              const SizedBox(height: 14),
            ],
            AuthActionButton(
              label: l10n.t('auth.login.button'),
              loading: _loading,
              onPressed: _googleLoading ? null : _submit,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _loading || _googleLoading
                    ? null
                    : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF334155)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _googleLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const _GoogleMark(),
                label: const Text(
                  'Đăng nhập bằng Google',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: widget.onRegisterTap,
              child: Text(l10n.t('auth.login.register')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _loading || _googleLoading) {
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

      await _handleLoginResult(result);
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() => _errorMessage = context.l10n.t('auth.login.error'));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_loading || _googleLoading) {
      return;
    }

    setState(() {
      _googleLoading = true;
      _errorMessage = null;
    });

    try {
      final idToken = await widget.googleIdentityService.signInAndGetIdToken();
      if (idToken == null || !mounted) {
        return;
      }

      final result = await widget.authApi.loginWithGoogle(
        idToken: idToken,
        deviceType: 'flutter',
      );

      if (mounted) {
        await _handleLoginResult(result);
      }
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() => _errorMessage = context.l10n.t('auth.login.googleError'));
    } finally {
      if (mounted) {
        setState(() => _googleLoading = false);
      }
    }
  }

  Future<void> _handleLoginResult(AuthLoginResult result) async {
    switch (result) {
      case AuthenticatedLoginResult(:final session):
        widget.onLoginSuccess(session);
      case PasswordChangeRequiredLoginResult(:final user):
        if (user.role.roleCode != UserRoleCode.admin) {
          if (mounted) {
            setState(
              () => _errorMessage = context.l10n.t(
                'auth.login.tempPasswordMismatch',
              ),
            );
          }
          return;
        }

        final newPassword = await _promptNewPassword();
        if (newPassword == null || !mounted) {
          setState(
            () => _errorMessage = context.l10n.t(
              'auth.login.tempPasswordRequired',
            ),
          );
          return;
        }

        final changed = await widget.authApi.login(
          email: _emailController.text,
          password: _passwordController.text,
          newPassword: newPassword,
          deviceType: 'flutter',
        );

        if (changed case AuthenticatedLoginResult(:final session)) {
          widget.onLoginSuccess(session);
          return;
        }

        if (mounted) {
          setState(
            () => _errorMessage = context.l10n.t(
              'auth.login.tempPasswordUpdateFailed',
            ),
          );
        }
    }
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

  Future<String?> _promptNewPassword() async {
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscure = true;

    final newPassword = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.l10n.t('auth.passwordChange.title')),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: context.l10n.t(
                          'auth.passwordChange.newPassword',
                        ),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setDialogState(() => obscure = !obscure),
                          icon: Icon(
                            obscure ? Icons.visibility_off : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.length < 8) {
                          return context.l10n.t(
                            'auth.passwordChange.minLength',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: context.l10n.t(
                          'auth.passwordChange.confirmPassword',
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim() !=
                            passwordController.text.trim()) {
                          return context.l10n.t('auth.passwordChange.mismatch');
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(context.l10n.t('common.cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    Navigator.of(
                      dialogContext,
                    ).pop(passwordController.text.trim());
                  },
                  child: Text(context.l10n.t('auth.passwordChange.update')),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
    confirmController.dispose();
    return newPassword;
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
