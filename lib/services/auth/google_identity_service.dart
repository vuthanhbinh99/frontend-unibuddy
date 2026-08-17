import 'package:google_sign_in/google_sign_in.dart';

import '../api/core/api_exception.dart';

/// Service phụ trách đăng nhập Google ở phía client.
///
/// File này chỉ lấy Google `idToken`. Việc tạo session UniBuddy vẫn nằm ở
/// `AuthApiService.loginWithGoogle`, để luồng auth backend tập trung một chỗ.
class GoogleIdentityService {
  GoogleIdentityService({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  /// Client ID mặc định dùng khi build local nếu chưa truyền dart-define.
  static const _defaultServerClientId =
      '984633166938-ds33c3bbk7r1bc4l2rt5k40ei4vhnog7.apps.googleusercontent.com';

  /// Có thể override bằng:
  /// `--dart-define=GOOGLE_SERVER_CLIENT_ID=<server-client-id>`.
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: _defaultServerClientId,
  );

  final GoogleSignIn _googleSignIn;
  Future<void>? _initializeFuture;

  /// Mở Google Sign-In và trả về `idToken` để gửi về backend.
  ///
  /// Trả `null` khi người dùng chủ động hủy đăng nhập; các lỗi cấu hình hoặc
  /// lỗi provider thật sẽ được đổi thành `ApiException` để UI hiển thị.
  Future<String?> signInAndGetIdToken() async {
    try {
      await _ensureInitialized();

      if (!_googleSignIn.supportsAuthenticate()) {
        throw const ApiException(
          code: 'GOOGLE_AUTH_UNSUPPORTED',
          message: 'Thiết bị hiện tại không hỗ trợ đăng nhập bằng Google.',
        );
      }

      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const ApiException(
          code: 'GOOGLE_ID_TOKEN_MISSING',
          message:
              'Không lấy được Google ID token. Vui lòng kiểm tra cấu hình Google client ID.',
        );
      }

      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }

      if (error.code == GoogleSignInExceptionCode.uiUnavailable) {
        throw const ApiException(
          code: 'GOOGLE_AUTH_UI_UNAVAILABLE',
          message: 'Không thể mở giao diện đăng nhập Google trên thiết bị này.',
        );
      }

      throw ApiException(
        code: 'GOOGLE_AUTH_FAILED',
        message: 'Đăng nhập Google thất bại, vui lòng thử lại.',
        details: error.description,
      );
    }
  }

  /// Khởi tạo Google Sign-In một lần duy nhất.
  ///
  /// `_initializeFuture` giúp nhiều lần gọi liên tiếp dùng chung một tiến trình
  /// initialize, tránh mở/khởi tạo provider lặp lại.
  Future<void> _ensureInitialized() {
    final serverClientId = _blankToNull(_serverClientId);

    return _initializeFuture ??= _googleSignIn.initialize(
      serverClientId: serverClientId,
    );
  }

  /// Chuẩn hóa chuỗi rỗng thành null trước khi truyền vào Google SDK.
  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
