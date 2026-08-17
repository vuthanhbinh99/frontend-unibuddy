part of 'student_course_management_page.dart';

class _GpaDashboard extends StatelessWidget {
  const _GpaDashboard({
    required this.courses,
    required this.targetGpa,
    required this.isLinearFormula,
    required this.isProjecting,
    required this.backendAdvice,
    required this.onTargetGpaChanged,
    required this.onFormulaToggle,
  });

  final List<_ManagedCourse> courses;
  final double targetGpa;
  final bool isLinearFormula;
  final bool isProjecting;
  final String? backendAdvice;
  final ValueChanged<double> onTargetGpaChanged;
  final ValueChanged<bool> onFormulaToggle;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    double totalCredits = 0;
    double completedCredits = 0;
    double completedWeighted4 = 0;
    double completedWeighted10 = 0;

    for (final course in courses) {
      totalCredits += course.credits;
      if (!course.hasCompletedGrade) {
        continue;
      }
      final avg10 = course.backendAverage10 ?? course.averageGrade;
      final avg4 = isLinearFormula ? (avg10 / 10) * 4 : course.gpa4;
      completedWeighted4 += avg4 * course.credits;
      completedWeighted10 += avg10 * course.credits;
      completedCredits += course.credits;
    }

    final remainingCredits = (totalCredits - completedCredits)
        .clamp(0, double.infinity)
        .toDouble();
    final finalGpa4 = completedCredits > 0
        ? completedWeighted4 / completedCredits
        : 0.0;
    final finalGpa10 = completedCredits > 0
        ? completedWeighted10 / completedCredits
        : 0.0;

    String honorText = 'Trung bình';
    Color honorColor = colors.textMuted;
    if (finalGpa4 >= 3.6) {
      honorText = 'Xuất sắc';
      honorColor = colors.danger;
    } else if (finalGpa4 >= 3.2) {
      honorText = 'Giỏi';
      honorColor = colors.primaryStrong;
    } else if (finalGpa4 >= 2.5) {
      honorText = 'Khá';
      honorColor = colors.info;
    }

