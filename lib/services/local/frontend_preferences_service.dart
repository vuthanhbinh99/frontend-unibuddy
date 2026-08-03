import 'package:shared_preferences/shared_preferences.dart';

class FrontendPreferencesService {
  FrontendPreferencesService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _studentThemeModeKey = 'student.themeMode';
  static const _studentDashboardTabIndexKey = 'student.dashboardTabIndex';
  static const _studentLanguageCodeKey = 'student.languageCode';
  static const _flashcardReminderEnabledKey = 'student.flashcardReminderEnabled';
  static const _flashcardReminderTimeKey = 'student.flashcardReminderTime';

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

  /// Trạng thái bật/tắt nhắc ôn tập flashcard. Mặc định bật (`true`).
  Future<bool> readFlashcardReminderEnabled() async {
    return await _preferences.getBool(_flashcardReminderEnabledKey) ?? true;
  }

  Future<void> saveFlashcardReminderEnabled(bool enabled) {
    return _preferences.setBool(_flashcardReminderEnabledKey, enabled);
  }

  /// Giờ nhắc ôn tập flashcard dạng chuỗi "HH:mm". Mặc định "20:00".
  Future<String> readFlashcardReminderTime() async {
    return await _preferences.getString(_flashcardReminderTimeKey) ?? '20:00';
  }

  Future<void> saveFlashcardReminderTime(String time) {
    return _preferences.setString(_flashcardReminderTimeKey, time);
  }
}
