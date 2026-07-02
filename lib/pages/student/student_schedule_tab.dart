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
    required this.studentApi,
    required this.onViewAllNotifications,
    this.isImportingSchedule = false,
    this.isSavingManualSchedule = false,
  });

  final StudentScheduleData data;
  final StudentDeadlineData deadlines;
  final Future<void> Function() onRefresh;
  final Future<void> Function(StudentDeadlineItem item) onToggleDeadline;
  final Future<void> Function() onImportSchedule;
  final Future<void> Function() onAddScheduleManually;
  final StudentApiService studentApi;
  final VoidCallback onViewAllNotifications;
  final bool isImportingSchedule;
  final bool isSavingManualSchedule;

  @override
  State<StudentScheduleTab> createState() => _StudentScheduleTabState();
}

class _StudentScheduleTabState extends State<StudentScheduleTab> {
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _initialDay();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    final filtered = widget.data.items
        .where((item) => item.dayOfWeek == _selectedDay)
        .toList();
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
                : widget.onImportSchedule,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.t('student.dashboard.schedule.manualAdd'),
        backgroundColor: colors.primaryStrong,
        onPressed: widget.isSavingManualSchedule
            ? null
            : widget.onAddScheduleManually,
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
            _DaySelector(
              selectedDay: _selectedDay,
              days: days,
              onSelected: (day) => setState(() => _selectedDay = day),
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
                  : filtered.isEmpty
                  ? _EmptySchedule(message: _emptyMessage(l10n, widget.data))
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return _ScheduleCard(
                          item: filtered[index],
                          isEven: index.isEven,
                        );
                      },
                    ),
            ),
          ],
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
  const _ScheduleCard({required this.item, required this.isEven});

  final StudentScheduleItem item;
  final bool isEven;

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
