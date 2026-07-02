enum StudentNotificationStatusFilter {
  all('all'),
  unread('unread');

  const StudentNotificationStatusFilter(this.value);

  final String value;
}

enum StudentNotificationCategory {
  system('HE_THONG', 'Hệ thống'),
  deadline('DEADLINE', 'Deadline'),
  group('NHOM_HOC_TAP', 'Nhóm');

  const StudentNotificationCategory(this.value, this.label);

  final String value;
  final String label;

  static StudentNotificationCategory fromBackend(String? value) {
    final normalized = value?.trim().toUpperCase() ?? '';
    if (normalized.contains('DEADLINE') || normalized.contains('NHAC_NHO')) {
      return StudentNotificationCategory.deadline;
    }
    if (normalized.contains('NHOM') || normalized.contains('KANBAN')) {
      return StudentNotificationCategory.group;
    }
    return StudentNotificationCategory.system;
  }
}

class StudentNotificationData {
  const StudentNotificationData({
    required this.message,
    required this.items,
    required this.total,
    required this.unreadCount,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.readTrackingSupported,
  });

  final String message;
  final List<StudentNotificationItem> items;
  final int total;
  final int unreadCount;
  final int page;
  final int limit;
  final int totalPages;
  final bool readTrackingSupported;

  factory StudentNotificationData.fromJson(Object? data) {
    final map = data as Map<String, dynamic>;
    final rawItems = (map['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();

    return StudentNotificationData(
      message:
          map['message'] as String? ?? 'Tải danh sách thông báo thành công',
      items: rawItems.map(StudentNotificationItem.fromJson).toList(),
      total: (map['total'] as num?)?.toInt() ?? 0,
      unreadCount: (map['unreadCount'] as num?)?.toInt() ?? 0,
      page: (map['page'] as num?)?.toInt() ?? 1,
      limit: (map['limit'] as num?)?.toInt() ?? rawItems.length,
      totalPages: (map['totalPages'] as num?)?.toInt() ?? 1,
      readTrackingSupported: map['readTrackingSupported'] as bool? ?? false,
    );
  }
}

class StudentNotificationItem {
  const StudentNotificationItem({
    required this.id,
    required this.recipientId,
    required this.creatorId,
    required this.title,
    required this.content,
    required this.category,
    required this.backendType,
    required this.taskId,
    required this.sentAt,
    required this.createdAt,
    required this.readAt,
    required this.isRead,
  });

  final String id;
  final String recipientId;
  final String? creatorId;
  final String title;
  final String content;
  final StudentNotificationCategory category;
  final String backendType;
  final String? taskId;
  final DateTime? sentAt;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isRead;

  DateTime get displayTime => sentAt ?? createdAt;

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(displayTime.toLocal());
    if (diff.inMinutes < 1) {
      return 'Vừa xong';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    }
    if (diff.inDays == 1) {
      return 'Hôm qua';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} ngày trước';
    }

    final day = displayTime.day.toString().padLeft(2, '0');
    final month = displayTime.month.toString().padLeft(2, '0');
    return '$day/$month/${displayTime.year}';
  }

  factory StudentNotificationItem.fromJson(Map<String, dynamic> json) {
    final backendType = json['loaiThongBao'] as String? ?? 'HE_THONG';
    return StudentNotificationItem(
      id: json['maThongBao'] as String? ?? '',
      recipientId: json['maNguoiNhan'] as String? ?? '',
      creatorId: json['nguoiTao'] as String?,
      title: json['tieuDe'] as String? ?? 'Thông báo',
      content: json['noiDung'] as String? ?? '',
      category: StudentNotificationCategory.fromBackend(backendType),
      backendType: backendType,
      taskId: json['maCongViec'] as String?,
      sentAt: _parseDate(json['thoiGianDaGui']),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      readAt: _parseDate(json['readAt']),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  StudentNotificationItem copyWith({bool? isRead, DateTime? readAt}) {
    return StudentNotificationItem(
      id: id,
      recipientId: recipientId,
      creatorId: creatorId,
      title: title,
      content: content,
      category: category,
      backendType: backendType,
      taskId: taskId,
      sentAt: sentAt,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

DateTime? _parseDate(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.tryParse(value.toString());
}
