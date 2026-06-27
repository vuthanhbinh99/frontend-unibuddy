import '../../../models/auth_models.dart';
import '../../../models/student_course_models.dart';
import '../../../models/student_home_models.dart';
import '../../../models/student_schedule_models.dart';
import '../api_client.dart';

class StudentApiService {
  StudentApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<PublicUser> getCurrentUser() async {
    final data = await _apiClient.get('/users/me');
    return PublicUser.fromJson(data as Map<String, dynamic>);
  }

  Future<StudentHomeData> getStudentHomeData() async {
    final user = await getCurrentUser();
    return StudentHomeData.fromCurrentUser(user);
  }

  Future<StudentScheduleData> listSchedules({String? maMonHoc}) async {
    final data = await _apiClient.get(
      '/schedules',
      query: maMonHoc == null ? null : {'maMonHoc': maMonHoc},
    );
    return StudentScheduleData.fromJson(data);
  }

  Future<StudentCourseData> listCourses({String? maHocKy}) async {
    final data = await _apiClient.get(
      '/courses',
      query: maHocKy == null ? null : {'maHocKy': maHocKy},
    );
    return StudentCourseData.fromJson(data);
  }
}
