import 'package:flutter/material.dart';

import '../../models/student_deadline_models.dart';
import '../../models/student_schedule_models.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api/modules/student_api_service.dart';
import 'student_theme.dart';
import 'widgets/student_notification_dropdown.dart';

class StudentScheduleTab extends StatefulWidget {
  const StudentScheduleTab({
    super.key,
    required this.data,
    required this.deadlines,
    required this.onRefresh,
    required this.onToggleDeadline,
    required this.onImportSchedule,
    required this.onAddScheduleManually,
    required this.onEditSchedule,
    required this.onDeleteSchedule,
    required this.studentApi,
    required this.onViewAllNotifications,
    this.isImportingSchedule = false,
    this.isSavingManualSchedule = false,
    this.preferredSemesterName,
    this.semesterOptions = const [],
    this.onSemesterChanged,
  });

  final StudentScheduleData data;
  final StudentDeadlineData deadlines;
  final Future<void> Function() onRefresh;
  final Future<void> Function(StudentDeadlineItem item) onToggleDeadline;
  final Future<void> Function() onImportSchedule;
  final Future<void> Function() onAddScheduleManually;
  final Future<void> Function(StudentScheduleItem item) onEditSchedule;
  final Future<void> Function(StudentScheduleItem item) onDeleteSchedule;
  final StudentApiService studentApi;
  final VoidCallback onViewAllNotifications;
  final bool isImportingSchedule;
  final bool isSavingManualSchedule;
  final String? preferredSemesterName;
  final List<String> semesterOptions;
  final ValueChanged<String?>? onSemesterChanged;

  @override
  State<StudentScheduleTab> createState() => _StudentScheduleTabState();
}

class _StudentScheduleTabState extends State<StudentScheduleTab> {
  late int _selectedDay;
  _ScheduleViewMode _viewMode = _ScheduleViewMode.list;
  DateTime? _selectedWeekStart;
  String? _selectedSemester;

