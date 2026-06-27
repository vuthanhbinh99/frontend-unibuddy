import 'package:google_sign_in/google_sign_in.dart';

import '../api/api_exception.dart';

class GoogleIdentityService {
  GoogleIdentityService({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  static const _defaultServerClientId =
      '984633166938-ds33c3bbk7r1bc4l2rt5k40ei4vhnog7.apps.googleusercontent.com';
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: _defaultServerClientId,
  );

  final GoogleSignIn _googleSignIn;
  Future<void>? _initializeFuture;

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

  Future<void> _ensureInitialized() {
    final serverClientId = _blankToNull(_serverClientId);

    return _initializeFuture ??= _googleSignIn.initialize(
      serverClientId: serverClientId,
    );
  }

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
