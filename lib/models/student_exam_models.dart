class StudentExamItem {
  const StudentExamItem({
    required this.id,
    required this.courseId,
    required this.semesterId,
    required this.courseCode,
    required this.courseName,
    required this.semesterName,
    required this.examTime,
    required this.room,
    required this.examLocation,
    required this.reminderCount,
  });

  final String id;
  final String courseId;
  final String semesterId;
  final String? courseCode;
  final String courseName;
  final String semesterName;
  final DateTime examTime;
  final String? room;
  final String? examLocation;
  final int reminderCount;

  factory StudentExamItem.fromJson(Map<String, dynamic> json) {
    return StudentExamItem(
      id: json['maLichThi'] as String,
      courseId: json['maMonHoc'] as String,
      semesterId: json['maHocKy'] as String? ?? '',
      courseCode: json['maMon'] as String?,
      courseName: json['tenMon'] as String? ?? '--',
      semesterName: json['tenHocKy'] as String? ?? '--',
      examTime:
          DateTime.tryParse(json['thoiGianThi']?.toString() ?? '') ??
          DateTime.now(),
      room: _nullableText(json['phongThi']),
      examLocation: _nullableText(json['diaDiemThi']),
      reminderCount: _intValue(json['soNhacNho']) ?? 0,
    );
  }
}

class StudentExamData {
  const StudentExamData({
    required this.message,
    required this.items,
  });

  final String message;
  final List<StudentExamItem> items;

  factory StudentExamData.fromJson(Object? data) {
    if (data is List<dynamic>) {
      return StudentExamData(
        message: 'Lấy danh sách lịch thi thành công',
        items: data
            .cast<Map<String, dynamic>>()
            .map(StudentExamItem.fromJson)
            .toList(),
      );
    }

    final map = data as Map<String, dynamic>;
    final rawItems = (map['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return StudentExamData(
      message: map['message'] as String? ?? 'Lấy danh sách lịch thi thành công',
      items: rawItems.map(StudentExamItem.fromJson).toList(),
    );
  }
}

class StudentExamImportHeadersData {
  const StudentExamImportHeadersData({
    required this.message,
    required this.headers,
    required this.rows,
    required this.suggestedMapping,
    required this.sourceType,
  });

  final String message;
  final List<String> headers;
  final List<Map<String, Object?>> rows;
  final StudentExamImportMapping suggestedMapping;
  final String sourceType;

  factory StudentExamImportHeadersData.fromJson(Map<String, dynamic> json) {
    final rawRows = json['rows'] as List<dynamic>? ?? const [];
    return StudentExamImportHeadersData(
      message: json['message'] as String? ?? 'Trích xuất header lịch thi thành công',
      headers: (json['headers'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      rows: rawRows.whereType<Map>().map(_stringKeyMap).toList(),
      suggestedMapping: StudentExamImportMapping.fromJson(
        json['suggestedMapping'] is Map ? json['suggestedMapping'] as Map : null,
      ),
      sourceType: json['sourceType'] as String? ?? '--',
    );
  }
}

class StudentExamImportMapping {
  const StudentExamImportMapping({
    this.maMonHoc,
    this.maMon,
    this.tenMon,
    this.thoiGianThi,
    this.ngayThi,
    this.gioBatDau,
    this.phongThi,
    this.diaDiemThi,
  });

  final String? maMonHoc;
  final String? maMon;
  final String? tenMon;
  final String? thoiGianThi;
  final String? ngayThi;
  final String? gioBatDau;
  final String? phongThi;
  final String? diaDiemThi;

  factory StudentExamImportMapping.fromJson(Map? json) {
    String? value(String key) {
      final raw = json?[key];
      final text = raw?.toString().trim();
      return text == null || text.isEmpty ? null : text;
    }

    return StudentExamImportMapping(
      maMonHoc: value('maMonHoc'),
      maMon: value('maMon'),
      tenMon: value('tenMon'),
      thoiGianThi: value('thoiGianThi'),
      ngayThi: value('ngayThi'),
      gioBatDau: value('gioBatDau'),
      phongThi: value('phongThi'),
      diaDiemThi: value('diaDiemThi'),
    );
  }

  Map<String, Object?> toJson() {
    return {
      if (maMonHoc != null) 'maMonHoc': maMonHoc,
      if (maMon != null) 'maMon': maMon,
      if (tenMon != null) 'tenMon': tenMon,
      if (thoiGianThi != null) 'thoiGianThi': thoiGianThi,
      if (ngayThi != null) 'ngayThi': ngayThi,
      if (gioBatDau != null) 'gioBatDau': gioBatDau,
      if (phongThi != null) 'phongThi': phongThi,
      if (diaDiemThi != null) 'diaDiemThi': diaDiemThi,
    };
  }
}

class StudentExamImportPreviewData {
  const StudentExamImportPreviewData({
    required this.message,
    required this.totalRows,
    required this.validRows,
    required this.invalidRows,
    required this.existingExamRows,
    required this.hasExistingExam,
    required this.mapping,
    required this.items,
  });

  final String message;
  final int totalRows;
  final int validRows;
  final int invalidRows;
  final int existingExamRows;
  final bool hasExistingExam;
  final StudentExamImportMapping? mapping;
  final List<StudentExamImportPreviewItem> items;

  List<StudentExamImportCandidate> get validItems {
    return items
        .where((item) => item.isValid && item.exam != null)
        .map((item) => item.exam!)
        .toList();
  }

  factory StudentExamImportPreviewData.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(_stringKeyMap);
    return StudentExamImportPreviewData(
      message: json['message'] as String? ?? 'Preview lịch thi thành công',
      totalRows: _intValue(json['totalRows']) ?? 0,
      validRows: _intValue(json['validRows']) ?? 0,
      invalidRows: _intValue(json['invalidRows']) ?? 0,
      existingExamRows: _intValue(json['existingExamRows']) ?? 0,
      hasExistingExam: _boolValue(json['hasExistingExam']),
      mapping: json['mapping'] is Map
          ? StudentExamImportMapping.fromJson(json['mapping'] as Map)
          : null,
      items: rawItems.map(StudentExamImportPreviewItem.fromJson).toList(),
    );
  }
}

class StudentExamImportPreviewItem {
  const StudentExamImportPreviewItem({
    required this.rowIndex,
    required this.isValid,
    required this.errors,
    required this.hasExistingExam,
    required this.exam,
  });

