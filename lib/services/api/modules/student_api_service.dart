import '../../../models/auth_models.dart';
import '../api_client.dart';

class StudentApiService {
  StudentApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<PublicUser> getCurrentUser() async {
    final data = await _apiClient.get('/users/me');
    return PublicUser.fromJson(data as Map<String, dynamic>);
  }
}
