import 'package:flutter/material.dart';
import '../../../models/student_deadline_models.dart';
import '../../../models/student_schedule_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api/modules/student/student_api_service.dart';
import '../theme/student_theme.dart';
import '../widgets/student_notification_dropdown.dart';
part 'student_schedule_controls.dart';
part 'student_schedule_list_widgets.dart';
part 'student_schedule_card_widgets.dart';

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
