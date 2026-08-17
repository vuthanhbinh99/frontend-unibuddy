import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Id kênh thông báo ưu tiên cao. Phải trùng với
/// `com.google.firebase.messaging.default_notification_channel_id`
/// khai báo trong AndroidManifest.xml để notification background/terminated
/// hiển thị đúng mức ưu tiên.
const String kHighImportanceChannelId = 'unibuddy_high_importance';

/// Kênh riêng cho các nhắc nhở đặt lịch cục bộ (ôn tập flashcard hằng ngày).
const String kDailyReminderChannelId = 'unibuddy_daily_reminder';

/// Id cố định của notification "Ôn tập Flashcard mỗi ngày". Dùng cùng một id
/// để mỗi lần đặt lịch mới sẽ ghi đè lịch cũ thay vì tạo trùng.
const int kFlashcardReminderNotificationId = 1001;

/// Handler chạy nền cho FCM. Bắt buộc phải là hàm top-level (không nằm trong
/// class) và được đánh dấu `@pragma('vm:entry-point')` vì nó chạy trong một
/// isolate riêng khi app ở background/terminated.
///
/// Message của hệ thống có kèm khối `notification`, nên hệ điều hành tự hiển
/// thị lên khay — ở đây chỉ cần đảm bảo Firebase đã được khởi tạo.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Callback được gọi khi người dùng chạm vào một notification để mở app.
typedef PushNotificationTapHandler = void Function(Map<String, dynamic> data);

/// Gói toàn bộ logic Firebase Cloud Messaging: xin quyền, lấy token, hiển thị
/// notification khi app đang mở (foreground) và điều hướng khi người dùng chạm.
class PushNotificationService {
  PushNotificationService();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  PushNotificationTapHandler? _onNotificationTap;
  bool _initialized = false;

  /// Đăng ký handler điều hướng khi người dùng chạm vào notification.
  set onNotificationTap(PushNotificationTapHandler? handler) {
    _onNotificationTap = handler;
  }

  /// Khởi tạo dịch vụ: xin quyền, tạo kênh Android, đăng ký các listener.
  ///
  /// An toàn khi gọi nhiều lần (chỉ chạy một lần thực sự).
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    await _messaging.requestPermission();

    await _initializeTimeZone();
    await _initializeLocalNotifications();

    // Foreground: OS không tự hiện notification, nên ta tự dựng local
    // notification từ payload để người dùng vẫn thấy heads-up khi app đang mở.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // App đang ở background rồi được mở lên bằng cách chạm vào notification.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
  }

  /// Khởi tạo cơ sở dữ liệu múi giờ và đặt múi giờ cục bộ của thiết bị.
  /// Bắt buộc phải làm trước khi dùng `zonedSchedule`, nếu không thời điểm đặt
  /// lịch sẽ bị lệch múi giờ.
  Future<void> _initializeTimeZone() async {
    tz.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (error) {
      debugPrint('PushNotificationService._initializeTimeZone failed: $error');
    }
  }

  /// Khởi tạo local notification plugin và tạo các kênh Android cần dùng.
  ///
  /// Kênh quan trọng dùng cho FCM foreground; kênh nhắc hằng ngày dùng cho lịch
  /// ôn flashcard cục bộ.
  Future<void> _initializeLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _onNotificationTap?.call({'type': payload});
        }
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    const channel = AndroidNotificationChannel(
      kHighImportanceChannelId,
      'Thông báo quan trọng',
      description: 'Kênh hiển thị các thông báo đẩy từ UniBuddy.',
      importance: Importance.max,
    );

    const dailyReminderChannel = AndroidNotificationChannel(
      kDailyReminderChannelId,
      'Nhắc nhở hằng ngày',
      description: 'Kênh nhắc nhở ôn tập flashcard theo lịch mỗi ngày.',
      importance: Importance.high,
    );

    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.createNotificationChannel(dailyReminderChannel);

    // Android 13+ yêu cầu xin quyền hiển thị notification runtime.
    await androidPlugin?.requestNotificationsPermission();
  }

  /// Đặt lịch (hoặc đặt lại) thông báo "Ôn tập Flashcard mỗi ngày" lặp lại
  /// hằng ngày vào [hour]:[minute] theo giờ địa phương.
  ///
  /// Dùng chung [kFlashcardReminderNotificationId] nên gọi nhiều lần chỉ ghi
  /// đè lịch cũ. Ưu tiên exact alarm; nếu thiết bị không cho phép thì tự động
  /// hạ xuống chế độ inexact để vẫn hoạt động thay vì ném lỗi.
  Future<void> scheduleDailyFlashcardReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final canScheduleExact =
        await androidPlugin?.canScheduleExactNotifications() ?? false;
    final scheduleMode = canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        kDailyReminderChannelId,
        'Nhắc nhở hằng ngày',
        channelDescription:
            'Kênh nhắc nhở ôn tập flashcard theo lịch mỗi ngày.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _localNotifications.zonedSchedule(
      kFlashcardReminderNotificationId,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      details,
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'flashcard_review',
    );
  }

  /// Huỷ lịch thông báo ôn tập flashcard (khi người dùng tắt toggle).
  Future<void> cancelDailyFlashcardReminder() async {
    await _localNotifications.cancel(kFlashcardReminderNotificationId);
  }

  /// Tính mốc thời gian gần nhất trong tương lai ứng với [hour]:[minute].
  /// Nếu giờ hôm nay đã trôi qua thì đẩy sang ngày mai.
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Hiển thị notification local khi nhận FCM trong lúc app đang mở.
  ///
  /// Khi app foreground, hệ điều hành không luôn tự hiện thông báo từ FCM, nên
  /// hàm này dựng local notification để người dùng vẫn thấy thông báo.
  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) {
      return;
    }

    final type = message.data['type']?.toString();

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          kHighImportanceChannelId,
          'Thông báo quan trọng',
          channelDescription: 'Kênh hiển thị các thông báo đẩy từ UniBuddy.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: type,
    );
  }

  /// Chuyển payload notification cho UI xử lý điều hướng sau khi người dùng bấm.
  void _handleMessageTap(RemoteMessage message) {
    _onNotificationTap?.call(message.data);
  }

  /// Lấy FCM token của thiết bị. Trả về `null` nếu không lấy được
  /// (ví dụ giả lập không có Google Play services, hoặc bị từ chối quyền).
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (error) {
      debugPrint('PushNotificationService.getToken failed: $error');
      return null;
    }
  }

  /// Stream phát ra token mới mỗi khi FCM xoay vòng token.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Message đã mở app từ trạng thái terminated (nếu có).
  Future<RemoteMessage?> getInitialMessage() {
    return _messaging.getInitialMessage();
  }
}
