import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/local/frontend_preferences_service.dart';

enum StudentThemeMode { dark, light }

class StudentThemeController extends ChangeNotifier {
  StudentThemeController({
    StudentThemeMode initialMode = StudentThemeMode.dark,
    FrontendPreferencesService? preferences,
  }) : _mode = initialMode,
       _preferences = preferences ?? FrontendPreferencesService();

  StudentThemeMode _mode;
  final FrontendPreferencesService _preferences;
  bool _isDisposed = false;

  StudentThemeMode get mode => _mode;

  bool get isLight => _mode == StudentThemeMode.light;

  StudentThemeColors get colors =>
      isLight ? StudentThemeColors.light : StudentThemeColors.dark;

  Future<void> loadSavedMode() async {
    final savedMode = _modeFromStorageValue(
      await _preferences.readStudentThemeMode(),
    );
    if (_isDisposed || savedMode == null || savedMode == _mode) {
      return;
    }
    _mode = savedMode;
    notifyListeners();
  }

  void toggle() {
    _mode = isLight ? StudentThemeMode.dark : StudentThemeMode.light;
    notifyListeners();
    unawaited(_preferences.saveStudentThemeMode(_mode.name));
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  StudentThemeMode? _modeFromStorageValue(String? value) {
    return switch (value) {
      'dark' => StudentThemeMode.dark,
      'light' => StudentThemeMode.light,
      _ => null,
    };
  }
}

class StudentThemeScope extends InheritedNotifier<StudentThemeController> {
  const StudentThemeScope({
    super.key,
    required StudentThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static StudentThemeController controllerOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<StudentThemeScope>();
    assert(scope != null, 'StudentThemeScope was not found in context.');
    return scope!.notifier!;
  }

  static StudentThemeController? maybeControllerOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<StudentThemeScope>()
        ?.notifier;
  }

  static StudentThemeColors colorsOf(BuildContext context) {
    final controller = maybeControllerOf(context);
    if (controller != null) {
      return controller.colors;
    }
    return Theme.of(context).brightness == Brightness.light
        ? StudentThemeColors.light
        : StudentThemeColors.dark;
  }
}

class StudentThemedRoute extends StatelessWidget {
  const StudentThemedRoute({
    super.key,
    required this.controller,
    required this.child,
  });

  final StudentThemeController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StudentThemeScope(
      controller: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Theme(
            data: buildStudentMaterialTheme(controller.colors),
            child: child,
          );
        },
      ),
    );
  }
}

MaterialPageRoute<T> buildStudentThemedRoute<T>({
  required StudentThemeController controller,
  required WidgetBuilder builder,
}) {
  return MaterialPageRoute<T>(
    builder: (context) {
      return StudentThemedRoute(
        controller: controller,
        child: builder(context),
      );
    },
  );
}

MaterialPageRoute<T> studentThemedRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return buildStudentThemedRoute<T>(
    controller: StudentThemeScope.controllerOf(context),
    builder: builder,
  );
}

class StudentThemeColors {
  const StudentThemeColors({
    required this.brightness,
    required this.background,
    required this.backgroundSoft,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceMuted,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.border,
    required this.borderStrong,
    required this.primary,
    required this.primaryStrong,
    required this.primarySoft,
    required this.onPrimary,
    required this.bottomBar,
    required this.shadow,
    required this.gpaGradientStart,
    required this.gpaGradientEnd,
  });

  final Brightness brightness;
  final Color background;
  final Color backgroundSoft;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceMuted;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color border;
  final Color borderStrong;
  final Color primary;
  final Color primaryStrong;
  final Color primarySoft;
  final Color onPrimary;
  final Color bottomBar;
  final Color shadow;
  final Color gpaGradientStart;
  final Color gpaGradientEnd;

