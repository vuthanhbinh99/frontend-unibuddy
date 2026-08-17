import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_exception.dart';

typedef TokenRefreshHandler = Future<bool> Function();

/// Lớp HTTP dùng chung cho toàn bộ module API ở frontend.
///
/// File này phụ trách base URL, gắn Bearer token, giải mã envelope trả về từ
/// backend, và tự refresh/retry một lần khi request bảo vệ bị 401. Các module
/// nghiệp vụ chỉ nên khai báo endpoint và payload, không tự xử lý HTTP lặp lại.
class ApiClient {
  ApiClient({http.Client? httpClient, String baseUrl = ApiConfig.baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = baseUrl;

  final http.Client _httpClient;
  final String _baseUrl;
  String? _accessToken;
  String? _acceptLanguageCode;
  TokenRefreshHandler? _tokenRefreshHandler;
  Future<bool>? _tokenRefreshFuture;

  /// Cập nhật access token hiện tại để các request sau tự gắn header Authorization.
  void setAccessToken(String? token) {
    _accessToken = token;
  }

  /// Đăng ký hàm refresh token do app cung cấp; ApiClient sẽ gọi khi request bảo vệ bị 401.
  void setTokenRefreshHandler(TokenRefreshHandler? handler) {
    _tokenRefreshHandler = handler;
  }

  /// Cập nhật ngôn ngữ gửi lên backend qua header Accept-Language.
  void setAcceptLanguageCode(String? languageCode) {
    final normalized = languageCode?.trim();
    _acceptLanguageCode = normalized == null || normalized.isEmpty
        ? null
        : normalized;
  }

  /// Gửi request GET và trả về phần data trong envelope backend.
  Future<Object?> get(String path, {Map<String, String>? query}) {
    return _send('GET', path, query: query);
  }

  /// Gửi request POST JSON và trả về phần data trong envelope backend.
  Future<Object?> post(String path, {Map<String, Object?>? body}) {
    return _send('POST', path, body: body);
  }

  /// Gửi request multipart khi upload file; vẫn dùng chung cơ chế token và refresh/retry.
  Future<Object?> postMultipart(
    String path, {
    required String fileField,
    required List<int> bytes,
    required String filename,
    Map<String, String>? fields,
    bool allowTokenRefresh = true,
  }) async {
    final request = http.MultipartRequest('POST', _buildUri(path, null));
    request.headers.addAll({
      'Accept': 'application/json',
      ...?(_acceptLanguageCode == null
          ? null
          : {'Accept-Language': _acceptLanguageCode!}),
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    });
    if (fields != null) {
      request.fields.addAll(fields);
    }
    request.files.add(
      http.MultipartFile.fromBytes(fileField, bytes, filename: filename),
    );

    try {
      final streamedResponse = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      return _decodeEnvelope(response);
    } on ApiException catch (error) {
      if (await _shouldRefreshAndRetry(
        error,
        path,
        allowTokenRefresh: allowTokenRefresh,
      )) {
        return postMultipart(
          path,
          fileField: fileField,
          bytes: bytes,
          filename: filename,
          fields: fields,
          allowTokenRefresh: false,
        );
      }
      rethrow;
    } on http.ClientException catch (error) {
      throw ApiException(
        code: 'NETWORK_ERROR',
        message:
            'Không thể kết nối backend UniBuddy. Vui lòng kiểm tra API base URL.',
        details: error.message,
      );
    }
  }

  /// Gửi request PUT JSON cho các thao tác thay thế dữ liệu.
  Future<Object?> put(String path, {Map<String, Object?>? body}) {
    return _send('PUT', path, body: body);
  }

  /// Gửi request PATCH JSON cho các thao tác cập nhật một phần.
  Future<Object?> patch(String path, {Map<String, Object?>? body}) {
    return _send('PATCH', path, body: body);
  }

  /// Gửi request DELETE, có thể kèm body khi backend cần thêm dữ liệu.
  Future<Object?> delete(String path, {Map<String, Object?>? body}) {
    return _send('DELETE', path, body: body);
  }

  /// Hàm gửi request JSON dùng chung cho GET/POST/PUT/PATCH/DELETE.
  ///
  /// Nếu backend trả 401 cho request được phép refresh, hàm này sẽ gọi refresh
  /// token rồi retry lại đúng request ban đầu một lần.
  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    bool allowTokenRefresh = true,
  }) async {
    final uri = _buildUri(path, query);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...?(_acceptLanguageCode == null
          ? null
          : {'Accept-Language': _acceptLanguageCode!}),
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };

