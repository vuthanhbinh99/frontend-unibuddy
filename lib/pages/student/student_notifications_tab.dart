import 'package:flutter/material.dart';

import '../../models/student_notification_models.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/student_api_service.dart';
import 'student_theme.dart';

class StudentNotificationsTab extends StatefulWidget {
  const StudentNotificationsTab({super.key, required this.studentApi});

  final StudentApiService studentApi;

  @override
  State<StudentNotificationsTab> createState() =>
      _StudentNotificationsTabState();
}

class _StudentNotificationsTabState extends State<StudentNotificationsTab> {
  StudentNotificationStatusFilter _statusFilter =
      StudentNotificationStatusFilter.all;
  StudentNotificationCategory? _categoryFilter;
  late Future<StudentNotificationData> _future;
  List<StudentNotificationItem> _items = [];
  final Set<String> _hiddenIds = {};
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _future = _loadNotifications();
  }

  Future<StudentNotificationData> _loadNotifications() async {
    final data = await widget.studentApi.listNotifications(
      status: _statusFilter,
      category: _categoryFilter,
    );
    if (mounted) {
      setState(() {
        _items = data.items
            .where((item) => !_hiddenIds.contains(item.id))
            .toList();
      });
    }
    return data;
  }

  Future<void> _reload() async {
    final next = _loadNotifications();
    setState(() => _future = next);
    await next;
  }

  void _setStatusFilter(StudentNotificationStatusFilter value) {
    if (_statusFilter == value) {
      return;
    }
    setState(() {
      _statusFilter = value;
      _future = _loadNotifications();
    });
  }

  void _setCategoryFilter(StudentNotificationCategory? value) {
    if (_categoryFilter == value) {
      return;
    }
    setState(() {
      _categoryFilter = value;
      _future = _loadNotifications();
    });
  }

  Future<void> _markAllAsRead() async {
    final l10n = context.l10n;
    if (_markingAll || _items.isEmpty) {
      return;
    }

    setState(() {
      _markingAll = true;
      _items = _items
          .map((item) => item.copyWith(isRead: true, readAt: DateTime.now()))
          .toList();
    });

    try {
      await widget.studentApi.markAllNotificationsRead();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t('student.dashboard.notifications.readAllSuccess'),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _markingAll = false);
      }
    }
  }

  Future<void> _markAsRead(StudentNotificationItem item) async {
    if (!item.isRead) {
      setState(() {
        _items = _items
            .map(
              (current) => current.id == item.id
                  ? current.copyWith(isRead: true, readAt: DateTime.now())
                  : current,
            )
            .toList();
      });
    }

    try {
      await widget.studentApi.markNotificationRead(item.id);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _dismissNotification(StudentNotificationItem item) async {
    setState(() {
      _hiddenIds.add(item.id);
      _items = _items.where((current) => current.id != item.id).toList();
    });
    await _markAsRead(item);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: RefreshIndicator(
        onRefresh: _reload,
        color: colors.primaryStrong,
        backgroundColor: colors.surface,
        child: FutureBuilder<StudentNotificationData>(
          future: _future,
          builder: (context, snapshot) {
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting &&
                _items.isEmpty;
            final unreadCount =
                snapshot.data?.unreadCount ??
                _items.where((item) => !item.isRead).length;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    unreadCount: unreadCount,
                    isMarkingAll: _markingAll,
                    onMarkAll: _markAllAsRead,
                  ),
                  const SizedBox(height: 16),
                  _StatusSegmentedControl(
                    selected: _statusFilter,
                    onSelected: _setStatusFilter,
                  ),
                  const SizedBox(height: 16),
                  _CategoryFilter(
                    selected: _categoryFilter,
                    onSelected: _setCategoryFilter,
                  ),
                  const SizedBox(height: 20),
                  if (isLoading)
                    const _LoadingState()
                  else if (snapshot.hasError && _items.isEmpty)
                    _ErrorState(
                      message: snapshot.error is ApiException
                          ? (snapshot.error as ApiException).message
                          : l10n.t('student.dashboard.notifications.error'),
                      onRetry: _reload,
                    )
                  else if (_items.isEmpty)
                    const _EmptyState()
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _NotificationCard(
                          item: item,
                          isOdd: index.isEven,
                          onTap: () => _markAsRead(item),
                          onDismiss: () => _dismissNotification(item),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.unreadCount,
    required this.isMarkingAll,
    required this.onMarkAll,
  });

  final int unreadCount;
  final bool isMarkingAll;
  final VoidCallback onMarkAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('student.dashboard.notifications.title'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colors.text,
              ),
            ),
            if (unreadCount > 0)
              Text(
                l10n.t(
                  'student.dashboard.notifications.unreadCount',
                  arguments: {'count': unreadCount},
                ),
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        TextButton.icon(
          onPressed: isMarkingAll ? null : onMarkAll,
          icon: isMarkingAll
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF89CEFF),
                    ),
                  ),
                )
              : const Icon(Icons.done_all, size: 16, color: Color(0xFF89CEFF)),
          label: Text(
            l10n.t('student.dashboard.notifications.markAll'),
            style: TextStyle(
              color: Color(0xFF89CEFF),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusSegmentedControl extends StatelessWidget {
  const _StatusSegmentedControl({
    required this.selected,
    required this.onSelected,
  });

  final StudentNotificationStatusFilter selected;
  final ValueChanged<StudentNotificationStatusFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          _StatusPill(
            label: l10n.t('student.dashboard.notifications.all'),
            selected: selected == StudentNotificationStatusFilter.all,
            onTap: () => onSelected(StudentNotificationStatusFilter.all),
          ),
          _StatusPill(
            label: l10n.t('student.dashboard.notifications.unread'),
            selected: selected == StudentNotificationStatusFilter.unread,
            onTap: () => onSelected(StudentNotificationStatusFilter.unread),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colors.primaryStrong : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: selected ? colors.onPrimary : colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({required this.selected, required this.onSelected});

  final StudentNotificationCategory? selected;
  final ValueChanged<StudentNotificationCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    final items = <({String label, StudentNotificationCategory? value})>[
      (label: l10n.t('student.dashboard.notifications.allTypes'), value: null),
      for (final category in StudentNotificationCategory.values)
        (label: category.label, value: category),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = selected == item.value;
          return GestureDetector(
            onTap: () => onSelected(item.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF00A2E6) : colors.surfaceAlt,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF89CEFF).withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              child: Center(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? const Color(0xFF00344E)
                        : colors.textMuted,
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemCount: items.length,
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.isOdd,
    required this.onTap,
    required this.onDismiss,
  });

  final StudentNotificationItem item;
  final bool isOdd;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final style = _categoryStyle(item.category);
    final borderRadius = isOdd
        ? const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(8),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(20),
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: item.isRead
            ? colors.surface.withValues(alpha: colors.isLight ? 0.72 : 0.42)
            : colors.surface,
        borderRadius: borderRadius,
        border: Border.all(
          color: item.isRead
              ? colors.border
              : colors.primary.withValues(alpha: 0.2),
        ),
        boxShadow: item.isRead
            ? null
            : [
                BoxShadow(
                  color: colors.primaryStrong.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(style.icon, color: style.color, size: 16),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: style.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: style.color.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          item.category.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: style.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close, size: 16),
                    color: colors.textMuted.withValues(alpha: 0.62),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.content.isEmpty ? item.title : item.content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: item.isRead ? FontWeight.normal : FontWeight.w500,
                  color: item.isRead
                      ? colors.text.withValues(alpha: 0.72)
                      : colors.text,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.timeAgo,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textMuted.withValues(alpha: 0.72),
                    ),
                  ),
                  if (!item.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFC0C1FF),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return SizedBox(
      height: 220,
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(colors.primaryStrong),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 48,
            color: colors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.t('student.dashboard.notifications.empty'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: colors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 42,
            color: Color(0xFFFFB4AB),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.t('common.retry')),
          ),
        ],
      ),
    );
  }
}

class _NotificationCategoryStyle {
  const _NotificationCategoryStyle({
    required this.color,
    required this.background,
    required this.icon,
  });

  final Color color;
  final Color background;
  final IconData icon;
}

_NotificationCategoryStyle _categoryStyle(
  StudentNotificationCategory category,
) {
  switch (category) {
    case StudentNotificationCategory.deadline:
      return _NotificationCategoryStyle(
        color: const Color(0xFFFFB4AB),
        background: const Color(0xFF690005).withValues(alpha: 0.3),
        icon: Icons.alarm,
      );
    case StudentNotificationCategory.group:
      return _NotificationCategoryStyle(
        color: const Color(0xFF89CEFF),
        background: const Color(0xFF00344D).withValues(alpha: 0.3),
        icon: Icons.group,
      );
    case StudentNotificationCategory.system:
      return _NotificationCategoryStyle(
        color: const Color(0xFFFFAFD3),
        background: const Color(0xFF620040).withValues(alpha: 0.3),
        icon: Icons.settings,
      );
  }
}
