class StudentGradeComponent {
  const StudentGradeComponent({
    required this.id,
    required this.courseId,
    required this.name,
    required this.weight,
    required this.score,
  });

  final String id;
  final String courseId;
  final String name;
  final double weight;
  final double? score;

  factory StudentGradeComponent.fromJson(Map<String, dynamic> json) {
    return StudentGradeComponent(
      id: json['maThanhPhan'].toString(),
      courseId: json['maMonHoc'] as String? ?? '',
      name: json['tenThanhPhan'] as String? ?? '--',
      weight: (json['trongSo'] as num?)?.toDouble() ?? 0,
      score: (json['diem'] as num?)?.toDouble(),
    );
  }
}

class StudentGradeWeightInput {
  const StudentGradeWeightInput({
    required this.name,
    required this.weight,
    required this.score,
  });

  final String name;
  final double weight;
  final double? score;

  Map<String, Object?> toJson() {
    return {'tenThanhPhan': name, 'trongSo': weight, 'diem': score};
  }
}

class StudentGradeResult {
  const StudentGradeResult({
    required this.totalWeight,
    required this.hasFullWeight,
    required this.hasAllScores,
    required this.finalScore10,
    required this.letterGrade,
    required this.score4,
  });

  final double totalWeight;
  final bool hasFullWeight;
  final bool hasAllScores;
  final double? finalScore10;
  final String? letterGrade;
  final double? score4;

  factory StudentGradeResult.fromJson(Map<String, dynamic>? json) {
    return StudentGradeResult(
      totalWeight: (json?['tongTrongSo'] as num?)?.toDouble() ?? 0,
      hasFullWeight: json?['duTrongSo'] as bool? ?? false,
      hasAllScores: json?['dayDuDiem'] as bool? ?? false,
      finalScore10: (json?['diemTongKetHe10'] as num?)?.toDouble(),
      letterGrade: json?['diemChu'] as String?,
      score4: (json?['diemHe4'] as num?)?.toDouble(),
    );
  }
}

class StudentGradeCourse {
  const StudentGradeCourse({
    required this.id,
    required this.semesterId,
    required this.code,
    required this.name,
    required this.credits,
    required this.semesterName,
    required this.components,
    required this.result,
  });

  final String id;
  final String semesterId;
  final String? code;
  final String name;
  final int credits;
  final String semesterName;
  final List<StudentGradeComponent> components;
  final StudentGradeResult result;

