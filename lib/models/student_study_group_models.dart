enum StudentStudyGroupRole {
  leader('TRUONG_NHOM', 'TRƯỞNG NHÓM'),
  member('THANH_VIEN', 'THÀNH VIÊN');

  const StudentStudyGroupRole(this.value, this.label);

  final String value;
  final String label;

  static StudentStudyGroupRole from(String? value) {
    return StudentStudyGroupRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => StudentStudyGroupRole.member,
    );
  }
}

class StudentStudyGroupData {
  const StudentStudyGroupData({required this.message, required this.items});

  final String message;
  final List<StudentStudyGroup> items;

  factory StudentStudyGroupData.fromJson(Object? data) {
    final map = data as Map<String, dynamic>;
    final rawItems = (map['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();

    return StudentStudyGroupData(
      message:
          map['message'] as String? ?? 'Tải danh sách nhóm học tập thành công',
      items: rawItems.map(StudentStudyGroup.fromJson).toList(),
    );
  }
}

class StudentStudyGroup {
  const StudentStudyGroup({
    required this.id,
    required this.creatorId,
    required this.name,
    required this.courseCode,
    required this.schoolId,
    required this.inviteCode,
    required this.chatLink,
    required this.role,
    required this.memberCount,
    required this.joinedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String creatorId;
  final String name;
  final String? courseCode;
  final int? schoolId;
  final String inviteCode;
  final String chatLink;
  final StudentStudyGroupRole role;
  final int memberCount;
  final DateTime? joinedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isLeader => role == StudentStudyGroupRole.leader;

  String get courseLabel {
    final code = courseCode?.trim();
    return code == null || code.isEmpty ? 'NHÓM' : code.toUpperCase();
  }

  String get description {
    final code = courseCode?.trim();
    if (code == null || code.isEmpty) {
      return 'Không gian học tập nhóm, phân công nhiệm vụ và theo dõi tiến độ cùng nhau.';
    }
    return 'Nhóm học tập môn ${code.toUpperCase()}, cùng trao đổi tài liệu, lịch học và công việc Kanban.';
  }

  String get timeString {
    final date = joinedAt ?? createdAt;
    if (date == null) {
      return 'Đang hoạt động';
    }
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return 'Tham gia $day/$month';
  }

  List<String> get initials {
    final words = name
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return const ['U'];
    }
    final output = words.take(3).map(_firstLetter).toList();
    return output.isEmpty ? const ['U'] : output;
  }

  factory StudentStudyGroup.fromJson(Map<String, dynamic> json) {
    return StudentStudyGroup(
      id: json['maNhom'] as String? ?? '',
      creatorId: json['nguoiTao'] as String? ?? '',
      name: json['tenNhom'] as String? ?? 'Nhóm học tập',
      courseCode: json['maMon'] as String?,
      schoolId: (json['maTruong'] as num?)?.toInt(),
      inviteCode: json['maThamGia'] as String? ?? '',
      chatLink: json['linkNhomChat'] as String? ?? '',
      role: StudentStudyGroupRole.from(json['vaiTroTrongNhom'] as String?),
      memberCount: (json['soThanhVien'] as num?)?.toInt() ?? 1,
      joinedAt: _parseDate(json['thoiGianThamGia']),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  factory StudentStudyGroup.fromMutation(
    Map<String, dynamic> groupJson, {
    Map<String, dynamic>? memberJson,
    StudentStudyGroupRole fallbackRole = StudentStudyGroupRole.member,
  }) {
    final merged = {
      ...groupJson,
      'vaiTroTrongNhom':
          memberJson?['vaiTroTrongNhom'] as String? ?? fallbackRole.value,
      'thoiGianThamGia': memberJson?['thoiGianThamGia'],
      'soThanhVien': groupJson['soThanhVien'] ?? 1,
    };
    return StudentStudyGroup.fromJson(merged);
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
    return 'U';
  }
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}
