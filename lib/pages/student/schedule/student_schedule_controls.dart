part of 'student_schedule_tab.dart';

class _ScheduleViewSwitcher extends StatelessWidget {
  const _ScheduleViewSwitcher({
    required this.selectedMode,
    required this.onChanged,
  });

  final _ScheduleViewMode selectedMode;
  final ValueChanged<_ScheduleViewMode> onChanged;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surfaceAlt.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            _ScheduleViewOption(
              icon: Icons.view_list_rounded,
              label: l10n.t('student.dashboard.schedule.viewList'),
              mode: _ScheduleViewMode.list,
              selectedMode: selectedMode,
              onChanged: onChanged,
            ),
            _ScheduleViewOption(
              icon: Icons.calendar_month_outlined,
              label: l10n.t('student.dashboard.schedule.viewWeek'),
              mode: _ScheduleViewMode.week,
              selectedMode: selectedMode,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleViewOption extends StatelessWidget {
  const _ScheduleViewOption({
    required this.icon,
    required this.label,
    required this.mode,
    required this.selectedMode,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final _ScheduleViewMode mode;
  final _ScheduleViewMode selectedMode;
  final ValueChanged<_ScheduleViewMode> onChanged;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final isSelected = mode == selectedMode;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.primaryStrong : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? colors.onPrimary : colors.textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? colors.onPrimary : colors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleSemesterBar extends StatelessWidget {
  const _ScheduleSemesterBar({
    required this.semesterOptions,
    required this.selectedSemester,
    required this.onSemesterChanged,
  });

  final List<String> semesterOptions;
  final String? selectedSemester;
  final ValueChanged<String?> onSemesterChanged;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surfaceAlt.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.school_outlined, size: 16, color: colors.textMuted),
            const SizedBox(width: 8),
            Text(
              'Học kỳ',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: selectedSemester,
                isExpanded: true,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tất cả học kỳ'),
                  ),
                  ...semesterOptions.map(
                    (semester) => DropdownMenuItem<String?>(
                      value: semester,
                      child: Text(semester, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: onSemesterChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleWeekSemesterBar extends StatelessWidget {
  const _ScheduleWeekSemesterBar({
    required this.weekLabel,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onPickWeek,
    required this.semesterOptions,
    required this.selectedSemester,
    required this.onSemesterChanged,
  });

  final String weekLabel;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final Future<void> Function() onPickWeek;
  final List<String> semesterOptions;
  final String? selectedSemester;
  final ValueChanged<String?> onSemesterChanged;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surfaceAlt.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: canGoPrevious ? onPrevious : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    weekLabel,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: canGoNext ? onNext : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Chọn tuần',
                  onPressed: onPickWeek,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                ),
                TextButton(
                  onPressed: onToday,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text(
                    'Hôm nay',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surfaceAlt.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.school_outlined, size: 16, color: colors.textMuted),
                const SizedBox(width: 8),
                Text(
                  'Học kỳ',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: selectedSemester,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: colors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tất cả học kỳ'),
                      ),
                      ...semesterOptions.map(
                        (semester) => DropdownMenuItem<String?>(
                          value: semester,
                          child: Text(
                            semester,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: onSemesterChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
