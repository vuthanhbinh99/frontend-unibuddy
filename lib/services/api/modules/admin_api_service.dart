import '../../../models/admin_models.dart';
import '../api_client.dart';

class AdminApiService {
  AdminApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AdminSchool>> listSchools() async {
    final data = await _apiClient.get('/admin/schools');
    return _asList(data).map((item) => AdminSchool.fromJson(item)).toList();
  }

  Future<AdminSchool> createSchool({
    required String code,
    required String name,
  }) async {
    final data = await _apiClient.post(
      '/admin/schools',
      body: {'maTruongCode': code.trim(), 'tenTruong': name.trim()},
    );
    return AdminSchool.fromJson(data as Map<String, dynamic>);
  }

  Future<AdminSchool> updateSchool({
    required String code,
    required String name,
  }) async {
    final data = await _apiClient.put(
      '/admin/schools/${Uri.encodeComponent(code)}',
      body: {'tenTruong': name.trim()},
    );
    return AdminSchool.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteSchool(String code) async {
    await _apiClient.delete('/admin/schools/${Uri.encodeComponent(code)}');
  }

  Future<List<AdminDocumentReport>> listReports({
    AdminReportStatus? status,
  }) async {
    final data = await _apiClient.get(
      '/admin/reports',
      query: status == null ? null : {'trangThai': status.value},
    );
    return _asList(
      data,
    ).map((item) => AdminDocumentReport.fromJson(item)).toList();
  }

  Future<AdminDocumentReport> getReportDetail(String reportId) async {
    final data = await _apiClient.get(
      '/admin/reports/${Uri.encodeComponent(reportId)}',
    );
    return AdminDocumentReport.fromJson(data as Map<String, dynamic>);
  }

  Future<AdminDocumentReport> approveReport(String reportId) async {
    final data = await _apiClient.post(
      '/admin/reports/${Uri.encodeComponent(reportId)}/approve',
    );
    return AdminDocumentReport.fromJson(data as Map<String, dynamic>);
  }

  Future<AdminDocumentReport> rejectReport(String reportId) async {
    final data = await _apiClient.post(
      '/admin/reports/${Uri.encodeComponent(reportId)}/reject',
    );
    return AdminDocumentReport.fromJson(data as Map<String, dynamic>);
  }

  Future<AdminDashboardData> loadDashboard() async {
    final schools = await listSchools();
    final pendingReports = await listReports(status: AdminReportStatus.pending);
    final approvedReports = await listReports(
      status: AdminReportStatus.approved,
    );
    final rejectedReports = await listReports(
      status: AdminReportStatus.rejected,
    );

    return AdminDashboardData(
      schools: schools,
      pendingReports: pendingReports,
      approvedReports: approvedReports,
      rejectedReports: rejectedReports,
    );
  }

  List<Map<String, dynamic>> _asList(Object? data) {
    final list = data as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }
}
