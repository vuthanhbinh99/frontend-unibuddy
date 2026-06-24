class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'UNIBUDDY_API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );
}
