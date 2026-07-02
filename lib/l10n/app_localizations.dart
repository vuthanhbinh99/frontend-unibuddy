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
    _bundles['vi'] = await _loadBundle('vi');
    _bundles['en'] = await _loadBundle('en');
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
    final value = _bundles[_languageCode]?[key] ?? _bundles['vi']?[key] ?? key;
    if (arguments.isEmpty) {
      return value;
    }

    var result = value;
    arguments.forEach((name, argumentValue) {
      result = result.replaceAll('{$name}', '$argumentValue');
    });
    return result;
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

class AppLocalizationScope extends InheritedNotifier<AppLocalizationController> {
  const AppLocalizationScope({
    super.key,
    required AppLocalizationController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLocalizationController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLocalizationScope>();
    assert(scope != null, 'AppLocalizationScope is missing above this context.');
    return scope!.notifier!;
  }
}

extension AppLocalizationContextX on BuildContext {
  AppLocalizationController get l10n => AppLocalizationScope.of(this);
}