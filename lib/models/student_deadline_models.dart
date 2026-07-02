enum StudentDeadlineStatus {
  todo('CHUA_LAM'),
  inProgress('DANG_LAM'),
  completed('HOAN_THANH'),
  overdue('TRE_HAN');

  const StudentDeadlineStatus(this.value);

  final String value;

  static StudentDeadlineStatus from(String? value) {
    return StudentDeadlineStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => StudentDeadlineStatus.todo,
    );
  }
}

class StudentDeadlineSummary {
  const StudentDeadlineSummary({
    required this.todo,
    required this.inProgress,
    required this.completed,
    required this.overdue,
  });

  final int todo;
  final int inProgress;
  final int completed;
  final int overdue;

  factory StudentDeadlineSummary.fromJson(Map<String, dynamic>? json) {
    return StudentDeadlineSummary(
      todo: (json?['chuaLam'] as num?)?.toInt() ?? 0,
      inProgress: (json?['dangLam'] as num?)?.toInt() ?? 0,
      completed: (json?['hoanThanh'] as num?)?.toInt() ?? 0,
      overdue: (json?['treHan'] as num?)?.toInt() ?? 0,
    );
  }
}

class StudentDeadlineItem {
  const StudentDeadlineItem({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.title,
    required this.description,
    required this.dueAt,
    required this.status,
    required this.reminderCount,
  });

  final String id;
  final String courseId;
  final String? courseCode;
  final String courseName;
  final String title;
  final String? description;
  final DateTime? dueAt;
  final StudentDeadlineStatus status;
  final int reminderCount;

  bool get completed => status == StudentDeadlineStatus.completed;

  factory StudentDeadlineItem.fromJson(Map<String, dynamic> json) {
    return StudentDeadlineItem(
      id: json['maDeadline'] as String,
      courseId: json['maMonHoc'] as String,
      courseCode: json['maMon'] as String?,
      courseName: json['tenMon'] as String? ?? '--',
      title: json['tieuDe'] as String? ?? '--',
      description: json['moTa'] as String?,
      dueAt: _parseDate(json['hanNop']),
      status: StudentDeadlineStatus.from(json['trangThai'] as String?),
      reminderCount: (json['soNhacNho'] as num?)?.toInt() ?? 0,
    );
  }
}

class StudentDeadlineData {
  const StudentDeadlineData({
    required this.message,
    required this.total,
    required this.summary,
    required this.items,
  });

  final String message;
  final int total;
  final StudentDeadlineSummary summary;
  final List<StudentDeadlineItem> items;

  factory StudentDeadlineData.fromJson(Object? data) {
    if (data is List<dynamic>) {
      final items = data
          .cast<Map<String, dynamic>>()
          .map(StudentDeadlineItem.fromJson)
          .toList();
      return StudentDeadlineData(
        message: items.isEmpty
            ? 'Bạn chưa có deadline nào cần xử lý.'
            : 'Tải danh sách deadline thành công',
        total: items.length,
        summary: StudentDeadlineSummary(
          todo: items
              .where((item) => item.status == StudentDeadlineStatus.todo)
              .length,
          inProgress: items
              .where((item) => item.status == StudentDeadlineStatus.inProgress)
              .length,
          completed: items
              .where((item) => item.status == StudentDeadlineStatus.completed)
              .length,
          overdue: items
              .where((item) => item.status == StudentDeadlineStatus.overdue)
              .length,
        ),
        items: items,
      );
    }

    final map = data as Map<String, dynamic>;
    final rawItems = (map['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return StudentDeadlineData(
      message: map['message'] as String? ?? 'Tải danh sách deadline thành công',
      total: (map['total'] as num?)?.toInt() ?? rawItems.length,
      summary: StudentDeadlineSummary.fromJson(
        map['thongKeTrangThai'] as Map<String, dynamic>?,
      ),
      items: rawItems.map(StudentDeadlineItem.fromJson).toList(),
    );
  }
}

DateTime? _parseDate(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
