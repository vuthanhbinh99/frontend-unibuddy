import '../../../../models/auth_models.dart';
import '../../../../models/system_admin_models.dart';
import '../../core/api_client.dart';

/// Module API cho các chức năng backend của role `QUAN_TRI_VIEN`.
///
/// Các API dung lượng hệ thống, gửi thông báo hệ thống, audit/error logs và
/// quản lý người dùng để riêng, không trộn với module `ADMIN` thường.
class SystemAdminApiService {
  SystemAdminApiService(this._apiClient);

  final ApiClient _apiClient;

  /// Lấy thống kê dung lượng hệ thống cho dashboard QUAN_TRI_VIEN.
  Future<StorageUsage> getStorageUsage() async {
    final data = await _apiClient.get('/admin/storage-usage');
    return StorageUsage.fromJson(data as Map<String, dynamic>);
  }

  /// Lấy danh sách audit logs có phân trang và bộ lọc.
  Future<PaginatedAuditLogs> listAuditLogs({
    int page = 1,
    int limit = 20,
    AuditLogLevel? level,
    String? action,
    String? actorId,
    DateTime? from,
    DateTime? to,
  }) async {
    final data = await _apiClient.get(
      '/admin/audit-logs',
      query: _query({
        'page': page.toString(),
        'limit': limit.toString(),
        'level': level?.value,
        'action': _blankToNull(action),
        'actorId': _blankToNull(actorId),
        'from': from?.toIso8601String(),
        'to': to?.toIso8601String(),
      }),
    );

    return PaginatedAuditLogs.fromJson(data as Map<String, dynamic>);
  }

  /// Lấy danh sách log lỗi ERROR/CRITICAL có phân trang và bộ lọc.
  Future<PaginatedAuditLogs> listErrorLogs({
    int page = 1,
    int limit = 20,
    String? action,
    String? actorId,
    DateTime? from,
    DateTime? to,
  }) async {
    final data = await _apiClient.get(
      '/admin/error-logs',
      query: _query({
        'page': page.toString(),
        'limit': limit.toString(),
        'action': _blankToNull(action),
        'actorId': _blankToNull(actorId),
        'from': from?.toIso8601String(),
        'to': to?.toIso8601String(),
      }),
    );

    return PaginatedAuditLogs.fromJson(data as Map<String, dynamic>);
  }

  /// Lấy chi tiết một log lỗi cụ thể.
  Future<AuditLogEntry> getErrorLogDetail(String logId) async {
    final data = await _apiClient.get('/admin/error-logs/$logId');
    return AuditLogEntry.fromJson(data as Map<String, dynamic>);
  }

  /// Gửi thông báo hệ thống đến toàn bộ người dùng hoặc một nhóm role.
  Future<SystemNotificationResult> sendSystemNotification({
    required String title,
    required String content,
    required SystemNotificationAudience audience,
  }) async {
    final data = await _apiClient.post(
      '/admin/system-notifications',
      body: {
        'title': title.trim(),
        'content': content.trim(),
        'target': _notificationTarget(audience),
      },
    );

    return SystemNotificationResult.fromJson(data as Map<String, dynamic>);
  }

  /// Lấy danh sách tài khoản để quản trị viên hệ thống quản lý.
  Future<List<ManagedUser>> listUsers() async {
    final data = await _apiClient.get('/admin/users');
    return (data as List)
        .whereType<Map>()
        .map((item) => ManagedUser.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Lấy chi tiết một người dùng.
  Future<ManagedUser> getUserDetail(String userId) async {
    final data = await _apiClient.get('/admin/users/$userId');
    return ManagedUser.fromJson(data as Map<String, dynamic>);
  }

  /// Tạo tài khoản ADMIN hoặc QUAN_TRI_VIEN mới với mật khẩu tạm do backend sinh.
  Future<CreateManagedUserResult> createAdminUser({
    required String email,
    required String fullName,
    required UserRoleCode roleCode,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    final data = await _apiClient.post(
      '/admin/users',
      body: _withoutNulls({
        'email': email.trim(),
        'fullName': fullName.trim(),
        'phoneNumber': _blankToNull(phoneNumber),
        'avatarUrl': _blankToNull(avatarUrl),
        'roleCode': roleCode.value,
      }),
    );

    return CreateManagedUserResult.fromJson(data as Map<String, dynamic>);
  }

  /// Đổi role của người dùng giữa ADMIN và QUAN_TRI_VIEN theo quyền backend.
  Future<ManagedUser> updateUserRole({
    required String userId,
    required UserRoleCode roleCode,
  }) async {
    final data = await _apiClient.patch(
      '/admin/users/$userId/role',
      body: {'roleCode': roleCode.value},
    );

    return ManagedUser.fromJson(data as Map<String, dynamic>);
  }

  /// Cập nhật trạng thái hoạt động/khóa của người dùng.
  Future<UpdateUserStatusResult> updateUserStatus({
    required String userId,
    required ManagedUserStatus status,
  }) async {
    final data = await _apiClient.patch(
      '/admin/users/$userId/status',
      body: {'status': status.value},
    );

    return UpdateUserStatusResult.fromJson(data as Map<String, dynamic>);
  }

  /// Tạo query param và bỏ các giá trị null/rỗng trước khi gọi API lọc log.
  Map<String, String> _query(Map<String, String?> input) {
    return Map.fromEntries(
      input.entries
          .where((entry) => entry.value != null)
          .map((entry) => MapEntry(entry.key, entry.value!)),
    );
  }

  /// Chuyển lựa chọn người nhận trên UI thành payload target backend yêu cầu.
  Map<String, Object?> _notificationTarget(
    SystemNotificationAudience audience,
  ) {
    final roleCode = audience.roleCode;
    if (roleCode == null) {
      return {'allUsers': true};
    }

    return {
      'roleCodes': [roleCode.value],
    };
  }

  /// Bỏ các field null khỏi body trước khi gửi request.
  Map<String, Object?> _withoutNulls(Map<String, Object?> input) {
    return Map.fromEntries(input.entries.where((entry) => entry.value != null));
  }

  /// Chuẩn hóa chuỗi rỗng thành null để filter không gửi giá trị trắng.
  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
