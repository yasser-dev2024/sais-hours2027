import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationLaunchData {
  const NotificationLaunchData({
    required this.notificationId,
    required this.alert,
  });

  final int notificationId;
  final Map<String, Object?> alert;
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final ValueNotifier<NotificationLaunchData?> launchedAlert = ValueNotifier(
    null,
  );
  bool _initialized = false;
  static const channelVersion = '5';
  static const channelId = 'horse_club_alerts_jrs_alarm_v$channelVersion';
  static const _legacyChannels = <String>[
    'horse_club_alerts',
    'horse_club_alerts_jrs_alarm',
    'horse_club_alerts_jrs_alarm_v2',
    'horse_club_alerts_jrs_alarm_v3',
    'horse_club_alerts_jrs_alarm_v4',
  ];

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('notification_icon'),
      ),
      onDidReceiveNotificationResponse: _handleResponse,
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        'إنذار سايس الخيل بصوت jrs',
        description:
            'تنبيهات الخيل والاشتراكات والإيواء بصوت إنذار واضح وملء الشاشة',
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('jrs'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 450, 180, 450, 180, 700]),
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
    for (final legacy in _legacyChannels) {
      await android?.deleteNotificationChannel(channelId: legacy);
    }
    _initialized = true;
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _decodePayload(launchDetails?.notificationResponse?.payload);
    }
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final notifications =
        await android?.requestNotificationsPermission() ?? true;
    final fullScreen =
        await android?.requestFullScreenIntentPermission() ?? true;
    return notifications && fullScreen;
  }

  Future<bool> notificationsEnabled() async {
    await initialize();
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        true;
  }

  Future<void> showAlert({
    required int id,
    required String title,
    required String body,
    required Map<String, Object?> alert,
  }) async {
    await initialize();
    final payload = jsonEncode({'notification_id': id, 'alert': alert});
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: _details(title, body),
    );
  }

  Future<bool> scheduleAlert({
    required int id,
    required String title,
    required String body,
    required Map<String, Object?> alert,
  }) async {
    await initialize();
    final date = DateTime.tryParse('${alert['event_date'] ?? ''}');
    if (date == null) return false;
    final reminderDays = (alert['reminder_days'] as num?)?.toInt() ?? 3;
    final location = tz.getLocation('Asia/Riyadh');
    final event = tz.TZDateTime(location, date.year, date.month, date.day, 9);
    final scheduled = event.subtract(Duration(days: reminderDays));
    if (!scheduled.isAfter(
      tz.TZDateTime.now(location).add(const Duration(minutes: 1)),
    )) {
      return false;
    }
    final payload = jsonEncode({'notification_id': id, 'alert': alert});
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: _details(title, body),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
    return true;
  }

  Future<void> cancel(int id) => _plugin.cancel(id: id);

  int notificationIdForAlert(Map<String, Object?> alert) {
    final key = '${alert['kind']}:${alert['id']}:${alert['status']}';
    return notificationIdForKey(key);
  }

  int notificationIdForKey(String key) {
    // هوية إشعار النظام ثابتة للسجل والحالة حتى لو احتوت هوية التنبيه
    // الداخلية على تاريخ أو سبب جديدين لإجبار الواجهة على التحديث.
    final parts = key.split(':');
    final notificationKey = parts.length >= 3 ? parts.take(3).join(':') : key;
    var hash = 2166136261;
    for (final unit in notificationKey.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return 1000 + (hash % 2000000000);
  }

  void clearLaunchedAlert() => launchedAlert.value = null;

  void _handleResponse(NotificationResponse response) {
    _decodePayload(response.payload);
  }

  void _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final alert = Map<String, Object?>.from(decoded['alert'] as Map);
      launchedAlert.value = NotificationLaunchData(
        notificationId: (decoded['notification_id'] as num).toInt(),
        alert: alert,
      );
    } catch (_) {
      // تجاهل الحمولة القديمة أو غير الصالحة دون تعطيل التطبيق.
    }
  }

  NotificationDetails _details(String title, String body) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'إنذار سايس الخيل بصوت jrs',
          channelDescription:
              'تنبيهات الخيل والمشتركين والمواعيد المهمة بملء الشاشة',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('jrs'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 450, 180, 450, 180, 700]),
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          ticker: 'تنبيه سايس الخيل: $title',
          autoCancel: false,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: 'سايس الخيل',
          ),
        ),
      );
}