    final requiredRemainingWeighted4 =
        targetGpa * totalCredits - completedWeighted4;
    final requiredRemainingAvg4 = remainingCredits > 0
        ? requiredRemainingWeighted4 / remainingCredits
        : 0.0;
    final maxPossibleGpa = totalCredits > 0
        ? (completedWeighted4 + remainingCredits * 4) / totalCredits
        : 0.0;
    final completedCourseCount = courses
        .where((course) => course.hasCompletedGrade && course.credits > 0)
        .length;
    final remainingCourseCount = courses
        .where((course) => !course.hasCompletedGrade && course.credits > 0)
        .length;
    final localProjectionAdvice = _buildLocalProjectionAdvice(
      targetGpa: targetGpa,
      totalCredits: totalCredits,
      completedCredits: completedCredits,
      remainingCredits: remainingCredits,
      completedCourseCount: completedCourseCount,
      remainingCourseCount: remainingCourseCount,
      requiredRemainingAvg4: requiredRemainingAvg4,
      maxPossibleGpa: maxPossibleGpa,
      useLinearScore: isLinearFormula,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.surfaceAlt.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onFormulaToggle(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isLinearFormula
                          ? colors.primaryStrong
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Tuyến tính (10/10)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isLinearFormula
                              ? colors.onPrimary
                              : colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => onFormulaToggle(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: !isLinearFormula
                          ? colors.primaryStrong
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Theo quy chế trường',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: !isLinearFormula
                              ? colors.onPrimary
                              : colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.tint(colors.primaryStrong, lightAlpha: 0.12),
                colors.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'GPA HIỆN TẠI',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: honorColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  honorText,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: honorColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          textBaseline: TextBaseline.alphabetic,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          children: [
                            Text(
                              finalGpa4.toStringAsFixed(2),
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: colors.primaryStrong,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/ 4.0',
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hệ 10: ${finalGpa10.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.info,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.tint(colors.primaryStrong),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.primaryStrong.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Icon(
                      Icons.trending_up,
                      color: colors.primaryStrong,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: colors.border),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mục tiêu học kỳ này',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted,
                    ),
                  ),
                  Text(
                    targetGpa.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: colors.primaryStrong,
                  inactiveTrackColor: colors.surfaceMuted,
                  thumbColor: colors.primaryStrong,
                  overlayColor: colors.primaryStrong.withValues(alpha: 0.2),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: targetGpa,
                  min: 0,
                  max: 4,
                  onChanged: (value) => onTargetGpaChanged(
                    double.parse(value.toStringAsFixed(2)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kéo để giả lập điểm trung bình mục tiêu',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                  if (isProjecting)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.danger,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (localProjectionAdvice != null || backendAdvice != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.tint(colors.danger, lightAlpha: 0.09),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.danger.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.school, color: colors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          backendAdvice ?? localProjectionAdvice!,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.danger,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String? _buildLocalProjectionAdvice({
  required double targetGpa,
  required double totalCredits,
  required double completedCredits,
  required double remainingCredits,
  required int completedCourseCount,
  required int remainingCourseCount,
  required double requiredRemainingAvg4,
  required double maxPossibleGpa,
  required bool useLinearScore,
}) {
  if (totalCredits <= 0) {
    return 'Thêm môn học và số tín chỉ trước khi dự phóng GPA học kỳ.';
  }

  if (remainingCredits <= 0) {
    final currentGpa = completedCredits > 0 ? maxPossibleGpa : 0.0;
    if (currentGpa + 0.005 >= targetGpa) {
      return 'Tất cả môn đã có điểm và GPA hiện tại đã đạt mục tiêu ${targetGpa.toStringAsFixed(2)}.';
    }
    return 'Tất cả môn đã có điểm nên không thể dự phóng thêm. GPA hiện tại là ${currentGpa.toStringAsFixed(2)}, thấp hơn mục tiêu ${targetGpa.toStringAsFixed(2)}.';
  }

  if (requiredRemainingAvg4 > 4) {
    return 'Mục tiêu ${targetGpa.toStringAsFixed(2)} chưa khả thi với điểm hiện tại. Nếu các môn còn lại đều đạt 4.0, GPA tối đa của học kỳ là ${maxPossibleGpa.toStringAsFixed(2)}.';
  }

  if (requiredRemainingAvg4 <= 0) {
    return 'Bạn đã chắc chắn đạt mục tiêu ${targetGpa.toStringAsFixed(2)} với các môn đã có điểm.';
  }

  final score10 = useLinearScore
      ? ' (khoảng ${(requiredRemainingAvg4 * 2.5).toStringAsFixed(1)}/10)'
      : '';
  if (completedCourseCount == 0) {
    return 'Chưa có môn nào nhập đủ điểm. Để đạt GPA ${targetGpa.toStringAsFixed(2)}, $remainingCourseCount môn / ${remainingCredits.toStringAsFixed(0)} tín chỉ cần trung bình ${requiredRemainingAvg4.toStringAsFixed(2)}/4.0$score10.';
  }

  return 'Đã có điểm $completedCourseCount môn / ${completedCredits.toStringAsFixed(0)} tín chỉ. Các môn còn lại cần trung bình ${requiredRemainingAvg4.toStringAsFixed(2)}/4.0$score10 để đạt GPA ${targetGpa.toStringAsFixed(2)}.';
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.index,
    required this.onTap,
    required this.onGradeTap,
  });

  final _ManagedCourse course;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onGradeTap;

  Color get _gradeColor {
    final avg = course.averageGrade;
    if (avg >= 8.5) {
      return const Color(0xFFFFAFD3);
    }
    if (avg >= 7) {
      return const Color(0xFFC0C1FF);
    }
    return const Color(0xFF89CEFF);
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final isOdd = (index + 1) % 2 != 0;
    final cardBorderRadius = isOdd
        ? const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(8),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(24),
          );

    return InkWell(
      onTap: onTap,
      borderRadius: cardBorderRadius,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: cardBorderRadius,
          border: Border.all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colors.border),
                          ),
                          child: Text(
                            course.code.isEmpty ? '--' : course.code,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${course.credits} tín chỉ',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.info,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    course.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                    ),
                  ),
                  if (course.needsGradeConfigWarning) ...[
                    const SizedBox(height: 8),
                    _CourseWarningChip(
                      isAutoCreatedFromScheduleImport:
                          course.isAutoCreatedFromScheduleImport,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniGradeTag(
                        label: 'CC',
                        grade: course.attendance,
                        color: const Color(0xFF10B981),
                      ),
                      _MiniGradeTag(
                        label: 'GK',
                        grade: course.midterm,
                        color: const Color(0xFF3B82F6),
                      ),
                      _MiniGradeTag(
                        label: 'CK',
                        grade: course.finalGrade,
                        color: const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  textBaseline: TextBaseline.alphabetic,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  children: [
                    Text(
                      course.averageGrade.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _gradeColor,
                      ),
                    ),
                    Text(
                      '/10',
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'ĐIỂM TỔNG KẾT',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onGradeTap,
                  icon: Icon(
                    Icons.edit_note,
                    size: 16,
                    color: colors.primaryStrong,
                  ),
                  label: Text(
                    'Nhập điểm',
                    style: TextStyle(
                      color: colors.primaryStrong,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseWarningChip extends StatelessWidget {
  const _CourseWarningChip({required this.isAutoCreatedFromScheduleImport});

  final bool isAutoCreatedFromScheduleImport;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.tint(colors.danger, lightAlpha: 0.12, darkAlpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: colors.danger),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              isAutoCreatedFromScheduleImport
                  ? 'Môn tạo từ TKB, hãy rà soát trọng số điểm'
                  : 'Môn này cần rà soát cấu hình điểm',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: colors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniGradeTag extends StatelessWidget {
  const _MiniGradeTag({
    required this.label,
    required this.grade,
    required this.color,
  });

  final String label;
  final double grade;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.tint(color, lightAlpha: 0.1, darkAlpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            grade.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
        ],
      ),
    );
  }
}