  static const dark = StudentThemeColors(
    brightness: Brightness.dark,
    background: Color(0xFF0B1326),
    backgroundSoft: Color(0xFF111A2D),
    surface: Color(0xFF131B2E),
    surfaceAlt: Color(0xFF1E293B),
    surfaceMuted: Color(0xFF2D3449),
    text: Color(0xFFDAE2FD),
    textMuted: Color(0xFFC7C4D7),
    textSubtle: Color(0xFF94A3B8),
    border: Color(0x1AFFFFFF),
    borderStrong: Color(0x2EFFFFFF),
    primary: Color(0xFFC0C1FF),
    primaryStrong: Color(0xFF8083FF),
    primarySoft: Color(0x332D49FF),
    onPrimary: Color(0xFF07006C),
    bottomBar: Color(0xFF0B1326),
    shadow: Color(0x66000000),
    gpaGradientStart: Color(0xFF312E81),
    gpaGradientEnd: Color(0xFF1E1B4B),
  );

  static const light = StudentThemeColors(
    brightness: Brightness.light,
    background: Color(0xFFF6F8FF),
    backgroundSoft: Color(0xFFEFF4FF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEAF0FF),
    surfaceMuted: Color(0xFFDDE7F6),
    text: Color(0xFF0F172A),
    textMuted: Color(0xFF334155),
    textSubtle: Color(0xFF64748B),
    border: Color(0x1F0F172A),
    borderStrong: Color(0x330F172A),
    primary: Color(0xFF4F46E5),
    primaryStrong: Color(0xFF4338CA),
    primarySoft: Color(0x1A4F46E5),
    onPrimary: Color(0xFFFFFFFF),
    bottomBar: Color(0xFFFFFFFF),
    shadow: Color(0x1F1E293B),
    gpaGradientStart: Color(0xFF4F46E5),
    gpaGradientEnd: Color(0xFF0EA5E9),
  );

  bool get isLight => brightness == Brightness.light;

  Color get success =>
      isLight ? const Color(0xFF047857) : const Color(0xFF10B981);

  Color get info => isLight ? const Color(0xFF0369A1) : const Color(0xFF89CEFF);

  Color get warning =>
      isLight ? const Color(0xFFB45309) : const Color(0xFFF59E0B);

  Color get danger =>
      isLight ? const Color(0xFFDC2626) : const Color(0xFFFFB4AB);

  Color get elevatedBorder => isLight ? borderStrong : border;

  Color onColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : const Color(0xFF0F172A);
  }

  Color tint(Color color, {double lightAlpha = 0.12, double darkAlpha = 0.16}) {
    return color.withValues(alpha: isLight ? lightAlpha : darkAlpha);
  }

  Color overlay(double alpha) {
    return (isLight ? const Color(0xFF0F172A) : Colors.white).withValues(
      alpha: alpha,
    );
  }

  Color inverseOverlay(double alpha) {
    return (isLight ? Colors.white : Colors.black).withValues(alpha: alpha);
  }

  Color elevatedSurface({double alpha = 1}) {
    return surface.withValues(alpha: alpha);
  }
}

ThemeData buildStudentMaterialTheme(StudentThemeColors colors) {
  return ThemeData(
    useMaterial3: true,
    brightness: colors.brightness,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: colors.primaryStrong,
          brightness: colors.brightness,
        ).copyWith(
          primary: colors.primaryStrong,
          onPrimary: colors.onPrimary,
          surface: colors.surface,
          onSurface: colors.text,
        ),
    scaffoldBackgroundColor: colors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.background,
      foregroundColor: colors.text,
      elevation: 0,
      centerTitle: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: colors.text,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: TextStyle(color: colors.textMuted, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceAlt.withValues(alpha: colors.isLight ? 0.75 : 1),
      labelStyle: TextStyle(color: colors.textSubtle),
      hintStyle: TextStyle(color: colors.textSubtle),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.primaryStrong, width: 1.4),
      ),
    ),
    textTheme: ThemeData(
      brightness: colors.brightness,
      fontFamily: 'Roboto',
    ).textTheme.apply(bodyColor: colors.text, displayColor: colors.text),
  );
}
