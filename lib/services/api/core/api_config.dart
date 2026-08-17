/// Cấu hình URL backend cho app Flutter.
///
/// Khi muốn FE gọi backend đã deploy như Render, truyền:
/// `--dart-define=UNIBUDDY_API_BASE_URL=<backend-url>`.
class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'UNIBUDDY_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );
}
