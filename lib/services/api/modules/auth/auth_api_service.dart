import '../../../../models/auth_models.dart';
import '../../core/api_client.dart';

/// Module API cho các endpoint xác thực nằm dưới `/auth/*`.
///
/// Các luồng đăng nhập, Google login, refresh token, logout, đăng ký và quên
/// mật khẩu để ở đây để dễ tìm hợp đồng liên quan đến phiên đăng nhập.
class AuthApiService {
  AuthApiService(this._apiClient);

  final ApiClient _apiClient;

  /// Đăng nhập bằng email/password qua `/auth/login` và trả về kết quả phiên đăng nhập.
  Future<AuthLoginResult> login({
    required String email,
    required String password,
    String? newPassword,
    String? fcmToken,
    String? deviceType,
  }) async {
    final data = await _apiClient.post(
      '/auth/login',
      body: _withoutNulls({
        'email': email.trim(),
        'password': password,
        'newPassword': newPassword,
        'fcmToken': fcmToken,
        'deviceType': deviceType,
      }),
    );

    return _parseLoginResult(data);
  }

  /// Đăng nhập bằng Google ID token qua `/auth/google`.
  Future<AuthLoginResult> loginWithGoogle({
    required String idToken,
    String? fcmToken,
    String? deviceType,
  }) async {
    final data = await _apiClient.post(
      '/auth/google',
      body: _withoutNulls({
        'idToken': idToken,
        'fcmToken': fcmToken,
        'deviceType': deviceType,
      }),
    );

    return _parseLoginResult(data);
  }

  /// Lấy danh sách trường công khai để hiển thị ở màn đăng ký sinh viên.
  Future<List<PublicSchool>> listSchools() async {
    final data = await _apiClient.get('/auth/schools');
    return _asList(data).map((item) => PublicSchool.fromJson(item)).toList();
  }

  /// Parse response đăng nhập.
  ///
  /// Backend có thể trả phiên đăng nhập bình thường hoặc yêu cầu đổi mật khẩu
  /// tạm thời, nên hàm này tách hai trường hợp đó ở một nơi.
  AuthLoginResult _parseLoginResult(Object? data) {
    final payload = data as Map<String, dynamic>;
    if (payload['requiresPasswordChange'] == true) {
      return PasswordChangeRequiredLoginResult.fromJson(payload);
    }

    final session = AuthSession.fromJson(payload);
    _apiClient.setAccessToken(session.accessToken);
    return AuthenticatedLoginResult(session);
  }

  /// Gọi `/auth/refresh` để đổi access token mới.
  /// Backend dùng refresh-token rotation nên response mới phải thay cả access token và refresh token.
  Future<AuthSessionTokens> refreshSession({
    required String refreshToken,
    String? fcmToken,
    String? deviceType,
  }) async {
    final data = await _apiClient.post(
      '/auth/refresh',
      body: _withoutNulls({
        'refreshToken': refreshToken,
        'fcmToken': fcmToken,
        'deviceType': deviceType,
      }),
    );

    final tokens = AuthSessionTokens.fromJson(data as Map<String, dynamic>);
    _apiClient.setAccessToken(tokens.accessToken);
    return tokens;
  }

  /// Đăng ký tài khoản sinh viên mới qua `/auth/register`.
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

  /// Yêu cầu backend gửi mã OTP quên mật khẩu đến email.
  Future<void> requestForgotPasswordCode(String email) async {
    await _apiClient.post(
      '/auth/forgot-password',
      body: {'email': email.trim()},
    );
  }

  /// Xác thực OTP quên mật khẩu và nhận reset token tạm thời.
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

  /// Đặt lại mật khẩu mới bằng reset token đã xác thực.
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    await _apiClient.post(
      '/auth/forgot-password/reset',
      body: {'resetToken': resetToken, 'newPassword': newPassword},
    );
  }

  /// Đăng xuất phiên hiện tại trên backend bằng refresh token.
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

  /// Bỏ các field null/rỗng trước khi gửi body để payload gọn và đúng ý backend.
  Map<String, Object?> _withoutNulls(Map<String, Object?> input) {
    return Map.fromEntries(input.entries.where((entry) => entry.value != null));
  }

  /// Ép response dạng list JSON sang list map để model parser dùng được.
  List<Map<String, dynamic>> _asList(Object? data) {
    final list = data as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  /// Chuẩn hóa chuỗi rỗng thành null để không gửi field trống lên backend.
  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
