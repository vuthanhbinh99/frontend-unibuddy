class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'UNIBUDDY_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );
}
