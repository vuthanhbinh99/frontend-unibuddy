import 'package:flutter/material.dart';

import '../../../models/admin_models.dart';

const adminPrimary = Color(0xFF6366F1);
const adminBackground = Color(0xFFF8FAFC);
const adminSurface = Color(0xFFFFFFFF);
const adminSurfaceSoft = Color(0xFFF1F5F9);
const adminBorder = Color(0xFFE2E8F0);
const adminText = Color(0xFF0F172A);
const adminMuted = Color(0xFF64748B);
const adminDanger = Color(0xFFE11D48);
const adminSuccess = Color(0xFF059669);
const adminWarning = Color(0xFFD97706);
const adminBlue = Color(0xFF2563EB);
const adminCompactBreakpoint = 420.0;

bool adminIsCompact(BuildContext context) {
  return MediaQuery.sizeOf(context).width < adminCompactBreakpoint;
}

EdgeInsets adminPagePadding(BuildContext context) {
  final compact = adminIsCompact(context);
  final horizontal = compact ? 16.0 : 20.0;
  return EdgeInsets.fromLTRB(horizontal, 18, horizontal, 22);
}

ThemeData buildAdminLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: adminPrimary,
    brightness: Brightness.light,
  ).copyWith(primary: adminPrimary, surface: adminSurface, error: adminDanger);

  OutlineInputBorder border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
  }

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: adminBackground,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: adminSurface,
      foregroundColor: adminText,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: adminSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: adminBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: adminSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(adminBorder),
      enabledBorder: border(adminBorder),
      focusedBorder: border(adminPrimary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: adminPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: adminText,
        side: const BorderSide(color: adminBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: adminText,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}

class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: adminText,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: adminMuted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor = adminBorder,
    this.backgroundColor = adminSurface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class AdminLoading extends StatelessWidget {
  const AdminLoading({super.key});

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

class AdminErrorState extends StatelessWidget {
  const AdminErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: adminDanger, size: 34),
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

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      backgroundColor: adminSurfaceSoft,
      borderColor: adminBorder,
      child: Column(
        children: [
          Icon(icon, color: adminMuted, size: 36),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: adminMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminMetricCard extends StatelessWidget {
  const AdminMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: adminMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: adminText,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: adminMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminPill extends StatelessWidget {
  const AdminPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String formatAdminDateTime(DateTime? value) {
  if (value == null) {
    return '--';
  }
  final local = value.toLocal();
  final date =
      '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}

String adminReportStatusLabel(AdminReportStatus status) {
  return switch (status) {
    AdminReportStatus.pending => 'Chờ xử lý',
    AdminReportStatus.approved => 'Đã ẩn tài liệu',
    AdminReportStatus.rejected => 'Đã bác bỏ',
  };
}

Color adminReportStatusColor(AdminReportStatus status) {
  return switch (status) {
    AdminReportStatus.pending => adminWarning,
    AdminReportStatus.approved => adminDanger,
    AdminReportStatus.rejected => adminSuccess,
  };
}

String adminDocumentStatusLabel(AdminDocumentStatus status) {
  return switch (status) {
    AdminDocumentStatus.available => 'Khả dụng',
    AdminDocumentStatus.deleted => 'Đã ẩn/xóa',
    AdminDocumentStatus.pendingModeration => 'Chờ kiểm duyệt',
  };
}

String fileExtensionFromName(String name) {
  final parts = name.split('.');
  if (parts.length < 2) {
    return 'FILE';
  }
  return parts.last.toUpperCase();
}
