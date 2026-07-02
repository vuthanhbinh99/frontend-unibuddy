enum StudentStorageVisibility {
  public('CONG_KHAI', 'Công khai'),
  private('RIENG_TU', 'Riêng tư'),
  group('CHIA_SE_NHOM', 'Nhóm học tập');

  const StudentStorageVisibility(this.value, this.label);

  final String value;
  final String label;

  static StudentStorageVisibility from(String? value) {
    return StudentStorageVisibility.values.firstWhere(
      (item) => item.value == value,
      orElse: () => StudentStorageVisibility.public,
    );
  }
}

enum StudentStorageCategory {
  all('Tất cả Tệp'),
  document('Tài liệu'),
  image('Hình ảnh'),
  spreadsheet('Bảng tính'),
  video('Video'),
  other('Khác');

  const StudentStorageCategory(this.label);

  final String label;
}

class StudentStorageData {
  const StudentStorageData({
    required this.message,
    required this.items,
    required this.total,
    required this.totalBytes,
    required this.storageMaxBytes,
  });

  final String message;
  final List<StudentStorageFile> items;
  final int total;
  final int totalBytes;
  final int storageMaxBytes;

  factory StudentStorageData.fromJson(Object? json) {
    final map = json as Map<String, dynamic>? ?? const {};
    final rawItems = map['items'] as List<dynamic>? ?? const [];
    return StudentStorageData(
      message: map['message'] as String? ?? '',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(StudentStorageFile.fromJson)
          .toList(),
      total: _asInt(map['total']),
      totalBytes: _asInt(map['totalBytes']),
      storageMaxBytes: _asInt(
        map['storageMaxBytes'],
        fallback: 5 * 1024 * 1024 * 1024,
      ),
    );
  }
}

class StudentStorageFile {
  const StudentStorageFile({
    required this.id,
    required this.uploaderId,
    required this.courseId,
    required this.groupId,
    required this.noteId,
    required this.downloadUrl,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.visibility,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.uploaderName,
    required this.uploaderEmail,
    required this.courseCode,
    required this.courseName,
    required this.groupName,
  });

  final String id;
  final String uploaderId;
  final String? courseId;
  final String? groupId;
  final String? noteId;
  final String downloadUrl;
  final String name;
  final String? mimeType;
  final int sizeBytes;
  final StudentStorageVisibility visibility;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? uploaderName;
  final String? uploaderEmail;
  final String? courseCode;
  final String? courseName;
  final String? groupName;

  factory StudentStorageFile.fromJson(Map<String, dynamic> json) {
    return StudentStorageFile(
      id: json['maTaiLieu'] as String? ?? '',
      uploaderId: json['nguoiTaiLen'] as String? ?? '',
      courseId: json['maMonHoc'] as String?,
      groupId: json['maNhom'] as String?,
      noteId: json['maGhiChu'] as String?,
      downloadUrl: json['duongDanLuuTru'] as String? ?? '',
      name: json['tenFile'] as String? ?? 'Tài liệu UniBuddy',
      mimeType: json['loaiFile'] as String?,
      sizeBytes: _asInt(json['dungLuong']),
      visibility: StudentStorageVisibility.from(
        json['cheDoHienThi'] as String?,
      ),
      status: json['trangThai'] as String? ?? 'KHA_DUNG',
      createdAt: _asDate(json['createdAt']),
      updatedAt: _asDate(json['updatedAt']),
      uploaderName: json['tenNguoiTaiLen'] as String?,
      uploaderEmail: json['emailNguoiTaiLen'] as String?,
      courseCode: json['maMon'] as String?,
      courseName: json['tenMonHoc'] as String?,
      groupName: json['tenNhom'] as String?,
    );
  }

  StudentStorageCategory get category {
    final type = (mimeType ?? '').toLowerCase();
    final ext = extension;
    if (type.startsWith('image/') || ['png', 'jpg', 'jpeg'].contains(ext)) {
      return StudentStorageCategory.image;
    }
    if (type.startsWith('video/') ||
        ['mp4', 'mov', 'm4v', 'webm', 'avi'].contains(ext)) {
      return StudentStorageCategory.video;
    }
    if (type.contains('spreadsheet') ||
        type.contains('excel') ||
        ext == 'xls' ||
        ext == 'xlsx') {
      return StudentStorageCategory.spreadsheet;
    }
    if (type.contains('pdf') ||
        type.contains('word') ||
        type.contains('presentation') ||
        type.startsWith('text/') ||
        ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt'].contains(ext)) {
      return StudentStorageCategory.document;
    }
    return StudentStorageCategory.other;
  }

  String get extension {
    final cleanName = name.split('?').first;
    final dot = cleanName.lastIndexOf('.');
    if (dot < 0 || dot == cleanName.length - 1) {
      return '';
    }
    return cleanName.substring(dot + 1).toLowerCase();
  }

  String get categoryLabel => category.label;

  String get authorLabel {
    final name = uploaderName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final email = uploaderEmail?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }
    return 'UniBuddy';
  }

  String get courseLabel {
    final code = courseCode?.trim();
    final title = courseName?.trim();
    if (code != null && code.isNotEmpty && title != null && title.isNotEmpty) {
      return '$code - $title';
    }
    if (title != null && title.isNotEmpty) {
      return title;
    }
    if (groupName != null && groupName!.trim().isNotEmpty) {
      return groupName!.trim();
    }
    return visibility.label;
  }

  String get updatedLabel {
    final date = updatedAt ?? createdAt;
    if (date == null) {
      return 'Vừa cập nhật';
    }

    final diff = DateTime.now().difference(date.toLocal());
    if (diff.inMinutes < 1) {
      return 'Vừa xong';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes} phút trước';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours} giờ trước';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} ngày trước';
    }
    return '${date.toLocal().day}/${date.toLocal().month}/${date.toLocal().year}';
  }
}

String formatStudentStorageBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

DateTime? _asDate(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}
