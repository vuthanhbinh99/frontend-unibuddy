import 'package:shared_preferences/shared_preferences.dart';

class FrontendPreferencesService {
  FrontendPreferencesService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _studentThemeModeKey = 'student.themeMode';
  static const _studentDashboardTabIndexKey = 'student.dashboardTabIndex';
  static const _studentLanguageCodeKey = 'student.languageCode';

  final SharedPreferencesAsync _preferences;

  Future<String?> readStudentThemeMode() {
    return _preferences.getString(_studentThemeModeKey);
  }

  Future<void> saveStudentThemeMode(String mode) {
    return _preferences.setString(_studentThemeModeKey, mode);
  }

  Future<int?> readStudentDashboardTabIndex() {
    return _preferences.getInt(_studentDashboardTabIndexKey);
  }

  Future<void> saveStudentDashboardTabIndex(int index) {
    return _preferences.setInt(_studentDashboardTabIndexKey, index);
  }

  Future<String?> readStudentLanguageCode() {
    return _preferences.getString(_studentLanguageCodeKey);
  }

  Future<void> saveStudentLanguageCode(String code) {
    return _preferences.setString(_studentLanguageCodeKey, code);
  }
}