    late http.Response response;
    try {
      response = switch (method) {
        'GET' => await _httpClient.get(uri, headers: headers),
        'POST' => await _httpClient.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? {}),
        ),
        'PATCH' => await _httpClient.patch(
          uri,
          headers: headers,
          body: jsonEncode(body ?? {}),
        ),
        'PUT' => await _httpClient.put(
          uri,
          headers: headers,
          body: jsonEncode(body ?? {}),
        ),
        'DELETE' =>
          body == null
              ? await _httpClient.delete(uri, headers: headers)
              : await _httpClient.delete(
                  uri,
                  headers: headers,
                  body: jsonEncode(body),
                ),
        _ => throw UnsupportedError('Unsupported method $method'),
      };
    } on http.ClientException catch (error) {
      throw ApiException(
        code: 'NETWORK_ERROR',
        message:
            'Không thể kết nối backend UniBuddy. Vui lòng kiểm tra API base URL.',
        details: error.message,
      );
    }

    try {
      return _decodeEnvelope(response);
    } on ApiException catch (error) {
      if (await _shouldRefreshAndRetry(
        error,
        path,
        allowTokenRefresh: allowTokenRefresh,
      )) {
        return _send(
          method,
          path,
          query: query,
          body: body,
          allowTokenRefresh: false,
        );
      }
      rethrow;
    }
  }

  /// Ghép base URL, path endpoint và query param thành URI hoàn chỉnh.
  Uri _buildUri(String path, Map<String, String>? query) {
    final normalizedBaseUrl = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '$normalizedBaseUrl$normalizedPath',
    ).replace(queryParameters: query);
  }

  /// Giải mã response envelope chuẩn của backend.
  ///
  /// Backend thường trả `{ success, data, error }`; UI chỉ nhận `data`, còn lỗi
  /// được đổi thành `ApiException` để các màn hình bắt và hiển thị.
  Object? _decodeEnvelope(http.Response response) {
    final decoded = response.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is Map<String, dynamic>) {
      if (decoded['success'] == true) {
        return decoded['data'];
      }

      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        throw ApiException(
          code: error['code'] as String? ?? 'API_ERROR',
          message: error['message'] as String? ?? 'Yêu cầu không thành công',
          details: error['details'],
          statusCode: response.statusCode,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw ApiException(
      code: 'HTTP_${response.statusCode}',
      message: 'Backend trả về lỗi không đúng định dạng envelope.',
      details: decoded,
      statusCode: response.statusCode,
    );
  }

  /// Kiểm tra lỗi 401 có đủ điều kiện để refresh token và retry hay không.
  Future<bool> _shouldRefreshAndRetry(
    ApiException error,
    String path, {
    required bool allowTokenRefresh,
  }) async {
    if (!allowTokenRefresh ||
        error.statusCode != 401 ||
        _accessToken == null ||
        _tokenRefreshHandler == null ||
        _isAuthSessionEndpoint(path)) {
      return false;
    }

    return _refreshAccessToken();
  }

  /// Các endpoint auth/session không được tự refresh để tránh vòng lặp vô hạn.
  bool _isAuthSessionEndpoint(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return normalizedPath == '/auth/login' ||
        normalizedPath == '/auth/google' ||
        normalizedPath == '/auth/register' ||
        normalizedPath == '/auth/refresh' ||
        normalizedPath == '/auth/logout' ||
        normalizedPath.startsWith('/auth/forgot-password');
  }

  /// Chạy refresh token qua handler của app.
  ///
  /// Nếu nhiều request cùng hết hạn token, các request sẽ dùng chung một Future
  /// refresh để tránh gọi `/auth/refresh` nhiều lần làm hỏng refresh-token rotation.
  Future<bool> _refreshAccessToken() {
    final existingRefresh = _tokenRefreshFuture;
    if (existingRefresh != null) {
      return existingRefresh;
    }

    final refresh = _tokenRefreshHandler!().whenComplete(() {
      _tokenRefreshFuture = null;
    });
    _tokenRefreshFuture = refresh;
    return refresh;
  }

  /// Đóng HTTP client khi app/service không còn dùng nữa.
  void close() {
    _httpClient.close();
  }
}
