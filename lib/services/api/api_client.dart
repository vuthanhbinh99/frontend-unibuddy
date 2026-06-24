import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({http.Client? httpClient, String baseUrl = ApiConfig.baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = baseUrl;

  final http.Client _httpClient;
  final String _baseUrl;
  String? _accessToken;

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  Future<Object?> get(String path, {Map<String, String>? query}) {
    return _send('GET', path, query: query);
  }

  Future<Object?> post(String path, {Map<String, Object?>? body}) {
    return _send('POST', path, body: body);
  }

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
  }) async {
    final uri = _buildUri(path, query);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
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

    return _decodeEnvelope(response);
  }

  Uri _buildUri(String path, Map<String, String>? query) {
    final normalizedBaseUrl = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '$normalizedBaseUrl$normalizedPath',
    ).replace(queryParameters: query);
  }

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

  void close() {
    _httpClient.close();
  }
}