  final int rowIndex;
  final bool isValid;
  final List<String> errors;
  final bool hasExistingExam;
  final StudentExamImportCandidate? exam;

  factory StudentExamImportPreviewItem.fromJson(Map<String, dynamic> json) {
    final rawExam = json['lichThi'];
    return StudentExamImportPreviewItem(
      rowIndex: _intValue(json['rowIndex']) ?? 0,
      isValid: _boolValue(json['hopLe']),
      errors: (json['loi'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      hasExistingExam: _boolValue(json['daCoLichThi']),
      exam: rawExam is Map
          ? StudentExamImportCandidate.fromJson(_stringKeyMap(rawExam))
          : null,
    );
  }
}

class StudentExamImportCandidate {
  const StudentExamImportCandidate({
    required this.rowIndex,
    required this.maMonHoc,
    required this.maMon,
    required this.tenMon,
    required this.thoiGianThi,
    required this.phongThi,
    required this.diaDiemThi,
  });

  final int rowIndex;
  final String maMonHoc;
  final String? maMon;
  final String tenMon;
  final DateTime thoiGianThi;
  final String? phongThi;
  final String? diaDiemThi;

  factory StudentExamImportCandidate.fromJson(Map<String, dynamic> json) {
    return StudentExamImportCandidate(
      rowIndex: _intValue(json['rowIndex']) ?? 0,
      maMonHoc: json['maMonHoc'] as String,
      maMon: _nullableText(json['maMon']),
      tenMon: _nullableText(json['tenMon']) ?? '--',
      thoiGianThi:
          DateTime.tryParse(json['thoiGianThi']?.toString() ?? '') ??
          DateTime.now(),
      phongThi: _nullableText(json['phongThi']),
      diaDiemThi: _nullableText(json['diaDiemThi']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'rowIndex': rowIndex,
      'maMonHoc': maMonHoc,
      'maMon': maMon,
      'tenMon': tenMon,
      'thoiGianThi': thoiGianThi.toIso8601String(),
      'phongThi': phongThi,
      'diaDiemThi': diaDiemThi,
    };
  }
}

class StudentExamImportConfirmData {
  const StudentExamImportConfirmData({
    required this.message,
    required this.importedCount,
    required this.replacedExamCount,
  });

  final String message;
  final int importedCount;
  final int replacedExamCount;

  factory StudentExamImportConfirmData.fromJson(Map<String, dynamic> json) {
    return StudentExamImportConfirmData(
      message: json['message'] as String? ?? 'Import lịch thi thành công',
      importedCount: _intValue(json['importedCount']) ?? 0,
      replacedExamCount: _intValue(json['replacedExamCount']) ?? 0,
    );
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
