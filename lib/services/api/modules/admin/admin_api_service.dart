import '../../../../models/admin_models.dart';
import '../../core/api_client.dart';

/// Module API cho các chức năng backend của role `ADMIN`.
///
/// Các API quản lý trường, cấu hình học thuật và kiểm duyệt tài liệu để ở đây.
class AdminApiService {
  AdminApiService(this._apiClient);

  final ApiClient _apiClient;

  /// Lấy danh sách trường cho màn quản lý trường của ADMIN.
  Future<List<AdminSchool>> listSchools() async {
    final data = await _apiClient.get('/admin/schools');
    return _asList(data).map((item) => AdminSchool.fromJson(item)).toList();
  }

  /// Tạo trường mới với mã trường và tên trường.
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

  /// Cập nhật tên trường theo mã trường.
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

  /// Xóa trường theo mã trường; backend sẽ chặn nếu trường còn dữ liệu liên kết.
  Future<void> deleteSchool(String code) async {
    await _apiClient.delete('/admin/schools/${Uri.encodeComponent(code)}');
  }

  /// Lấy cấu hình học thuật/thang điểm của một trường.
  Future<AdminAcademicRules> getAcademicRules(String code) async {
    final data = await _apiClient.get(
      '/admin/schools/${Uri.encodeComponent(code)}/academic-rules',
    );
    return AdminAcademicRules.fromJson(data as Map<String, dynamic>);
  }

  /// Cập nhật thang điểm chữ, điểm số và GPA cho trường.
  Future<void> updateScoreScale({
    required String code,
    required List<AdminScoreScaleLevel> levels,
  }) async {
    await _apiClient.put(
      '/admin/schools/${Uri.encodeComponent(code)}/academic-rules/score-scale',
      body: {'mucThangDiem': levels.map((level) => level.toJson()).toList()},
    );
  }

  /// Cập nhật quy tắc xếp loại học lực cho trường.
  Future<void> updateAcademicStandings({
    required String code,
    required List<AdminAcademicStanding> standings,
  }) async {
    await _apiClient.put(
      '/admin/schools/${Uri.encodeComponent(code)}/academic-rules/academic-standing',
      body: {
        'quyCheHocLuc': standings.map((standing) => standing.toJson()).toList(),
      },
    );
  }

  /// Lấy danh sách báo cáo tài liệu, có thể lọc theo trạng thái.
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

  /// Lấy chi tiết một báo cáo tài liệu.
  Future<AdminDocumentReport> getReportDetail(String reportId) async {
    final data = await _apiClient.get(
      '/admin/reports/${Uri.encodeComponent(reportId)}',
    );
    return AdminDocumentReport.fromJson(data as Map<String, dynamic>);
  }

  /// Duyệt báo cáo tài liệu; backend sẽ xử lý ẩn/xóa tài liệu theo nghiệp vụ.
  Future<AdminDocumentReport> approveReport(String reportId) async {
    final data = await _apiClient.post(
      '/admin/reports/${Uri.encodeComponent(reportId)}/approve',
    );
    return AdminDocumentReport.fromJson(data as Map<String, dynamic>);
  }

  /// Từ chối báo cáo tài liệu và giữ/khôi phục tài liệu theo nghiệp vụ backend.
  Future<AdminDocumentReport> rejectReport(String reportId) async {
    final data = await _apiClient.post(
      '/admin/reports/${Uri.encodeComponent(reportId)}/reject',
    );
    return AdminDocumentReport.fromJson(data as Map<String, dynamic>);
  }

  /// Tải dữ liệu tổng quan cho dashboard ADMIN từ các API con hiện có.
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

  /// Ép response dạng list JSON sang list map để các model admin parse thống nhất.
  List<Map<String, dynamic>> _asList(Object? data) {
    final list = data as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }
}
