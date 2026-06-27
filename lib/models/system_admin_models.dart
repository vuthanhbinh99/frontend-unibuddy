import 'auth_models.dart';

enum ManagedUserStatus {
  active('HOAT_DONG'),
  locked('BI_KHOA'),
  unverified('CHUA_XAC_THUC'),
  passwordChangeRequired('CHO_DOI_MAT_KHAU');

  const ManagedUserStatus(this.value);

  final String value;

  static ManagedUserStatus? from(String value) {
    for (final status in ManagedUserStatus.values) {
      if (status.value == value) {
        return status;
      }
    }
    return null;
  }
}

enum AuditLogLevel {
  info('INFO'),
  warning('WARNING'),
  error('ERROR'),
  critical('CRITICAL');

  const AuditLogLevel(this.value);

  final String value;

  static AuditLogLevel? from(String value) {
    for (final level in AuditLogLevel.values) {
      if (level.value == value) {
        return level;
      }
    }
    return null;
  }
}

enum SystemNotificationAudience {
  all('Tất cả', null),
  students('Sinh viên', UserRoleCode.student),
  admins('Admin', UserRoleCode.admin),
  systemAdmins('Quản trị viên', UserRoleCode.systemAdmin);

  const SystemNotificationAudience(this.label, this.roleCode);

  final String label;
  final UserRoleCode? roleCode;
}

class StorageCategoryUsage {
  const StorageCategoryUsage({
    required this.category,
    required this.bytes,
    required this.fileCount,
  });

  final String category;
  final int bytes;
  final int fileCount;

  factory StorageCategoryUsage.fromJson(Map<String, dynamic> json) {
    return StorageCategoryUsage(
      category: json['category'] as String? ?? 'unknown',
      bytes: _asInt(json['bytes']),
      fileCount: _asInt(json['fileCount']),
    );
  }
}

class DatabaseTableUsage {
  const DatabaseTableUsage({required this.tableName, required this.bytes});

  final String tableName;
  final int bytes;

  factory DatabaseTableUsage.fromJson(Map<String, dynamic> json) {
    return DatabaseTableUsage(
      tableName: json['tableName'] as String? ?? 'unknown',
      bytes: _asInt(json['bytes']),
    );
  }
}

class FirebaseStorageUsage {
  const FirebaseStorageUsage({
    required this.configured,
    required this.bucket,
    required this.totalBytes,
    required this.fileCount,
    required this.categories,
    this.error,
  });

  final bool configured;
  final String? bucket;
  final int totalBytes;
  final int fileCount;
  final List<StorageCategoryUsage> categories;
  final String? error;

  factory FirebaseStorageUsage.fromJson(Map<String, dynamic> json) {
    return FirebaseStorageUsage(
      configured: json['configured'] == true,
      bucket: json['bucket'] as String?,
      totalBytes: _asInt(json['totalBytes']),
      fileCount: _asInt(json['fileCount']),
      categories: _parseList(json['categories'], StorageCategoryUsage.fromJson),
      error: json['error'] as String?,
    );
  }
}

class StorageUsage {
  const StorageUsage({
    required this.databaseTotalBytes,
    required this.databaseTables,
    required this.documentTotalBytes,
    required this.documentFileCount,
    required this.documentCategories,
    required this.firebase,
  });

  final int databaseTotalBytes;
  final List<DatabaseTableUsage> databaseTables;
  final int documentTotalBytes;
  final int documentFileCount;
  final List<StorageCategoryUsage> documentCategories;
  final FirebaseStorageUsage firebase;

  int get totalBytes {
    return databaseTotalBytes + documentTotalBytes + firebase.totalBytes;
  }

  factory StorageUsage.fromJson(Map<String, dynamic> json) {
    final database = json['database'] as Map<String, dynamic>? ?? const {};
    final documents = json['documents'] as Map<String, dynamic>? ?? const {};
    final firebase = json['firebase'] as Map<String, dynamic>? ?? const {};

    return StorageUsage(
      databaseTotalBytes: _asInt(database['totalBytes']),
      databaseTables: _parseList(
        database['tables'],
        DatabaseTableUsage.fromJson,
      ),
      documentTotalBytes: _asInt(documents['totalBytes']),
      documentFileCount: _asInt(documents['fileCount']),
      documentCategories: _parseList(
        documents['categories'],
        StorageCategoryUsage.fromJson,
      ),
      firebase: FirebaseStorageUsage.fromJson(firebase),
    );
  }
}

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.level,
    required this.action,
    required this.createdAt,
    this.actorId,
    this.actorEmail,
    this.actorFullName,
    this.tableName,
    this.recordId,
    this.message,
    this.metadata,
  });

  final String id;
  final String? actorId;
  final String? actorEmail;
  final String? actorFullName;
  final AuditLogLevel level;
  final String action;
  final String? tableName;
  final String? recordId;
  final String? message;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    final rawLevel = json['level'] as String? ?? 'INFO';
    final metadata = json['metadata'];

    return AuditLogEntry(
      id: json['id'].toString(),
      actorId: json['actorId'] as String?,
      actorEmail: json['actorEmail'] as String?,
      actorFullName: json['actorFullName'] as String?,
      level: AuditLogLevel.from(rawLevel) ?? AuditLogLevel.info,
      action: json['action'] as String? ?? '',
      tableName: json['tableName'] as String?,
      recordId: json['recordId'] as String?,
      message: json['message'] as String?,
      metadata: metadata is Map ? Map<String, dynamic>.from(metadata) : null,
      createdAt: _parseDate(json['createdAt']),
    );
  }
}

