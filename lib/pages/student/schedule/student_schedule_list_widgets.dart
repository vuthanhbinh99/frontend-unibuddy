part of 'student_schedule_tab.dart';

class _ScheduleListView extends StatelessWidget {
  const _ScheduleListView({
    required this.items,
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  final List<StudentScheduleItem> items;
  final StudentScheduleData data;
  final ValueChanged<StudentScheduleItem> onEdit;
  final ValueChanged<StudentScheduleItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (items.isEmpty) {
      return _EmptySchedule(
        message: data.items.isEmpty
            ? data.message
            : l10n.t('student.dashboard.schedule.emptyList'),
      );
    }

    final grouped = <String, List<StudentScheduleItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(_scheduleCourseGroupKey(item), () => []).add(item);
    }
    final groups = grouped.values.toList()
      ..sort((a, b) => _compareScheduleItems(a.first, b.first));

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 96),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final groupItems = groups[index]..sort(_compareScheduleItems);
        return _ScheduleCourseGroup(
          items: groupItems,
          isEven: index.isEven,
          onEdit: onEdit,
          onDelete: onDelete,
        );
      },
    );
  }
}

class _ScheduleCourseGroup extends StatelessWidget {
  const _ScheduleCourseGroup({
    required this.items,
    required this.isEven,
    required this.onEdit,
    required this.onDelete,
  });

  final List<StudentScheduleItem> items;
  final bool isEven;
  final ValueChanged<StudentScheduleItem> onEdit;
  final ValueChanged<StudentScheduleItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final l10n = context.l10n;
    final firstItem = items.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: isEven
            ? const BorderRadius.only(
                topRight: Radius.circular(28),
                bottomLeft: Radius.circular(28),
                topLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              )
            : const BorderRadius.only(
                topLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _ScheduleCompactBadge(
                          label:
                              firstItem.courseCode ??
                              l10n.t(
                                'student.dashboard.schedule.courseCodeUnknown',
                              ),
                          color: colors.primary,
                        ),
                        _ScheduleCompactBadge(
                          label: firstItem.semesterName,
                          color: colors.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      firstItem.courseName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ScheduleMeta(
            icon: Icons.date_range_rounded,
            text: _formatCourseDateRange(l10n, items),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => _ScheduleCourseGroupSession(
              item: item,
              onEdit: () => onEdit(item),
              onDelete: () => onDelete(item),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCourseGroupSession extends StatelessWidget {
  const _ScheduleCourseGroupSession({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final StudentScheduleItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceAlt.withValues(alpha: colors.isLight ? 0.65 : 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ScheduleMeta(
                  icon: Icons.calendar_today_rounded,
                  text: _weekdayLabel(l10n, item.dayOfWeek),
                ),
                _ScheduleMeta(
                  icon: Icons.schedule_rounded,
                  text: l10n.t(
                    'student.dashboard.schedule.periodRange',
                    arguments: {
                      'start': item.startPeriod,
                      'end': item.endPeriod,
                    },
                  ),
                ),
                _ScheduleMeta(
                  icon: Icons.room_rounded,
                  text:
                      item.room ??
                      l10n.t('student.dashboard.schedule.roomUnknown'),
                ),
              ],
            ),
          ),
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
    );
  }
}

class _ScheduleCompactBadge extends StatelessWidget {
  const _ScheduleCompactBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.isLight ? color : colors.text,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}