  factory StudentGradeCourse.fromJson(Map<String, dynamic> json) {
    final rawComponents = (json['thanhPhan'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();

    return StudentGradeCourse(
      id: json['maMonHoc'] as String,
      semesterId: json['maHocKy'] as String,
      code: json['maMon'] as String?,
      name: json['tenMon'] as String? ?? '--',
      credits: (json['soTinChi'] as num?)?.toInt() ?? 0,
      semesterName: json['tenHocKy'] as String? ?? '--',
      components: rawComponents.map(StudentGradeComponent.fromJson).toList(),
      result: StudentGradeResult.fromJson(
        json['ketQua'] as Map<String, dynamic>?,
      ),
    );
  }
}

class StudentGpaProjectionSuggestion {
  const StudentGpaProjectionSuggestion({
    required this.courseId,
    required this.courseName,
    required this.credits,
    required this.requiredScore,
    required this.status,
    required this.isFeasible,
  });

  final String courseId;
  final String courseName;
  final int credits;
  final double requiredScore;
  final String status;
  final bool isFeasible;

  factory StudentGpaProjectionSuggestion.fromJson(Map<String, dynamic> json) {
    return StudentGpaProjectionSuggestion(
      courseId: json['maMonHoc'] as String? ?? '',
      courseName: json['tenMon'] as String? ?? '--',
      credits: (json['soTinChi'] as num?)?.toInt() ?? 0,
      requiredScore:
          (json['diemThanhPhanCanDat'] as num?)?.toDouble() ??
          (json['diemHe10ToiThieu'] as num?)?.toDouble() ??
          0,
      status: json['trangThai'] as String? ?? '--',
      isFeasible: json['khaThi'] as bool? ?? true,
    );
  }
}

class StudentGpaProjectionData {
  const StudentGpaProjectionData({
    required this.message,
    required this.targetGpa,
    required this.currentGpa,
    required this.maxPossibleGpa,
    required this.requiredGpaPerCredit,
    required this.minimumScore10,
    required this.expectedLetter,
    required this.suggestions,
  });

  final String message;
  final double targetGpa;
  final double? currentGpa;
  final double? maxPossibleGpa;
  final double? requiredGpaPerCredit;
  final double? minimumScore10;
  final String? expectedLetter;
  final List<StudentGpaProjectionSuggestion> suggestions;

  factory StudentGpaProjectionData.fromJson(Object? data) {
    final map = data as Map<String, dynamic>;
    final rawSuggestions = (map['goiY'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();

    return StudentGpaProjectionData(
      message: map['message'] as String? ?? 'Đã tính dự phóng GPA.',
      targetGpa: (map['targetGpa'] as num?)?.toDouble() ?? 0,
      currentGpa: (map['gpaHienTai'] as num?)?.toDouble(),
      maxPossibleGpa: (map['gpaToiDaCoTheDat'] as num?)?.toDouble(),
      requiredGpaPerCredit: (map['diemHe4CanDatMoiTinChi'] as num?)?.toDouble(),
      minimumScore10: (map['diemHe10ToiThieu'] as num?)?.toDouble(),
      expectedLetter: map['diemChuDuKien'] as String?,
      suggestions: rawSuggestions
          .map(StudentGpaProjectionSuggestion.fromJson)
          .toList(),
    );
  }
}

class StudentGradeSummary {
  const StudentGradeSummary({
    required this.calculatedCredits,
    required this.remainingCredits,
    required this.semesterGpa,
    required this.cumulativeGpa,
    required this.academicStanding,
  });

  final int calculatedCredits;
  final int remainingCredits;
  final double? semesterGpa;
  final double? cumulativeGpa;
  final String? academicStanding;

  factory StudentGradeSummary.fromJson(Map<String, dynamic>? json) {
    return StudentGradeSummary(
      calculatedCredits: (json?['soTinChiDaTinh'] as num?)?.toInt() ?? 0,
      remainingCredits: (json?['soTinChiConLai'] as num?)?.toInt() ?? 0,
      semesterGpa: (json?['gpaHocKy'] as num?)?.toDouble(),
      cumulativeGpa: (json?['gpaTichLuy'] as num?)?.toDouble(),
      academicStanding: json?['xepLoaiHocLuc'] as String?,
    );
  }
}

class StudentGradeTranscriptData {
  const StudentGradeTranscriptData({
    required this.message,
    required this.totalCourses,
    required this.items,
    required this.summary,
  });

  final String message;
  final int totalCourses;
  final List<StudentGradeCourse> items;
  final StudentGradeSummary summary;

  factory StudentGradeTranscriptData.empty([String? message]) {
    return StudentGradeTranscriptData(
      message: message ?? 'Bạn chưa có điểm số nào.',
      totalCourses: 0,
      items: const [],
      summary: const StudentGradeSummary(
        calculatedCredits: 0,
        remainingCredits: 0,
        semesterGpa: null,
        cumulativeGpa: null,
        academicStanding: null,
      ),
    );
  }

  factory StudentGradeTranscriptData.fromJson(Object? data) {
    final map = data as Map<String, dynamic>;
    final rawItems = (map['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return StudentGradeTranscriptData(
      message: map['message'] as String? ?? 'Tải bảng điểm thành công',
      totalCourses: (map['totalCourses'] as num?)?.toInt() ?? rawItems.length,
      items: rawItems.map(StudentGradeCourse.fromJson).toList(),
      summary: StudentGradeSummary.fromJson(
        map['tongKet'] as Map<String, dynamic>?,
      ),
    );
  }
}
