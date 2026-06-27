import 'package:flutter/material.dart';

import '../../../models/system_admin_models.dart';

const systemAdminAccent = Color(0xFFD97706);
const systemAdminBackground = Color(0xFFF8FAFC);
const systemAdminSurface = Color(0xFFFFFFFF);
const systemAdminSurfaceAlt = Color(0xFFF1F5F9);
const systemAdminBorder = Color(0xFFE2E8F0);
const systemAdminText = Color(0xFF0F172A);
const systemAdminMuted = Color(0xFF64748B);
const systemAdminMutedStrong = Color(0xFF475569);
const systemAdminInfo = Color(0xFF2563EB);
const systemAdminSuccess = Color(0xFF059669);
const systemAdminDanger = Color(0xFFDC2626);
const systemAdminCritical = Color(0xFFE11D48);
const systemAdminCompactBreakpoint = 420.0;

bool systemAdminIsCompact(BuildContext context) {
  return MediaQuery.sizeOf(context).width < systemAdminCompactBreakpoint;
}

EdgeInsets systemAdminPagePadding(BuildContext context) {
  final compact = systemAdminIsCompact(context);
  final horizontal = compact ? 14.0 : 20.0;
  return EdgeInsets.fromLTRB(horizontal, compact ? 14 : 20, horizontal, 20);
}

class SystemAdminSectionTitle extends StatelessWidget {
  const SystemAdminSectionTitle({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class SystemAdminCard extends StatelessWidget {
  const SystemAdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final compact = systemAdminIsCompact(context);

    return Container(
      width: double.infinity,
      padding: compact && padding == const EdgeInsets.all(16)
          ? const EdgeInsets.all(14)
          : padding,
      decoration: BoxDecoration(
        color: systemAdminSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: systemAdminBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SystemAdminMetricCard extends StatelessWidget {
  const SystemAdminMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SystemAdminCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: systemAdminMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: systemAdminMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SystemAdminLoading extends StatelessWidget {
  const SystemAdminLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class SystemAdminEmptyState extends StatelessWidget {
  const SystemAdminEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SystemAdminCard(
      child: Column(
        children: [
          Icon(icon, color: systemAdminMuted, size: 32),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class SystemAdminErrorState extends StatelessWidget {
  const SystemAdminErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SystemAdminCard(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: systemAdminDanger, size: 32),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

String formatBytes(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }

  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }

  return '${size.toStringAsFixed(size >= 10 ? 1 : 2)} ${units[unitIndex]}';
}

String formatDateTime(DateTime? dateTime) {
  if (dateTime == null) {
    return '--';
  }

  final local = dateTime.toLocal();
  final date =
      '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}

String statusLabel(ManagedUserStatus status) {
  return switch (status) {
    ManagedUserStatus.active => 'Hoạt động',
    ManagedUserStatus.locked => 'Bị khóa',
    ManagedUserStatus.unverified => 'Chưa xác thực',
    ManagedUserStatus.passwordChangeRequired => 'Chờ đổi mật khẩu',
  };
}

Color statusColor(ManagedUserStatus status) {
  return switch (status) {
    ManagedUserStatus.active => systemAdminSuccess,
    ManagedUserStatus.locked => systemAdminDanger,
    ManagedUserStatus.unverified => systemAdminAccent,
    ManagedUserStatus.passwordChangeRequired => systemAdminInfo,
  };
}

Color levelColor(AuditLogLevel level) {
  return switch (level) {
    AuditLogLevel.info => systemAdminInfo,
    AuditLogLevel.warning => systemAdminAccent,
    AuditLogLevel.error => systemAdminDanger,
    AuditLogLevel.critical => systemAdminCritical,
  };
}
