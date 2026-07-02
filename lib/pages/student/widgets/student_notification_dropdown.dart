import 'package:flutter/material.dart';

import '../../../models/student_notification_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api/api_exception.dart';
import '../../../services/api/modules/student_api_service.dart';
import '../student_theme.dart';

class StudentNotificationBell extends StatelessWidget {
  const StudentNotificationBell({
    super.key,
    required this.studentApi,
    this.onViewAll,
    this.size = 40,
    this.icon = Icons.notifications_none,
    this.iconColor = const Color(0xFF94A3B8),
    this.backgroundColor = const Color(0xFF171F33),
    this.borderColor,
    this.dotColor = const Color(0xFF6366F1),
    this.margin = EdgeInsets.zero,
  });

  final StudentApiService studentApi;
  final VoidCallback? onViewAll;
  final double size;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color? borderColor;
  final Color dotColor;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    final resolvedIconColor = iconColor == const Color(0xFF94A3B8)
        ? colors.textSubtle
        : iconColor;
    final resolvedBackground = backgroundColor == const Color(0xFF171F33)
        ? colors.surface
        : backgroundColor;
    final resolvedBorder = borderColor ?? colors.border;
    return Container(
      width: size,
      height: size,
      margin: margin,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: resolvedBackground,
              shape: BoxShape.circle,
              border: Border.all(color: resolvedBorder),
            ),
            child: IconButton(
              tooltip: l10n.t('student.dashboard.notifications.bellTooltip'),
              icon: Icon(icon, size: 18, color: resolvedIconColor),
              onPressed: () {
                showStudentNotificationDropdown(
                  context: context,
                  studentApi: studentApi,
                  onViewAll: onViewAll,
                );
              },
            ),
          ),
          Positioned(
            right: 5,
            top: 5,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showStudentNotificationDropdown({
  required BuildContext context,
  required StudentApiService studentApi,
  VoidCallback? onViewAll,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.t('student.dashboard.notifications.close'),
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.transparent,
            child: _NotificationDropdownPanel(
              studentApi: studentApi,
              onViewAll: onViewAll == null
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                      onViewAll();
                    },
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _NotificationDropdownPanel extends StatefulWidget {
  const _NotificationDropdownPanel({required this.studentApi, this.onViewAll});

  final StudentApiService studentApi;
  final VoidCallback? onViewAll;

  @override
  State<_NotificationDropdownPanel> createState() =>
      _NotificationDropdownPanelState();
}

class _NotificationDropdownPanelState
    extends State<_NotificationDropdownPanel> {
  late Future<StudentNotificationData> _future;
  List<StudentNotificationItem> _items = [];
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<StudentNotificationData> _load() async {
    final data = await widget.studentApi.listNotifications(limit: 6);
    if (mounted) {
      setState(() => _items = data.items);
    }
    return data;
  }

  Future<void> _retry() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _markAllAsRead() async {
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
    } catch (_) {
      // Keep the optimistic UI state; backend may not have a read column yet.
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final colors = StudentThemeScope.colorsOf(context);

    return Container(
      width: screen.width > 440 ? 420 : screen.width - 28,
      constraints: BoxConstraints(maxHeight: screen.height * 0.72),
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: FutureBuilder<StudentNotificationData>(
          future: _future,
          builder: (context, snapshot) {
            final unreadCount =
                snapshot.data?.unreadCount ??
                _items.where((item) => !item.isRead).length;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DropdownHeader(
                  unreadCount: unreadCount,
                  markingAll: _markingAll,
                  onMarkAll: _markAllAsRead,
                  onClose: () => Navigator.of(context).pop(),
                ),
                Flexible(child: _buildContent(snapshot)),
                if (widget.onViewAll != null)
                  _ViewAllButton(onPressed: widget.onViewAll!),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(AsyncSnapshot<StudentNotificationData> snapshot) {
    final l10n = context.l10n;
    if (snapshot.connectionState == ConnectionState.waiting && _items.isEmpty) {
      final colors = StudentThemeScope.colorsOf(context);
      return SizedBox(
        height: 190,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          ),
        ),
      );
    }

    if (snapshot.hasError && _items.isEmpty) {
      final message = snapshot.error is ApiException
          ? (snapshot.error as ApiException).message
          : l10n.t('student.dashboard.notifications.dropdownError');
      return _DropdownError(message: message, onRetry: _retry);
    }

    if (_items.isEmpty) {
      return const _DropdownEmpty();
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: _items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _DropdownNotificationItem(
          item: item,
          onTap: () => _markAsRead(item),
        );
      },
    );
  }
}

class _DropdownHeader extends StatelessWidget {
  const _DropdownHeader({
    required this.unreadCount,
    required this.markingAll,
    required this.onMarkAll,
    required this.onClose,
  });

  final int unreadCount;
  final bool markingAll;
  final VoidCallback onMarkAll;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: colors.primaryStrong,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('student.dashboard.notifications.title'),
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  unreadCount > 0
                      ? l10n.t(
                          'student.dashboard.notifications.unreadCount',
                          arguments: {'count': unreadCount},
                        )
                      : l10n.t('student.dashboard.notifications.allRead'),
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: markingAll ? null : onMarkAll,
            child: markingAll
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    l10n.t('student.dashboard.notifications.markAll'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          IconButton(
            tooltip: l10n.t('student.dashboard.notifications.close'),
            onPressed: onClose,
            icon: Icon(Icons.close, size: 18, color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DropdownNotificationItem extends StatelessWidget {
  const _DropdownNotificationItem({required this.item, required this.onTap});

  final StudentNotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final style = _categoryStyle(item.category);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item.isRead
              ? colors.surfaceAlt.withValues(alpha: colors.isLight ? 0.55 : 0.5)
              : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: item.isRead
                ? colors.border
                : style.color.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: style.background,
                shape: BoxShape.circle,
              ),
              child: Icon(style.icon, color: style.color, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: item.isRead
                                ? colors.text.withValues(alpha: 0.72)
                                : colors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.timeAgo,
                        style: TextStyle(
                          color: colors.textMuted.withValues(alpha: 0.62),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textMuted.withValues(
                        alpha: item.isRead ? 0.58 : 0.9,
                      ),
                      height: 1.3,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFC0C1FF),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ViewAllButton extends StatelessWidget {
  const _ViewAllButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primaryStrong,
          side: BorderSide(color: colors.primaryStrong.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(l10n.t('student.dashboard.notifications.viewAll')),
      ),
    );
  }
}

class _DropdownEmpty extends StatelessWidget {
  const _DropdownEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              color: colors.textMuted,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.t('student.dashboard.notifications.empty'),
              style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownError extends StatelessWidget {
  const _DropdownError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    return SizedBox(
      height: 190,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFFFFB4AB),
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.text, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(l10n.t('common.retry')),
              ),
            ],
          ),
        ),
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
