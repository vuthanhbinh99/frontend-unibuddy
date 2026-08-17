part of 'student_course_management_page.dart';

class _SemesterOverviewCard extends StatelessWidget {
  const _SemesterOverviewCard({
    required this.semesters,
    required this.selectedSemesterId,
    required this.isSaving,
    required this.onAddSemester,
    required this.onSelectSemester,
    required this.onEditSemester,
    required this.onDeleteSemester,
  });

  final List<StudentSemester> semesters;
  final String? selectedSemesterId;
  final bool isSaving;
  final VoidCallback onAddSemester;
  final ValueChanged<String> onSelectSemester;
  final ValueChanged<StudentSemester> onEditSemester;
  final ValueChanged<StudentSemester> onDeleteSemester;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final selectedSemester = semesters.isEmpty
        ? null
        : semesters.firstWhere(
            (item) => item.id == selectedSemesterId,
            orElse: () => semesters.first,
          );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Học kỳ',
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      semesters.isEmpty
                          ? 'Chưa có học kỳ nào. Thêm học kỳ trước để bắt đầu thêm môn học.'
                          : selectedSemester == null
                          ? 'Đã có ${semesters.length} học kỳ.'
                          : 'Đang dùng: ${selectedSemester.name}',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: isSaving ? null : onAddSemester,
                icon: isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Thêm học kỳ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primaryStrong,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
          if (semesters.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: semesters.map((semester) {
                final isSelected = semester.id == selectedSemesterId;
                return InkWell(
                  onTap: () => onSelectSemester(semester.id),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primaryStrong.withValues(alpha: 0.12)
                          : colors.surfaceAlt.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? colors.primaryStrong
                            : colors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              semester.name,
                              style: TextStyle(
                                color: colors.text,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: isSaving
                                  ? null
                                  : () => onEditSemester(semester),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 15,
                                  color: colors.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            InkWell(
                              onTap: isSaving
                                  ? null
                                  : () => onDeleteSemester(semester),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.delete_outline,
                                  size: 15,
                                  color: colors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _semesterDateRange(semester),
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineModalError extends StatelessWidget {
  const _InlineModalError({required this.message});

  final String message;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _semesterDateRange(StudentSemester semester) {
  final start = semester.startDate?.trim();
  final end = semester.endDate?.trim();
  if ((start == null || start.isEmpty) && (end == null || end.isEmpty)) {
    return 'Chưa có năm học';
  }
  if (start == null || start.isEmpty) {
    return 'Đến ${_yearFromSemesterValue(end)}';
  }
  if (end == null || end.isEmpty) {
    return 'Từ ${_yearFromSemesterValue(start)}';
  }
  return '${_yearFromSemesterValue(start)}-${_yearFromSemesterValue(end)}';
}

String _yearFromSemesterValue(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.length >= 4) {
    return trimmed.substring(0, 4);
  }
  return trimmed;
}

String _semesterNumberFromName(String? name) {
  final trimmed = name?.trim() ?? '';
  final match = RegExp(r'(\d+)').firstMatch(trimmed);
  return match?.group(1) ?? '';
}

StudentGradeComponent? _findComponent(
  List<StudentGradeComponent> components,

  /// Hàm hỗ trợ function cho màn hình trong file này.
  bool Function(String normalizedName) test,
) {
  for (final component in components) {
    if (test(_normalizeComponentName(component.name))) {
      return component;
    }
  }
  return null;
}

String _normalizeComponentName(String value) {
  return value.toLowerCase().trim();
}

bool _isAttendanceComponent(String value) {
  return value == 'cc' ||
      value.contains('chuyên') ||
      value.contains('chuyen') ||
      value.contains('attendance');
}

bool _isMidtermComponent(String value) {
  return value == 'gk' ||
      value.contains('giữa') ||
      value.contains('giua') ||
      value.contains('mid');
}

bool _isFinalComponent(String value) {
  return value == 'ck' ||
      value.contains('cuối') ||
      value.contains('cuoi') ||
      value.contains('final');
}

double _convert10To4(double score10) {
  if (score10 >= 8.5) {
    return 4;
  }
  if (score10 >= 8) {
    return 3.5;
  }
  if (score10 >= 7) {
    return 3;
  }
  if (score10 >= 6.5) {
    return 2.5;
  }
  if (score10 >= 5.5) {
    return 2;
  }
  if (score10 >= 5) {
    return 1.5;
  }
  if (score10 >= 4) {
    return 1;
  }
  return 0;
}
