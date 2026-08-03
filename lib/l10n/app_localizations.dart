import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/local/frontend_preferences_service.dart';

class AppLocalizationController extends ChangeNotifier {
  AppLocalizationController({required FrontendPreferencesService preferences})
    : _preferences = preferences;

  static const supportedLanguageCodes = ['vi', 'en'];
  static const defaultLanguageCode = 'vi';

  final FrontendPreferencesService _preferences;
  final Map<String, Map<String, String>> _bundles = {};

  bool _loaded = false;
  String _languageCode = defaultLanguageCode;

  bool get isLoaded => _loaded;
  String get languageCode => _languageCode;
  Locale get locale => Locale(_languageCode);

  Future<void> load() async {
    if (_loaded) {
      return;
    }

    final savedLanguageCode = await _preferences.readStudentLanguageCode();
    _languageCode = _normalizeLanguageCode(savedLanguageCode);
    try {
      _bundles['vi'] = await _loadBundle('vi');
    } catch (e, st) {
      debugPrint('L10N: failed loading vi bundle: $e\n$st');
      _bundles['vi'] = {};
    }
    try {
      _bundles['en'] = await _loadBundle('en');
    } catch (e, st) {
      debugPrint('L10N: failed loading en bundle: $e\n$st');
      _bundles['en'] = {};
    }
    debugPrint(
      'L10N: loaded language=$_languageCode vi=${_bundles['vi']?.length ?? 0} en=${_bundles['en']?.length ?? 0}',
    );
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    final nextLanguageCode = _normalizeLanguageCode(languageCode);
    if (nextLanguageCode == _languageCode) {
      return;
    }

    _languageCode = nextLanguageCode;
    await _preferences.saveStudentLanguageCode(nextLanguageCode);
    notifyListeners();
  }

  String t(String key, {Map<String, Object?> arguments = const {}}) {
    final value = _bundles[_languageCode]?[key] ?? _bundles['vi']?[key];
    String result;
    if (value == null) {
      // avoid showing raw key in UI; provide a friendly fallback
      final human = _humanizeKey(key);
      debugPrint(
        'L10N: missing key "$key" for lang=$_languageCode -> fallback="$human"',
      );
      result = human;
    } else {
      result = value;
    }

    return _interpolate(result, arguments);
  }

  String tOr(
    String key, {
    required String fallbackVi,
    required String fallbackEn,
    Map<String, Object?> arguments = const {},
  }) {
    final value = _bundles[_languageCode]?[key] ?? _bundles['vi']?[key];
    final result =
        value ?? (_languageCode == 'en' ? fallbackEn : fallbackVi);
    if (value == null) {
      debugPrint(
        'L10N: missing key "$key" for lang=$_languageCode -> fallback="$result"',
      );
    }
    return _interpolate(result, arguments);
  }

  String _interpolate(
    String template,
    Map<String, Object?> arguments,
  ) {
    var result = template;
    if (arguments.isEmpty) {
      return result;
    }
    arguments.forEach((name, argumentValue) {
      result = result.replaceAll('{$name}', '$argumentValue');
    });
    return result;
  }

  String _humanizeKey(String key) {
    final parts = key.split('.');
    final last = parts.isNotEmpty ? parts.last : key;
    // replace underscores and camelCase boundaries with spaces
    var s = last.replaceAll('_', ' ');
    s = s.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    s = s.replaceAll(RegExp(r'[^\w\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1);
  }

  String _normalizeLanguageCode(String? languageCode) {
    final normalized = languageCode?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return defaultLanguageCode;
    }
    return supportedLanguageCodes.contains(normalized)
        ? normalized
        : defaultLanguageCode;
  }

  Future<Map<String, String>> _loadBundle(String languageCode) async {
    final asset = await rootBundle.loadString('assets/i18n/$languageCode.json');
    final decoded = jsonDecode(asset);
    if (decoded is! Map<String, dynamic>) {
      throw FlutterError('Invalid localization bundle for $languageCode');
    }

    return _flattenMap(decoded);
  }

  Map<String, String> _flattenMap(
    Map<String, dynamic> input, [
    String prefix = '',
  ]) {
    final result = <String, String>{};
    input.forEach((key, value) {
      final fullKey = prefix.isEmpty ? key : '$prefix.$key';
      if (value is Map<String, dynamic>) {
        result.addAll(_flattenMap(value, fullKey));
        return;
      }
      result[fullKey] = '$value';
    });
    return result;
  }
}

class AppLocalizationScope
    extends InheritedNotifier<AppLocalizationController> {
  const AppLocalizationScope({
    super.key,
    required AppLocalizationController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLocalizationController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppLocalizationScope>();
    assert(
      scope != null,
      'AppLocalizationScope is missing above this context.',
    );
    return scope!.notifier!;
  }
}

extension AppLocalizationContextX on BuildContext {
  AppLocalizationController get l10n => AppLocalizationScope.of(this);
}
