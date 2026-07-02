enum StudentKanbanStatus {
  todo('CHUA_BAT_DAU', 'Cần làm'),
  doing('DANG_THUC_HIEN', 'Đang làm'),
  done('HOAN_THANH', 'Xong'),
  overdue('TRE_HAN', 'Trễ hạn');

  const StudentKanbanStatus(this.value, this.label);

  final String value;
  final String label;

  static StudentKanbanStatus from(String? value) {
    return StudentKanbanStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => StudentKanbanStatus.todo,
    );
  }
}

class StudentKanbanBoardData {
  const StudentKanbanBoardData({
    required this.message,
    required this.group,
    required this.myRole,
    required this.members,
    required this.total,
    required this.positionPersistence,
    required this.columns,
  });

  final String message;
  final StudentKanbanGroup group;
  final String myRole;
  final List<StudentKanbanMember> members;
  final int total;
  final bool positionPersistence;
  final List<StudentKanbanColumn> columns;

  List<StudentKanbanTask> get tasks {
    return columns.expand((column) => column.items).toList();
  }

  factory StudentKanbanBoardData.fromJson(Object? data) {
    final map = data as Map<String, dynamic>;
    final rawColumns = (map['columns'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();
    final rawMembers = (map['thanhVien'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();

    return StudentKanbanBoardData(
      message:
          map['message'] as String? ?? 'Tải bảng công việc Kanban thành công',
      group: StudentKanbanGroup.fromJson(
        map['nhom'] as Map<String, dynamic>? ?? const {},
      ),
      myRole: map['vaiTroCuaToi'] as String? ?? 'THANH_VIEN',
      members: rawMembers.map(StudentKanbanMember.fromJson).toList(),
      total: (map['total'] as num?)?.toInt() ?? 0,
      positionPersistence: map['positionPersistence'] == true,
      columns: rawColumns.map(StudentKanbanColumn.fromJson).toList(),
    );
  }
}

class StudentKanbanGroup {
  const StudentKanbanGroup({
    required this.id,
    required this.name,
    required this.chatLink,
  });

  final String id;
  final String name;
  final String chatLink;

  factory StudentKanbanGroup.fromJson(Map<String, dynamic> json) {
    return StudentKanbanGroup(
      id: json['maNhom'] as String? ?? '',
      name: json['tenNhom'] as String? ?? 'Nhóm học tập',
      chatLink: json['linkNhomChat'] as String? ?? '',
    );
  }
}

class StudentKanbanColumn {
  const StudentKanbanColumn({
    required this.status,
    required this.title,
    required this.items,
  });

  final StudentKanbanStatus status;
  final String title;
  final List<StudentKanbanTask> items;

  factory StudentKanbanColumn.fromJson(Map<String, dynamic> json) {
    final status = StudentKanbanStatus.from(json['trangThai'] as String?);
    final rawItems = (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();

    return StudentKanbanColumn(
      status: status,
      title: json['tieuDe'] as String? ?? status.label,
      items: rawItems.map(StudentKanbanTask.fromJson).toList(),
    );
  }
}

class StudentKanbanMember {
  const StudentKanbanMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  final String id;
  final String name;
  final String email;
  final String role;

  String get initials {
    final words = name
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return '?';
    }
    if (words.length == 1) {
      return _firstLetter(words.first);
    }
    return '${_firstLetter(words.first)}${_firstLetter(words.last)}';
  }

  factory StudentKanbanMember.fromJson(Map<String, dynamic> json) {
    return StudentKanbanMember(
      id: json['maNguoiDung'] as String? ?? '',
      name: json['hoTen'] as String? ?? 'Thành viên',
      email: json['email'] as String? ?? '',
      role: json['vaiTroTrongNhom'] as String? ?? 'THANH_VIEN',
    );
  }
}

class StudentKanbanTask {
  const StudentKanbanTask({
    required this.id,
    required this.groupId,
    required this.assigneeId,
    required this.assigneeName,
    required this.assigneeEmail,
    required this.title,
    required this.description,
    required this.status,
    required this.dueDate,
    required this.position,
    required this.commentCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String groupId;
  final String? assigneeId;
  final String? assigneeName;
  final String? assigneeEmail;
  final String title;
  final String? description;
  final StudentKanbanStatus status;
  final DateTime? dueDate;
  final int position;
  final int commentCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StudentKanbanTask copyWith({
    String? id,
    String? groupId,
    Object? assigneeId = _sentinel,
    Object? assigneeName = _sentinel,
    Object? assigneeEmail = _sentinel,
    String? title,
    Object? description = _sentinel,
    StudentKanbanStatus? status,
    Object? dueDate = _sentinel,
    int? position,
    int? commentCount,
    Object? createdAt = _sentinel,
    Object? updatedAt = _sentinel,
  }) {
    return StudentKanbanTask(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      assigneeId: assigneeId == _sentinel
          ? this.assigneeId
          : assigneeId as String?,
      assigneeName: assigneeName == _sentinel
          ? this.assigneeName
          : assigneeName as String?,
      assigneeEmail: assigneeEmail == _sentinel
          ? this.assigneeEmail
          : assigneeEmail as String?,
      title: title ?? this.title,
      description: description == _sentinel
          ? this.description
          : description as String?,
      status: status ?? this.status,
      dueDate: dueDate == _sentinel ? this.dueDate : dueDate as DateTime?,
      position: position ?? this.position,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt == _sentinel
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: updatedAt == _sentinel
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }

  factory StudentKanbanTask.fromJson(Map<String, dynamic> json) {
    return StudentKanbanTask(
      id: json['maCongViec'] as String? ?? '',
      groupId: json['maNhom'] as String? ?? '',
      assigneeId: json['nguoiDuocGiao'] as String?,
      assigneeName: json['nguoiDuocGiaoHoTen'] as String?,
      assigneeEmail: json['nguoiDuocGiaoEmail'] as String?,
      title: json['tieuDe'] as String? ?? 'Công việc chưa đặt tên',
      description: json['moTa'] as String?,
      status: StudentKanbanStatus.from(json['trangThai'] as String?),
      dueDate: _parseDate(json['hanHoanThanh']),
      position: (json['viTri'] as num?)?.toInt() ?? 0,
      commentCount: (json['soBinhLuan'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

class StudentKanbanComment {
  const StudentKanbanComment({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.authorName,
    required this.authorEmail,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final String userId;
  final String authorName;
  final String authorEmail;
  final String content;
  final DateTime? createdAt;

  factory StudentKanbanComment.fromJson(Map<String, dynamic> json) {
    return StudentKanbanComment(
      id: json['maBinhLuan'] as String? ?? '',
      taskId: json['maCongViec'] as String? ?? '',
      userId: json['maNguoiDung'] as String? ?? '',
      authorName: json['hoTen'] as String? ?? 'Bạn',
      authorEmail: json['email'] as String? ?? '',
      content: json['noiDung'] as String? ?? '',
      createdAt: _parseDate(json['createdAt']),
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

String _firstLetter(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

const Object _sentinel = Object();
