import 'package:shared_preferences/shared_preferences.dart';

/// Service lưu các tùy chọn nhỏ chỉ thuộc frontend trên thiết bị.
///
/// Không dùng service này để cache dữ liệu nghiệp vụ từ backend như học phần,
/// deadline, ghi chú hay tài liệu. Những dữ liệu đó phải lấy qua API service.
class FrontendPreferencesService {
  FrontendPreferencesService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  /// Key lưu chế độ sáng/tối của khu vực sinh viên.
  static const _studentThemeModeKey = 'student.themeMode';

  /// Key lưu tab dashboard sinh viên được mở gần nhất.
  static const _studentDashboardTabIndexKey = 'student.dashboardTabIndex';

  /// Key lưu ngôn ngữ frontend sinh viên chọn.
  static const _studentLanguageCodeKey = 'student.languageCode';

  /// Key lưu trạng thái bật/tắt nhắc ôn flashcard.
  static const _flashcardReminderEnabledKey =
      'student.flashcardReminderEnabled';

  /// Key lưu giờ nhắc ôn flashcard dạng chuỗi `HH:mm`.
  static const _flashcardReminderTimeKey = 'student.flashcardReminderTime';

  final SharedPreferencesAsync _preferences;

  /// Đọc chế độ theme sinh viên đã lưu, ví dụ `light` hoặc `dark`.
  Future<String?> readStudentThemeMode() {
    return _preferences.getString(_studentThemeModeKey);
  }

  /// Lưu chế độ theme sinh viên để lần mở app sau giữ nguyên lựa chọn.
  Future<void> saveStudentThemeMode(String mode) {
    return _preferences.setString(_studentThemeModeKey, mode);
  }

  /// Đọc index tab dashboard sinh viên được chọn gần nhất.
  Future<int?> readStudentDashboardTabIndex() {
    return _preferences.getInt(_studentDashboardTabIndexKey);
  }

  /// Lưu index tab dashboard sinh viên để quay lại đúng tab sau khi mở app.
  Future<void> saveStudentDashboardTabIndex(int index) {
    return _preferences.setInt(_studentDashboardTabIndexKey, index);
  }

  /// Đọc mã ngôn ngữ sinh viên đã chọn.
  Future<String?> readStudentLanguageCode() {
    return _preferences.getString(_studentLanguageCodeKey);
  }

  /// Lưu mã ngôn ngữ sinh viên đã chọn.
  Future<void> saveStudentLanguageCode(String code) {
    return _preferences.setString(_studentLanguageCodeKey, code);
  }

  /// Trạng thái bật/tắt nhắc ôn tập flashcard. Mặc định bật (`true`).
  Future<bool> readFlashcardReminderEnabled() async {
    return await _preferences.getBool(_flashcardReminderEnabledKey) ?? true;
  }

  /// Lưu trạng thái bật/tắt nhắc ôn tập flashcard.
  Future<void> saveFlashcardReminderEnabled(bool enabled) {
    return _preferences.setBool(_flashcardReminderEnabledKey, enabled);
  }

  /// Giờ nhắc ôn tập flashcard dạng chuỗi "HH:mm". Mặc định "20:00".
  Future<String> readFlashcardReminderTime() async {
    return await _preferences.getString(_flashcardReminderTimeKey) ?? '20:00';
  }

  /// Lưu giờ nhắc ôn tập flashcard dạng chuỗi `HH:mm`.
  Future<void> saveFlashcardReminderTime(String time) {
    return _preferences.setString(_flashcardReminderTimeKey, time);
  }
}
