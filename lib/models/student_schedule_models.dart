class StudentScheduleItem {
  const StudentScheduleItem({
    required this.id,
    required this.courseId,
    required this.semesterId,
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
  final String semesterId;
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
      semesterId: json['maHocKy'] as String? ?? '',
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

class StudentScheduleImportHeadersData {
  const StudentScheduleImportHeadersData({
    required this.message,
    required this.headers,
    required this.rows,
    required this.suggestedMapping,
    required this.sourceType,
  });

  final String message;
  final List<String> headers;
  final List<Map<String, Object?>> rows;
  final StudentScheduleImportMapping suggestedMapping;
  final String sourceType;

  factory StudentScheduleImportHeadersData.fromJson(Map<String, dynamic> json) {
    final rawRows = json['rows'] as List<dynamic>? ?? const [];
    return StudentScheduleImportHeadersData(
      message:
          json['message'] as String? ??
          'Trích xuất header thời khóa biểu thành công',
      headers: (json['headers'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      rows: rawRows
          .whereType<Map>()
          .map(_stringKeyMap)
          .toList(),
      suggestedMapping: StudentScheduleImportMapping.fromJson(
        json['suggestedMapping'] is Map
            ? json['suggestedMapping'] as Map
            : null,
      ),
      sourceType: json['sourceType'] as String? ?? '--',
    );
  }
}

class StudentScheduleImportMapping {
  const StudentScheduleImportMapping({
    this.maMonHoc,
    this.maMon,
    this.tenMon,
    this.thu,
    this.tietBatDau,
    this.soTiet,
    this.soTinChi,
    this.phongHoc,
    this.ngayBatDau,
    this.ngayKetThuc,
  });

  final String? maMonHoc;
  final String? maMon;
  final String? tenMon;
  final String? thu;
  final String? tietBatDau;
  final String? soTiet;
  final String? soTinChi;
  final String? phongHoc;
  final String? ngayBatDau;
  final String? ngayKetThuc;

  factory StudentScheduleImportMapping.fromJson(Map? json) {
    String? value(String key) {
      final raw = json?[key];
      final text = raw?.toString().trim();
      return text == null || text.isEmpty ? null : text;
    }

    return StudentScheduleImportMapping(
      maMonHoc: value('maMonHoc'),
      maMon: value('maMon'),
      tenMon: value('tenMon'),
      thu: value('thu'),
      tietBatDau: value('tietBatDau'),
      soTiet: value('soTiet'),
      soTinChi: value('soTinChi'),
      phongHoc: value('phongHoc'),
      ngayBatDau: value('ngayBatDau'),
      ngayKetThuc: value('ngayKetThuc'),
    );
  }

  Map<String, Object?> toJson() {
    return {
      if (maMonHoc != null) 'maMonHoc': maMonHoc,
      if (maMon != null) 'maMon': maMon,
      if (tenMon != null) 'tenMon': tenMon,
      if (thu != null) 'thu': thu,
      if (tietBatDau != null) 'tietBatDau': tietBatDau,
      if (soTiet != null) 'soTiet': soTiet,
      if (soTinChi != null) 'soTinChi': soTinChi,
      if (phongHoc != null) 'phongHoc': phongHoc,
      if (ngayBatDau != null) 'ngayBatDau': ngayBatDau,
      if (ngayKetThuc != null) 'ngayKetThuc': ngayKetThuc,
    };
  }
}

class StudentScheduleImportPreviewData {
  const StudentScheduleImportPreviewData({
    required this.message,
    required this.totalRows,
    required this.validRows,
    required this.invalidRows,
    required this.autoCreateCourseRows,
    required this.hasOverlap,
    required this.items,
  });

  final String message;
  final int totalRows;
  final int validRows;
  final int invalidRows;
  final int autoCreateCourseRows;
  final bool hasOverlap;
  final List<StudentScheduleImportPreviewItem> items;

  List<StudentScheduleImportCandidate> get validItems {
    return items
        .where((item) => item.isValid && item.schedule != null)
        .map((item) => item.schedule!)
        .toList();
  }

  factory StudentScheduleImportPreviewData.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(_stringKeyMap);
    return StudentScheduleImportPreviewData(
      message:
          json['message'] as String? ?? 'Preview thời khóa biểu thành công',
      totalRows: _intValue(json['totalRows']) ?? 0,
      validRows: _intValue(json['validRows']) ?? 0,
      invalidRows: _intValue(json['invalidRows']) ?? 0,
      autoCreateCourseRows: _intValue(json['autoCreateCourseRows']) ?? 0,
      hasOverlap: _boolValue(json['hasOverlap']),
      items: rawItems.map(StudentScheduleImportPreviewItem.fromJson).toList(),
    );
  }
}

class StudentScheduleImportPreviewItem {
  const StudentScheduleImportPreviewItem({
    required this.rowIndex,
    required this.isValid,
    required this.hasOverlap,
    required this.errors,
    required this.schedule,
  });

  final int rowIndex;
  final bool isValid;
  final bool hasOverlap;
  final List<String> errors;
  final StudentScheduleImportCandidate? schedule;

  factory StudentScheduleImportPreviewItem.fromJson(Map<String, dynamic> json) {
    final rawSchedule = json['lichHoc'];
    return StudentScheduleImportPreviewItem(
      rowIndex: _intValue(json['rowIndex']) ?? 0,
      isValid: _boolValue(json['hopLe']),
      hasOverlap: _boolValue(json['trungLich']),
      errors: (json['loi'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      schedule: rawSchedule is Map
          ? StudentScheduleImportCandidate.fromJson(_stringKeyMap(rawSchedule))
          : null,
    );
  }
}

class StudentScheduleImportCandidate {
  const StudentScheduleImportCandidate({
    required this.rowIndex,
    required this.maMonHoc,
    required this.maMon,
    required this.tenMon,
    required this.soTinChi,
    required this.thu,
    required this.tietBatDau,
    required this.soTiet,
    required this.phongHoc,
    required this.ngayBatDau,
    required this.ngayKetThuc,
    required this.tuDongTaoMonHoc,
  });

  final int rowIndex;
  final String? maMonHoc;
  final String? maMon;
  final String tenMon;
  final int? soTinChi;
  final int thu;
  final int tietBatDau;
  final int soTiet;
  final String? phongHoc;
  final String? ngayBatDau;
  final String? ngayKetThuc;
  final bool tuDongTaoMonHoc;

  factory StudentScheduleImportCandidate.fromJson(Map<String, dynamic> json) {
    return StudentScheduleImportCandidate(
      rowIndex: _intValue(json['rowIndex']) ?? 0,
      maMonHoc: _nullableText(json['maMonHoc']),
      maMon: _nullableText(json['maMon']),
      tenMon: _nullableText(json['tenMon']) ?? '--',
      soTinChi: _intValue(json['soTinChi']),
      thu: _intValue(json['thu']) ?? 2,
      tietBatDau: _intValue(json['tietBatDau']) ?? 1,
      soTiet: _intValue(json['soTiet']) ?? 1,
      phongHoc: _nullableText(json['phongHoc']),
      ngayBatDau: _nullableText(json['ngayBatDau']),
      ngayKetThuc: _nullableText(json['ngayKetThuc']),
      tuDongTaoMonHoc: _boolValue(json['tuDongTaoMonHoc']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'maMonHoc': maMonHoc,
      'rowIndex': rowIndex,
      'maMon': maMon,
      'tenMon': tenMon,
      'soTinChi': soTinChi,
      'thu': thu,
      'tietBatDau': tietBatDau,
      'soTiet': soTiet,
      'phongHoc': phongHoc,
      'ngayBatDau': ngayBatDau,
      'ngayKetThuc': ngayKetThuc,
      'tuDongTaoMonHoc': tuDongTaoMonHoc,
    };
  }
}

Map<String, dynamic> _stringKeyMap(Map map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}

String? _nullableText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _intValue(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

bool _boolValue(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

class StudentScheduleImportConfirmData {
  const StudentScheduleImportConfirmData({
    required this.message,
    required this.importedCount,
    required this.autoCreatedCourseCount,
  });

  final String message;
  final int importedCount;
  final int autoCreatedCourseCount;

  factory StudentScheduleImportConfirmData.fromJson(Map<String, dynamic> json) {
    return StudentScheduleImportConfirmData(
      message:
          json['message'] as String? ??
          'Đồng bộ thành công! Thời khóa biểu của bạn đã được cập nhật.',
      importedCount: _intValue(json['importedCount']) ?? 0,
      autoCreatedCourseCount: _intValue(json['autoCreatedCourseCount']) ?? 0,
    );
  }
}
