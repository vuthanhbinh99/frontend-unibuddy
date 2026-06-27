class StudentSemester {
  const StudentSemester({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  final String id;
  final String name;
  final String? startDate;
  final String? endDate;

  factory StudentSemester.fromJson(Map<String, dynamic> json) {
    return StudentSemester(
      id: json['maHocKy'] as String,
      name: json['tenHocKy'] as String? ?? '--',
      startDate: json['ngayBatDau'] as String?,
      endDate: json['ngayKetThuc'] as String?,
    );
  }
}

class StudentCourseItem {
  const StudentCourseItem({
    required this.id,
    required this.semesterId,
    required this.code,
    required this.name,
    required this.credits,
    required this.semesterName,
  });

  final String id;
  final String semesterId;
  final String? code;
  final String name;
  final int credits;
  final String semesterName;

  factory StudentCourseItem.fromJson(Map<String, dynamic> json) {
    return StudentCourseItem(
      id: json['maMonHoc'] as String,
      semesterId: json['maHocKy'] as String,
      code: json['maMon'] as String?,
      name: json['tenMon'] as String? ?? '--',
      credits: (json['soTinChi'] as num?)?.toInt() ?? 0,
      semesterName: json['tenHocKy'] as String? ?? '--',
    );
  }
}

class StudentCourseData {
  const StudentCourseData({
    required this.message,
    required this.selectedSemesterId,
    required this.semesters,
    required this.items,
  });

  final String message;
  final String? selectedSemesterId;
  final List<StudentSemester> semesters;
  final List<StudentCourseItem> items;

  factory StudentCourseData.fromJson(Object? data) {
    if (data is List<dynamic>) {
      return StudentCourseData(
        message: 'Lấy danh sách môn học thành công',
        selectedSemesterId: null,
        semesters: const [],
        items: data
            .cast<Map<String, dynamic>>()
            .map(StudentCourseItem.fromJson)
            .toList(),
      );
    }

    final map = data as Map<String, dynamic>;
    final rawSemesters = (map['hocKy'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final rawItems = (map['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    return StudentCourseData(
      message: map['message'] as String? ?? 'Lấy danh sách môn học thành công',
      selectedSemesterId: map['selectedMaHocKy'] as String?,
      semesters: rawSemesters.map(StudentSemester.fromJson).toList(),
      items: rawItems.map(StudentCourseItem.fromJson).toList(),
    );
  }
}
