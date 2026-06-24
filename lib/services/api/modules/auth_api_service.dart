import '../../../models/auth_models.dart';
import '../api_client.dart';

class AuthApiService {
  AuthApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthLoginResult> login({
    required String email,
    required String password,
    String? fcmToken,
    String? deviceType,
  }) async {
    final data = await _apiClient.post(
      '/auth/login',
      body: _withoutNulls({
        'email': email.trim(),
        'password': password,
        'fcmToken': fcmToken,
        'deviceType': deviceType,
      }),
    );

    final payload = data as Map<String, dynamic>;
    if (payload['requiresPasswordChange'] == true) {
      return PasswordChangeRequiredLoginResult.fromJson(payload);
    }

    final session = AuthSession.fromJson(payload);
    _apiClient.setAccessToken(session.accessToken);
    return AuthenticatedLoginResult(session);
  }

  Future<RegisterStudentResult> registerStudent({
    required String fullName,
    required String email,
    required String password,
    required String maSinhVien,
    String? phoneNumber,
    int? maTruong,
    String? maTruongCode,
    String? nganhHoc,
    String? khoaHoc,
  }) async {
    final data = await _apiClient.post(
      '/auth/register',
      body: _withoutNulls({
        'fullName': fullName.trim(),
        'email': email.trim(),
        'password': password,
        'maSinhVien': maSinhVien.trim(),
        'phoneNumber': _blankToNull(phoneNumber),
        'maTruong': maTruong,
        'maTruongCode': _blankToNull(maTruongCode),
        'nganhHoc': _blankToNull(nganhHoc),
        'khoaHoc': _blankToNull(khoaHoc),
      }),
    );

    return RegisterStudentResult.fromJson(data as Map<String, dynamic>);
  }

  Future<void> requestForgotPasswordCode(String email) async {
    await _apiClient.post(
      '/auth/forgot-password',
      body: {'email': email.trim()},
    );
  }

  Future<ResetPasswordToken> verifyForgotPasswordCode({
    required String email,
    required String code,
  }) async {
    final data = await _apiClient.post(
      '/auth/forgot-password/verify',
      body: {'email': email.trim(), 'code': code.trim()},
    );

    return ResetPasswordToken.fromJson(data as Map<String, dynamic>);
  }

  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    await _apiClient.post(
      '/auth/forgot-password/reset',
      body: {'resetToken': resetToken, 'newPassword': newPassword},
    );
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _apiClient.post(
        '/auth/logout',
        body: {'refreshToken': refreshToken},
      );
    } finally {
      _apiClient.setAccessToken(null);
    }
  }

  Map<String, Object?> _withoutNulls(Map<String, Object?> input) {
    return Map.fromEntries(input.entries.where((entry) => entry.value != null));
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
