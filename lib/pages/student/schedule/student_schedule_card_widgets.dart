part of 'student_schedule_tab.dart';

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.selectedDay,
    required this.days,
    required this.onSelected,
  });

  final int selectedDay;
  final List<_DayOption> days;
  final ValueChanged<int> onSelected;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return SizedBox(
      height: 58,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = day.value == selectedDay;
          return GestureDetector(
            onTap: () => onSelected(day.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primaryStrong
                    : colors.surfaceAlt.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? colors.primaryStrong : colors.border,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: colors.primaryStrong.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  day.label,
                  style: TextStyle(
                    color: isSelected ? colors.onPrimary : colors.textMuted,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.item,
    required this.isEven,
    required this.onEdit,
    required this.onDelete,
  });

  final StudentScheduleItem item;
  final bool isEven;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: isEven
            ? const BorderRadius.only(
                topRight: Radius.circular(32),
                bottomLeft: Radius.circular(32),
                topLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              )
            : const BorderRadius.only(
                topLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8083FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF8083FF).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    item.courseCode ??
                        l10n.t('student.dashboard.schedule.courseCodeUnknown'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5F85).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFF5F85).withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5F85).withValues(alpha: 0.08),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  l10n.t(
                    'student.dashboard.schedule.periodRange',
                    arguments: {
                      'start': item.startPeriod,
                      'end': item.endPeriod,
                    },
                  ),
                  style: const TextStyle(
                    color: Color(0xFFFF809F),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<_ScheduleCardAction>(
                tooltip: l10n.t('student.dashboard.schedule.cardActions'),
                icon: Icon(Icons.more_vert, size: 20, color: colors.textMuted),
                padding: EdgeInsets.zero,
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onSelected: (action) {
                  switch (action) {
                    case _ScheduleCardAction.edit:
                      onEdit();
                      break;
                    case _ScheduleCardAction.delete:
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<_ScheduleCardAction>(
                    value: _ScheduleCardAction.edit,
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: colors.text),
                        const SizedBox(width: 10),
                        Text(
                          l10n.t('student.dashboard.schedule.edit'),
                          style: TextStyle(color: colors.text),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<_ScheduleCardAction>(
                    value: _ScheduleCardAction.delete,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Color(0xFFFF5F85),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l10n.t('student.dashboard.schedule.delete'),
                          style: const TextStyle(color: Color(0xFFFF5F85)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.courseName,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _ScheduleMeta(
                icon: Icons.room_rounded,
                text:
                    item.room ??
                    l10n.t('student.dashboard.schedule.roomUnknown'),
              ),
              _ScheduleMeta(
                icon: Icons.date_range_rounded,
                text: _formatScheduleDateRange(l10n, item),
              ),
              _ScheduleMeta(
                icon: Icons.person_outline_rounded,
                text: l10n.t('student.dashboard.schedule.teacherUnknown'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleMeta extends StatelessWidget {
  const _ScheduleMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF8083FF)),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: colors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule({required this.message});

  final String message;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 120, 16, 96),
      children: [
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});

  final String message;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline, color: Colors.amber, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ScheduleViewMode { list, week }

enum _ScheduleCardAction { edit, delete }

class _DayOption {
  const _DayOption({required this.value, required this.label});

  final int value;
  final String label;
}

List<_DayOption> _dayOptions(AppLocalizationController l10n) {
  return [
    _DayOption(value: 2, label: l10n.t('student.dashboard.schedule.day.mon')),
    _DayOption(value: 3, label: l10n.t('student.dashboard.schedule.day.tue')),
    _DayOption(value: 4, label: l10n.t('student.dashboard.schedule.day.wed')),
    _DayOption(value: 5, label: l10n.t('student.dashboard.schedule.day.thu')),
    _DayOption(value: 6, label: l10n.t('student.dashboard.schedule.day.fri')),
    _DayOption(value: 7, label: l10n.t('student.dashboard.schedule.day.sat')),
    _DayOption(value: 8, label: l10n.t('student.dashboard.schedule.day.sun')),
  ];
}

String _weekdayLabel(AppLocalizationController l10n, int dayOfWeek) {
  for (final day in _dayOptions(l10n)) {
    if (day.value == dayOfWeek) {
      return day.label;
    }
  }
  return dayOfWeek.toString();
}

int _initialDay() {
  final weekday = DateTime.now().weekday;
  final backendDay = weekday == DateTime.sunday ? 8 : weekday + 1;
  return backendDay >= 2 && backendDay <= 8 ? backendDay : 2;
}

String _emptyMessage(AppLocalizationController l10n, StudentScheduleData data) {
  if (data.items.isEmpty) {
    return data.message;
  }
  return l10n.t('student.dashboard.schedule.emptyToday');
}

DateTime _startOfWeek(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  return normalized.subtract(
    Duration(days: normalized.weekday - DateTime.monday),
  );
}

DateTime? _parseFlexibleDate(String? raw) {
  if (raw == null) {
    return null;
  }
  final value = raw.trim();
  if (value.isEmpty) {
    return null;
  }

  final iso = DateTime.tryParse(value);
  if (iso != null) {
    return DateTime(iso.year, iso.month, iso.day);
  }

  final normalized = value.replaceAll('-', '/');
  final parts = normalized.split('/');
  if (parts.length != 3) {
    return null;
  }

  final first = int.tryParse(parts[0]);
  final second = int.tryParse(parts[1]);
  final third = int.tryParse(parts[2]);
  if (first == null || second == null || third == null) {
    return null;
  }

  if (parts[0].length == 4) {
    return DateTime(first, second, third);
  }

  final year = third < 100 ? 2000 + third : third;
  return DateTime(year, second, first);
}

String _formatWeekLabel(DateTime weekStart) {
  final weekEnd = weekStart.add(const Duration(days: 6));
  final start = _formatDateShort(weekStart);
  final end = _formatDateShort(weekEnd);
  return 'TUẦN $start - $end';
}

String _formatDateShort(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _scheduleDisplayKey(StudentScheduleItem item) {
  return [
    item.courseCode ?? '',
    item.courseName,
    item.dayOfWeek.toString(),
    item.startPeriod.toString(),
    item.endPeriod.toString(),
    item.room ?? '',
    _normalizedDateKey(item.startDate),
    _normalizedDateKey(item.endDate),
  ].join('|');
}

String _scheduleCourseGroupKey(StudentScheduleItem item) {
  return [
    item.semesterName.trim().toLowerCase(),
    (item.courseCode ?? '').trim().toLowerCase(),
    item.courseName.trim().toLowerCase(),
  ].join('|');
}

String _formatScheduleDateRange(
  AppLocalizationController l10n,
  StudentScheduleItem item,
) {
  return _formatDateRangeValues(
    l10n,
    _parseFlexibleDate(item.startDate),
    _parseFlexibleDate(item.endDate),
  );
}

String _formatCourseDateRange(
  AppLocalizationController l10n,
  List<StudentScheduleItem> items,
) {
  DateTime? earliestStart;
  DateTime? latestEnd;

  for (final item in items) {
    final start = _parseFlexibleDate(item.startDate);
    if (start != null &&
        (earliestStart == null || start.isBefore(earliestStart))) {
      earliestStart = start;
    }

    final end = _parseFlexibleDate(item.endDate);
    if (end != null && (latestEnd == null || end.isAfter(latestEnd))) {
      latestEnd = end;
    }
  }

  return _formatDateRangeValues(l10n, earliestStart, latestEnd);
}

String _formatDateRangeValues(
  AppLocalizationController l10n,
  DateTime? start,
  DateTime? end,
) {
  if (start == null && end == null) {
    return l10n.tOr(
      'student.dashboard.schedule.dateUnknown',
      fallbackVi: 'Chưa có thời gian học',
      fallbackEn: 'Study dates not set yet',
    );
  }
  if (start == null) {
    return _formatDateShort(end!);
  }
  if (end == null || _isSameDate(start, end)) {
    return _formatDateShort(start);
  }
  return l10n.tOr(
    'student.dashboard.schedule.dateRange',
    fallbackVi: '{start} đến {end}',
    fallbackEn: '{start} to {end}',
    arguments: {'start': _formatDateShort(start), 'end': _formatDateShort(end)},
  );
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

int _compareScheduleItems(StudentScheduleItem a, StudentScheduleItem b) {
  final dayComparison = a.dayOfWeek.compareTo(b.dayOfWeek);
  if (dayComparison != 0) {
    return dayComparison;
  }

  final periodComparison = a.startPeriod.compareTo(b.startPeriod);
  if (periodComparison != 0) {
    return periodComparison;
  }

  return a.courseName.toLowerCase().compareTo(b.courseName.toLowerCase());
}

String _normalizedDateKey(String? raw) {
  final parsed = _parseFlexibleDate(raw);
  if (parsed == null) {
    return raw?.trim() ?? '';
  }

  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final year = parsed.year.toString().padLeft(4, '0');
  return '$year-$month-$day';
}
