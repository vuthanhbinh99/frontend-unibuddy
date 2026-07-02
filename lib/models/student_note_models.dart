import 'student_course_models.dart';

enum StudentNoteSort {
  updatedDesc('updated_desc'),
  updatedAsc('updated_asc'),
  createdDesc('created_desc'),
  createdAsc('created_asc'),
  titleAsc('title_asc'),
  titleDesc('title_desc');

  const StudentNoteSort(this.value);

  final String value;
}

class StudentNoteData {
  const StudentNoteData({
    required this.message,
    required this.total,
    required this.page,
    required this.limit,
    required this.items,
  });

  final String? message;
  final int total;
  final int page;
  final int limit;
  final List<StudentNote> items;

  factory StudentNoteData.fromJson(Object? data) {
    final map = data as Map<String, dynamic>;
    final rawItems = (map['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    return StudentNoteData(
      message: map['message'] as String?,
      total: (map['total'] as num?)?.toInt() ?? rawItems.length,
      page: (map['page'] as num?)?.toInt() ?? 1,
      limit: (map['limit'] as num?)?.toInt() ?? rawItems.length,
      items: rawItems.map(StudentNote.fromJson).toList(),
    );
  }
}

class StudentNote {
  const StudentNote({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.attachmentCount,
    required this.attachments,
  });

  final String id;
  final String userId;
  final String? courseId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int attachmentCount;
  final List<StudentNoteAttachment> attachments;

  factory StudentNote.fromJson(Map<String, dynamic> json) {
    final rawAttachments = (json['tepDinhKem'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();
    return StudentNote(
      id: json['maGhiChu'] as String,
      userId: json['maNguoiDung'] as String? ?? '',
      courseId: json['maMonHoc'] as String?,
      title: json['tieuDe'] as String? ?? '--',
      content: json['noiDung'] as String? ?? '',
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updatedAt']) ?? DateTime.now(),
      attachmentCount: (json['soTepDinhKem'] as num?)?.toInt() ?? 0,
      attachments: rawAttachments.map(StudentNoteAttachment.fromJson).toList(),
    );
  }

  String categoryName(List<StudentCourseItem> courses) {
    if (courseId == null) {
      return StudentNoteCategories.uncategorized;
    }

    final course = _findCourse(courses, courseId);
    return course?.name ?? StudentNoteCategories.uncategorized;
  }

  List<String> displayTags(List<StudentCourseItem> courses) {
    final tags = <String>[];
    final course = _findCourse(courses, courseId);
    if (course?.code != null && course!.code!.trim().isNotEmpty) {
      tags.add(course.code!.trim());
    } else if (course != null) {
      tags.add(course.name);
    }

    final extracted = RegExp(r'#[^\s#,.!?;:(){}\[\]<>]+')
        .allMatches('$title $content')
        .map((match) => match.group(0)!.substring(1))
        .where((tag) => tag.trim().isNotEmpty);
    tags.addAll(extracted);

    if (attachmentCount > 0 || attachments.isNotEmpty) {
      tags.add('Tệp đính kèm');
    }

    return tags.toSet().take(4).toList();
  }
}

class StudentNoteAttachment {
  const StudentNoteAttachment({
    required this.id,
    required this.noteId,
    required this.name,
    required this.url,
    required this.fileType,
    required this.size,
  });

  final String id;
  final String noteId;
  final String name;
  final String url;
  final String? fileType;
  final int? size;

  factory StudentNoteAttachment.fromJson(Map<String, dynamic> json) {
    return StudentNoteAttachment(
      id: json['maTaiLieu'] as String? ?? '',
      noteId: json['maGhiChu'] as String? ?? '',
      name: json['tenFile'] as String? ?? '--',
      url: json['duongDanLuuTru'] as String? ?? '',
      fileType: json['loaiFile'] as String?,
      size: (json['dungLuong'] as num?)?.toInt(),
    );
  }
}

class StudentNoteAttachmentInput {
  const StudentNoteAttachmentInput({
    required this.downloadUrl,
    required this.name,
    required this.fileType,
    required this.size,
  });

  final String downloadUrl;
  final String name;
  final String fileType;
  final int size;

  Map<String, Object?> toJson() {
    return {
      'downloadUrl': downloadUrl,
      'tenFile': name,
      'loaiFile': fileType,
      'dungLuong': size,
    };
  }
}

class StudentNoteCategories {
  const StudentNoteCategories._();

  static const all = 'Tất cả ghi chú';
  static const uncategorized = 'Không gắn môn';
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

StudentCourseItem? _findCourse(List<StudentCourseItem> courses, String? id) {
  if (id == null) {
    return null;
  }

  for (final course in courses) {
    if (course.id == id) {
      return course;
    }
  }
  return null;
}