class PaginatedAuditLogs {
  const PaginatedAuditLogs({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<AuditLogEntry> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory PaginatedAuditLogs.fromJson(Map<String, dynamic> json) {
    return PaginatedAuditLogs(
      items: _parseList(json['items'], AuditLogEntry.fromJson),
      page: _asInt(json['page']),
      limit: _asInt(json['limit']),
      total: _asInt(json['total']),
      totalPages: _asInt(json['totalPages']),
    );
  }
}

class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.status,
    required this.role,
    this.phoneNumber,
    this.avatarUrl,
    this.temporaryPasswordCreatedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String? avatarUrl;
  final ManagedUserStatus status;
  final DateTime? temporaryPasswordCreatedAt;
  final UserRole role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    final rawStatus =
        json['status'] as String? ?? ManagedUserStatus.active.value;

    return ManagedUser(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      status: ManagedUserStatus.from(rawStatus) ?? ManagedUserStatus.active,
      temporaryPasswordCreatedAt: _parseDate(
        json['temporaryPasswordCreatedAt'],
      ),
      role: UserRole.fromJson(json['role'] as Map<String, dynamic>),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

class CreateManagedUserResult {
  const CreateManagedUserResult({
    required this.user,
    required this.temporaryPassword,
    required this.temporaryPasswordExpiresAt,
  });

  final ManagedUser user;
  final String temporaryPassword;
  final DateTime? temporaryPasswordExpiresAt;

  factory CreateManagedUserResult.fromJson(Map<String, dynamic> json) {
    return CreateManagedUserResult(
      user: ManagedUser.fromJson(json['user'] as Map<String, dynamic>),
      temporaryPassword: json['temporaryPassword'] as String? ?? '',
      temporaryPasswordExpiresAt: _parseDate(
        json['temporaryPasswordExpiresAt'],
      ),
    );
  }
}

class UpdateUserStatusResult {
  const UpdateUserStatusResult({
    required this.user,
    this.temporaryPassword,
    this.temporaryPasswordExpiresAt,
  });

  final ManagedUser user;
  final String? temporaryPassword;
  final DateTime? temporaryPasswordExpiresAt;

  factory UpdateUserStatusResult.fromJson(Map<String, dynamic> json) {
    return UpdateUserStatusResult(
      user: ManagedUser.fromJson(json['user'] as Map<String, dynamic>),
      temporaryPassword: json['temporaryPassword'] as String?,
      temporaryPasswordExpiresAt: _parseDate(
        json['temporaryPasswordExpiresAt'],
      ),
    );
  }
}

class NotificationDispatchResult {
  const NotificationDispatchResult({
    required this.configured,
    required this.tokenCount,
    required this.successCount,
    required this.failureCount,
    required this.invalidTokenCount,
  });

  final bool configured;
  final int tokenCount;
  final int successCount;
  final int failureCount;
  final int invalidTokenCount;

  factory NotificationDispatchResult.fromJson(Map<String, dynamic> json) {
    return NotificationDispatchResult(
      configured: json['configured'] == true,
      tokenCount: _asInt(json['tokenCount']),
      successCount: _asInt(json['successCount']),
      failureCount: _asInt(json['failureCount']),
      invalidTokenCount: _asInt(json['invalidTokenCount']),
    );
  }
}

class SystemNotificationResult {
  const SystemNotificationResult({
    required this.recipientCount,
    required this.notificationCount,
    required this.fcm,
  });

  final int recipientCount;
  final int notificationCount;
  final NotificationDispatchResult fcm;

  factory SystemNotificationResult.fromJson(Map<String, dynamic> json) {
    return SystemNotificationResult(
      recipientCount: _asInt(json['recipientCount']),
      notificationCount: _asInt(json['notificationCount']),
      fcm: NotificationDispatchResult.fromJson(
        json['fcm'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

List<T> _parseList<T>(
  Object? value,
  T Function(Map<String, dynamic> json) fromJson,
) {
  if (value is! List) {
    return const [];
  }

  return value
      .whereType<Map>()
      .map((item) => fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }

  return DateTime.tryParse(value);
}
