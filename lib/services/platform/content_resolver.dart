import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Cầu nối sang native Android để đọc file từ URI dạng `content://`.
///
/// Một số file picker trên Android không trả đường dẫn file thật mà trả
/// content URI. Flutter không đọc trực tiếp được URI này, nên cần MethodChannel
/// gọi native code lấy bytes rồi trả về Dart.
class ContentResolver {
  /// Channel phải trùng tên với native Android implementation.
  static const MethodChannel _channel = MethodChannel('unibuddy/local_file');

  /// Đọc bytes từ Android `content://` URI.
  ///
  /// Trả `null` khi native đọc thất bại, người dùng thu hồi quyền, hoặc URI
  /// không còn hợp lệ. UI/service gọi hàm này nên tự xử lý fallback.
  static Future<Uint8List?> readContentUri(String uri) async {
    try {
      debugPrint('ContentResolver: readContentUri invoking for $uri');
      final dynamic res = await _channel.invokeMethod('readContentUri', {
        'uri': uri,
      });
      debugPrint(
        'ContentResolver: method returned ${res == null ? 'null' : 'data of length ${(res as List).length}'}',
      );
      if (res == null) return null;
      // Native trả về byte buffer dạng List<int>, cần đổi sang Uint8List để
      // các API upload/file picker phía Dart dùng thống nhất.
      final List<int> list = List<int>.from(res as List<dynamic>);
      return Uint8List.fromList(list);
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