  Future<void> _runScheduleAction(
    Future<void> Function() action,
    String fallbackMessage,
  ) async {
    try {
      await action();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(fallbackMessage)));
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _initialDay();
    _selectedWeekStart = _startOfWeek(DateTime.now());
    _selectedSemester = _normalizeSemesterName(widget.preferredSemesterName);
  }

  @override
  void didUpdateWidget(covariant StudentScheduleTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPreferred = _normalizeSemesterName(widget.preferredSemesterName);
    final previousPreferred = _normalizeSemesterName(
      oldWidget.preferredSemesterName,
    );

    if (nextPreferred != previousPreferred) {
      _selectedSemester = nextPreferred;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    final selectedWeekStart =
        _selectedWeekStart ?? _startOfWeek(DateTime.now());
    final weekOptions = _buildWeekOptions(widget.data.items);
    final resolvedWeekStart = weekOptions.contains(selectedWeekStart)
        ? selectedWeekStart
        : _startOfWeek(DateTime.now());
    final semesters = _semesterOptions(widget.data.items);
    final resolvedSemester = _resolveSemesterSelection(semesters);
    final currentWeekIndex = weekOptions.indexOf(resolvedWeekStart);
    final listSeenKeys = <String>{};

    final listItems = widget.data.items.where((item) {
      if (resolvedSemester != null &&
          item.semesterName.trim() != resolvedSemester) {
        return false;
      }
      return listSeenKeys.add(_scheduleDisplayKey(item));
    }).toList()..sort(_compareScheduleItems);

    final weekSeenKeys = <String>{};
    final weekItems = widget.data.items.where((item) {
      if (item.dayOfWeek != _selectedDay) {
        return false;
      }
      if (resolvedSemester != null &&
          item.semesterName.trim() != resolvedSemester) {
        return false;
      }
      if (!_belongsToWeek(item, resolvedWeekStart)) {
        return false;
      }

      return weekSeenKeys.add(_scheduleDisplayKey(item));
    }).toList()..sort(_compareScheduleItems);
    final days = _dayOptions(l10n);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          l10n.t('student.dashboard.schedule.title'),
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
        backgroundColor: colors.background,
        elevation: 0,
        actions: [
          StudentNotificationBell(
            studentApi: widget.studentApi,
            onViewAll: widget.onViewAllNotifications,
            margin: const EdgeInsets.only(right: 2, top: 8, bottom: 8),
          ),
          IconButton(
            icon: widget.isImportingSchedule
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.primaryStrong,
                      ),
                    ),
                  )
                : Icon(Icons.auto_awesome, color: colors.primaryStrong),
            tooltip: l10n.t('student.dashboard.schedule.autoImport'),
            onPressed: widget.isImportingSchedule
                ? null
                : () => _runScheduleAction(
                    widget.onImportSchedule,
                    l10n.t('student.dashboard.schedule.importError'),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.t('student.dashboard.schedule.manualAdd'),
        backgroundColor: colors.primaryStrong,
        onPressed: widget.isSavingManualSchedule
            ? null
            : () => _runScheduleAction(
                widget.onAddScheduleManually,
                l10n.t('student.dashboard.schedule.manualError'),
              ),
        child: widget.isSavingManualSchedule
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.onPrimary),
                ),
              )
            : Icon(Icons.add, color: colors.onPrimary, size: 28),
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: colors.primaryStrong,
        backgroundColor: colors.surface,
        child: Column(
          children: [
            _ScheduleViewSwitcher(
              selectedMode: _viewMode,
              onChanged: (mode) {
                setState(() {
                  _viewMode = mode;
                });
              },
            ),
            if (_viewMode == _ScheduleViewMode.week) ...[
              _ScheduleWeekSemesterBar(
                weekLabel: _formatWeekLabel(resolvedWeekStart),
                canGoPrevious: currentWeekIndex > 0,
                canGoNext:
                    currentWeekIndex >= 0 &&
                    currentWeekIndex < weekOptions.length - 1,
                onPrevious: () {
                  final currentIndex = weekOptions.indexOf(resolvedWeekStart);
                  if (currentIndex > 0) {
                    setState(() {
                      _selectedWeekStart = weekOptions[currentIndex - 1];
                    });
                  }
                },
                onNext: () {
                  final currentIndex = weekOptions.indexOf(resolvedWeekStart);
                  if (currentIndex >= 0 &&
                      currentIndex < weekOptions.length - 1) {
                    setState(() {
                      _selectedWeekStart = weekOptions[currentIndex + 1];
                    });
                  }
                },
                onToday: () {
                  setState(() {
                    _selectedWeekStart = _startOfWeek(DateTime.now());
                  });
                },
                onPickWeek: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: resolvedWeekStart,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate == null || !mounted) {
                    return;
                  }
                  setState(() {
                    _selectedWeekStart = _startOfWeek(pickedDate);
                  });
                },
                semesterOptions: semesters,
                selectedSemester: resolvedSemester,
                onSemesterChanged: (next) {
                  setState(() {
                    _selectedSemester = next;
                  });
                  widget.onSemesterChanged?.call(next);
                },
              ),
              _DaySelector(
                selectedDay: _selectedDay,
                days: days,
                onSelected: (day) => setState(() => _selectedDay = day),
              ),
            ] else
              _ScheduleSemesterBar(
                semesterOptions: semesters,
                selectedSemester: resolvedSemester,
                onSemesterChanged: (next) {
                  setState(() {
                    _selectedSemester = next;
                  });
                  widget.onSemesterChanged?.call(next);
                },
              ),
            if (widget.data.warning != null &&
                widget.data.warning!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _WarningBanner(message: widget.data.warning!),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: widget.isImportingSchedule
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.primaryStrong,
                        ),
                      ),
                    )
                  : _viewMode == _ScheduleViewMode.list
                  ? _ScheduleListView(
                      items: listItems,
                      data: widget.data,
                      onEdit: (item) => _runScheduleAction(
                        () => widget.onEditSchedule(item),
                        l10n.t('student.dashboard.schedule.editError'),
                      ),
                      onDelete: (item) => _runScheduleAction(
                        () => widget.onDeleteSchedule(item),
                        l10n.t('student.dashboard.schedule.deleteError'),
                      ),
                    )
                  : weekItems.isEmpty
                  ? _EmptySchedule(message: _emptyMessage(l10n, widget.data))
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      itemCount: weekItems.length,
                      itemBuilder: (context, index) {
                        return _ScheduleCard(
                          item: weekItems[index],
                          isEven: index.isEven,
                          onEdit: () => _runScheduleAction(
                            () => widget.onEditSchedule(weekItems[index]),
                            l10n.t('student.dashboard.schedule.editError'),
                          ),
                          onDelete: () => _runScheduleAction(
                            () => widget.onDeleteSchedule(weekItems[index]),
                            l10n.t('student.dashboard.schedule.deleteError'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String? _resolveSemesterSelection(List<String> semesters) {
    if (_selectedSemester != null && semesters.contains(_selectedSemester)) {
      return _selectedSemester;
    }

    final preferredSemester = _normalizeSemesterName(
      widget.preferredSemesterName,
    );
    if (preferredSemester != null && semesters.contains(preferredSemester)) {
      return preferredSemester;
    }

    return null;
  }

  List<String> _semesterOptions(List<StudentScheduleItem> items) {
    final raw = <String>{
      ...widget.semesterOptions.map((name) => name.trim()),
      ...items.map((item) => item.semesterName.trim()),
    }.where((name) => name.isNotEmpty && name != '--').toList();
    raw.sort();
    return raw;
  }

  String? _normalizeSemesterName(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty || normalized == '--') {
      return null;
    }
    return normalized;
  }

  List<DateTime> _buildWeekOptions(List<StudentScheduleItem> items) {
    final weekStarts = <DateTime>{_startOfWeek(DateTime.now())};

    for (final item in items) {
      final start = _parseFlexibleDate(item.startDate);
      final end = _parseFlexibleDate(item.endDate);

      if (start == null || end == null) {
        continue;
      }

      var cursor = _startOfWeek(start);
      final limit = _startOfWeek(end);
      var guard = 0;
      while (!cursor.isAfter(limit) && guard < 120) {
        weekStarts.add(cursor);
        cursor = cursor.add(const Duration(days: 7));
        guard += 1;
      }
    }

    final sorted = weekStarts.toList()..sort();
    return sorted;
  }

  bool _belongsToWeek(StudentScheduleItem item, DateTime weekStart) {
    final itemStart = _parseFlexibleDate(item.startDate);
    final itemEnd = _parseFlexibleDate(item.endDate);
    if (itemStart == null || itemEnd == null) {
      return false;
    }

    final normalizedStart = itemStart;
    final normalizedEnd = itemEnd;
    final weekEnd = weekStart.add(const Duration(days: 6));

    return !normalizedEnd.isBefore(weekStart) &&
        !normalizedStart.isAfter(weekEnd);
  }
}

class _ScheduleViewSwitcher extends StatelessWidget {
  const _ScheduleViewSwitcher({
    required this.selectedMode,
    required this.onChanged,
  });

  final _ScheduleViewMode selectedMode;
  final ValueChanged<_ScheduleViewMode> onChanged;

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

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.selectedDay,
    required this.days,
    required this.onSelected,
  });

  final int selectedDay;
  final List<_DayOption> days;
  final ValueChanged<int> onSelected;

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
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: colors.text,
                        ),
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
    arguments: {
      'start': _formatDateShort(start),
      'end': _formatDateShort(end),
    },
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
