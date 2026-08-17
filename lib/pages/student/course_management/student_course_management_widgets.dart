part of 'student_course_management_page.dart';

class _EmptyCourseState extends StatelessWidget {
  const _EmptyCourseState({required this.message});

  final String message;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        message,
        style: TextStyle(color: colors.textMuted, fontSize: 13),
      ),
    );
  }
}

class _ManagedCourse {
  const _ManagedCourse({
    required this.id,
    required this.semesterId,
    required this.code,
    required this.name,
    required this.credits,
    required this.semesterName,
    required this.isAutoCreatedFromScheduleImport,
    required this.needsGradeConfigWarning,
    required this.components,
    required this.attendance,
    required this.midterm,
    required this.finalGrade,
    required this.attendanceWeight,
    required this.midtermWeight,
    required this.finalWeight,
    required this.attendanceComponentName,
    required this.midtermComponentName,
    required this.finalComponentName,
    required this.backendAverage10,
    required this.backendGpa4,
  });

  final String id;
  final String semesterId;
  final String code;
  final String name;
  final int credits;
  final String semesterName;
  final bool isAutoCreatedFromScheduleImport;
  final bool needsGradeConfigWarning;
  final List<StudentGradeComponent> components;
  final double attendance;
  final double midterm;
  final double finalGrade;
  final double attendanceWeight;
  final double midtermWeight;
  final double finalWeight;
  final String attendanceComponentName;
  final String midtermComponentName;
  final String finalComponentName;
  final double? backendAverage10;
  final double? backendGpa4;

  double get averageGrade {
    if (backendAverage10 != null) {
      return backendAverage10!;
    }

    final totalWeight = attendanceWeight + midtermWeight + finalWeight;
    if (totalWeight <= 0) {
      return 0;
    }

    return ((attendance * attendanceWeight) +
            (midterm * midtermWeight) +
            (finalGrade * finalWeight)) /
        totalWeight;
  }

  double get gpa4 => backendGpa4 ?? _convert10To4(averageGrade);

  bool get hasCompletedGrade => backendGpa4 != null;

  factory _ManagedCourse.fromBackend(
    StudentCourseItem course,
    StudentGradeCourse? grade,
  ) {
    final components = grade?.components ?? const <StudentGradeComponent>[];
    final attendance = _findComponent(components, _isAttendanceComponent);
    final midterm = _findComponent(components, _isMidtermComponent);
    final finalScore = _findComponent(components, _isFinalComponent);

    return _ManagedCourse(
      id: course.id,
      semesterId: course.semesterId,
      code: course.code ?? '',
      name: course.name,
      credits: course.credits,
      semesterName: course.semesterName,
      isAutoCreatedFromScheduleImport: course.isAutoCreatedFromScheduleImport,
      needsGradeConfigWarning: course.needsGradeConfigWarning,
      components: components,
      attendance: attendance?.score ?? 0,
      midterm: midterm?.score ?? 0,
      finalGrade: finalScore?.score ?? 0,
      attendanceWeight: attendance?.weight ?? 10,
      midtermWeight: midterm?.weight ?? 30,
      finalWeight: finalScore?.weight ?? 60,
      attendanceComponentName: attendance?.name ?? 'Chuyên cần',
      midtermComponentName: midterm?.name ?? 'Giữa kỳ',
      finalComponentName: finalScore?.name ?? 'Cuối kỳ',
      backendAverage10: grade?.result.finalScore10,
      backendGpa4: grade?.result.score4,
    );
  }
}

class _CourseDraft {
  const _CourseDraft({
    required this.code,
    required this.name,
    required this.credits,
    required this.attendanceWeight,
    required this.midtermWeight,
    required this.finalWeight,
  });

  final String code;
  final String name;
  final int credits;
  final double attendanceWeight;
  final double midtermWeight;
  final double finalWeight;
}

class _CourseModalResult {
  const _CourseModalResult._({this.draft, this.deleteCourseId});

  final _CourseDraft? draft;
  final String? deleteCourseId;

  factory _CourseModalResult.save(_CourseDraft draft) {
    return _CourseModalResult._(draft: draft);
  }

  factory _CourseModalResult.delete(String courseId) {
    return _CourseModalResult._(deleteCourseId: courseId);
  }
}

class _SemesterDraft {
  const _SemesterDraft({
    required this.name,
    required this.startYear,
    required this.endYear,
  });

  final String name;
  final String startYear;
  final String endYear;
}
