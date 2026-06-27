import '../../../models/auth_models.dart';
import '../../../models/system_admin_models.dart';
import '../api_client.dart';

class SystemAdminApiService {
  SystemAdminApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<StorageUsage> getStorageUsage() async {
    final data = await _apiClient.get('/admin/storage-usage');
    return StorageUsage.fromJson(data as Map<String, dynamic>);
  }

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

  Future<AuditLogEntry> getErrorLogDetail(String logId) async {
    final data = await _apiClient.get('/admin/error-logs/$logId');
    return AuditLogEntry.fromJson(data as Map<String, dynamic>);
  }

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

  Future<List<ManagedUser>> listUsers() async {
    final data = await _apiClient.get('/admin/users');
    return (data as List)
        .whereType<Map>()
        .map((item) => ManagedUser.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<ManagedUser> getUserDetail(String userId) async {
    final data = await _apiClient.get('/admin/users/$userId');
    return ManagedUser.fromJson(data as Map<String, dynamic>);
  }

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

  Map<String, String> _query(Map<String, String?> input) {
    return Map.fromEntries(
      input.entries
          .where((entry) => entry.value != null)
          .map((entry) => MapEntry(entry.key, entry.value!)),
    );
  }

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

  Map<String, Object?> _withoutNulls(Map<String, Object?> input) {
    return Map.fromEntries(input.entries.where((entry) => entry.value != null));
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
