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
          .whereType<Map<String, dynamic>>()
          .map((row) => Map<String, Object?>.from(row))
          .toList(),
      suggestedMapping: StudentScheduleImportMapping.fromJson(
        json['suggestedMapping'] as Map<String, dynamic>?,
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

  factory StudentScheduleImportMapping.fromJson(Map<String, dynamic>? json) {
    String? value(String key) {
      final raw = json?[key];
      return raw is String && raw.trim().isNotEmpty ? raw : null;
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
        .whereType<Map<String, dynamic>>();
    return StudentScheduleImportPreviewData(
      message:
          json['message'] as String? ?? 'Preview thời khóa biểu thành công',
      totalRows: (json['totalRows'] as num?)?.toInt() ?? 0,
      validRows: (json['validRows'] as num?)?.toInt() ?? 0,
      invalidRows: (json['invalidRows'] as num?)?.toInt() ?? 0,
      autoCreateCourseRows:
          (json['autoCreateCourseRows'] as num?)?.toInt() ?? 0,
      hasOverlap: json['hasOverlap'] as bool? ?? false,
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
      rowIndex: (json['rowIndex'] as num?)?.toInt() ?? 0,
      isValid: json['hopLe'] as bool? ?? false,
      hasOverlap: json['trungLich'] as bool? ?? false,
      errors: (json['loi'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      schedule: rawSchedule is Map<String, dynamic>
          ? StudentScheduleImportCandidate.fromJson(rawSchedule)
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
      rowIndex: (json['rowIndex'] as num?)?.toInt() ?? 0,
      maMonHoc: json['maMonHoc'] as String?,
      maMon: json['maMon'] as String?,
      tenMon: json['tenMon'] as String? ?? '--',
      soTinChi: (json['soTinChi'] as num?)?.toInt(),
      thu: (json['thu'] as num?)?.toInt() ?? 2,
      tietBatDau: (json['tietBatDau'] as num?)?.toInt() ?? 1,
      soTiet: (json['soTiet'] as num?)?.toInt() ?? 1,
      phongHoc: json['phongHoc'] as String?,
      ngayBatDau: json['ngayBatDau'] as String?,
      ngayKetThuc: json['ngayKetThuc'] as String?,
      tuDongTaoMonHoc: json['tuDongTaoMonHoc'] as bool? ?? false,
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
      importedCount: (json['importedCount'] as num?)?.toInt() ?? 0,
      autoCreatedCourseCount:
          (json['autoCreatedCourseCount'] as num?)?.toInt() ?? 0,
    );
  }
}
