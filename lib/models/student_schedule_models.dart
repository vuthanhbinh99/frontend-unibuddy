class StudentScheduleItem {
  const StudentScheduleItem({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.semesterName,
    required this.dayOfWeek,
    required this.startPeriod,
    required this.periodCount,
    required this.room,
    required this.startDate,
    required this.endDate,
  });

  final String id;
  final String courseId;
  final String? courseCode;
  final String courseName;
  final String semesterName;
  final int dayOfWeek;
  final int startPeriod;
  final int periodCount;
  final String? room;
  final String? startDate;
  final String? endDate;

  int get endPeriod => startPeriod + periodCount - 1;

  String get dayLabel => dayOfWeek == 8 ? 'CN' : 'Thứ $dayOfWeek';

  factory StudentScheduleItem.fromJson(Map<String, dynamic> json) {
    return StudentScheduleItem(
      id: json['maLichHoc'] as String,
      courseId: json['maMonHoc'] as String,
      courseCode: json['maMon'] as String?,
      courseName: json['tenMon'] as String? ?? '--',
      semesterName: json['tenHocKy'] as String? ?? '--',
      dayOfWeek: (json['thu'] as num?)?.toInt() ?? 2,
      startPeriod: (json['tietBatDau'] as num?)?.toInt() ?? 1,
      periodCount: (json['soTiet'] as num?)?.toInt() ?? 1,
      room: json['phongHoc'] as String?,
      startDate: json['ngayBatDau'] as String?,
      endDate: json['ngayKetThuc'] as String?,
    );
  }
}

class StudentScheduleData {
  const StudentScheduleData({
    required this.message,
    required this.warning,
    required this.items,
  });

  final String message;
  final String? warning;
  final List<StudentScheduleItem> items;

  factory StudentScheduleData.fromJson(Object? data) {
    if (data is List<dynamic>) {
      return StudentScheduleData(
        message: 'Lấy thời khóa biểu thành công',
        warning: null,
        items: data
            .cast<Map<String, dynamic>>()
            .map(StudentScheduleItem.fromJson)
            .toList(),
      );
    }

    final map = data as Map<String, dynamic>;
    final rawItems = (map['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    return StudentScheduleData(
      message: map['message'] as String? ?? 'Lấy thời khóa biểu thành công',
      warning: map['warning'] as String?,
      items: rawItems.map(StudentScheduleItem.fromJson).toList(),
    );
  }
}
