import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ContentResolver {
  static const MethodChannel _channel = MethodChannel('unibuddy/local_file');

  /// Reads bytes from an Android content:// URI. Returns null on failure.
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
      // Platform returns a byte buffer (List<int>)
      final List<int> list = List<int>.from(res as List<dynamic>);
      return Uint8List.fromList(list);
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
