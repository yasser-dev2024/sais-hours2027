import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../database/database_service.dart';
import '../services/notification_service.dart';

class AppProvider extends ChangeNotifier {
  bool loading = true;
  String? error;
  int revision = 0;
  Map<String, Object?> stats = const {};
  List<Map<String, Object?>> alerts = const [];
  List<Map<String, Object?>> mutedAlerts = const [];
  Map<String, String> appSettings = const {};

  Color get primaryColor =>
      _parseColor(appSettings['primary_color'], AppConstants.navy);
  Color get accentColor =>
      _parseColor(appSettings['accent_color'], AppConstants.gold);
  bool get permissionsSetupSeen =>
      appSettings['mobile_permissions_setup'] == '1';

  Future<void> initialize() async {
    loading = true;
    error = null;
    notifyListeners();
    final minimumSplash = Future<void>.delayed(
      const Duration(milliseconds: 2800),
    );
    try {
      await DatabaseService.instance.initialize();
      try {
        await NotificationService.instance.initialize();
      } catch (_) {
        // Notifications are useful but must never prevent access to local data.
      }
      final channelVersion = await DatabaseService.instance.getSetting(
        'mobile_notification_channel_version',
      );
      if (channelVersion != NotificationService.channelVersion) {
        await DatabaseService.instance.setSetting('mobile_seen_alerts', '[]');
        await DatabaseService.instance.setSetting(
          'mobile_notification_channel_version',
          NotificationService.channelVersion,
        );
      }
      await refresh(notify: false);
      if (permissionsSetupSeen) await _notifyNewAlerts();
    } catch (exception) {
      error = 'تعذر تهيئة التطبيق: $exception';
    }
    await minimumSplash;
    loading = false;
    notifyListeners();
  }

  Future<void> refresh({bool notify = true}) async {
    await DatabaseService.instance.autoUpdateSubscriberStatuses();
    stats = await DatabaseService.instance.dashboardStats();
    appSettings = await DatabaseService.instance.settings();
    final allAlerts = await DatabaseService.instance.alerts();
    final muted = _decodeKeys(appSettings['mobile_muted_alerts']);
    final dismissed = _decodeKeys(appSettings['mobile_dismissed_alerts']);
    alerts = allAlerts
        .where(
          (alert) =>
              !_containsAlert(muted, alert) &&
              !_containsAlert(dismissed, alert),
        )
        .toList();
    mutedAlerts = allAlerts
        .where(
          (alert) =>
              _containsAlert(muted, alert) && !_containsAlert(dismissed, alert),
        )
        .toList();
    revision++;
    if (notify) notifyListeners();
  }

  String alertKey(Map<String, Object?> alert) =>
      '${alert['kind']}:${alert['id']}:${alert['status']}:${alert['event_date']}:${alert['alert_type']}:${alert['reason']}';

  String _legacyAlertKey(Map<String, Object?> alert) =>
      '${alert['kind']}:${alert['id']}:${alert['status']}';

  bool _containsAlert(Set<String> keys, Map<String, Object?> alert) =>
      keys.contains(alertKey(alert)) || keys.contains(_legacyAlertKey(alert));

  Future<void> muteAlert(Map<String, Object?> alert) async {
    final muted = _decodeKeys(appSettings['mobile_muted_alerts']);
    muted.add(alertKey(alert));
    await DatabaseService.instance.setSetting(
      'mobile_muted_alerts',
      jsonEncode(muted.toList()),
    );
    await NotificationService.instance.cancel(
      NotificationService.instance.notificationIdForAlert(alert),
    );
    await refresh();
  }

  Future<void> unmuteAlert(Map<String, Object?> alert) async {
    final muted = _decodeKeys(appSettings['mobile_muted_alerts']);
    muted.remove(alertKey(alert));
    muted.remove(_legacyAlertKey(alert));
    await DatabaseService.instance.setSetting(
      'mobile_muted_alerts',
      jsonEncode(muted.toList()),
    );
    await refresh();
    final seen = _decodeKeys(appSettings['mobile_seen_alerts'])
      ..remove(alertKey(alert));
    await DatabaseService.instance.setSetting(
      'mobile_seen_alerts',
      jsonEncode(seen.toList()),
    );
    await _notifyNewAlerts();
  }

  /// يخفي التنبيه فقط، بينما يبقى السجل الأصلي في ملف الخيل والتقارير.
  /// إذا عُدّل التاريخ أو السبب تتغير هوية التنبيه ويظهر مجددًا بالبيانات الجديدة.
  Future<void> dismissAlert(Map<String, Object?> alert) async {
    final dismissed = _decodeKeys(appSettings['mobile_dismissed_alerts']);
    dismissed.add(alertKey(alert));
    await DatabaseService.instance.setSetting(
      'mobile_dismissed_alerts',
      jsonEncode(dismissed.toList()),
    );
    await NotificationService.instance.cancel(
      NotificationService.instance.notificationIdForAlert(alert),
    );
    await refresh();
  }

  Future<void> dataChanged() async {
    await refresh();
    await _notifyNewAlerts();
  }

  Future<void> onAppResumed() async {
    await refresh();
    await _notifyNewAlerts();
  }

  Future<void> completePermissionsSetup() async {
    await DatabaseService.instance.setSetting('mobile_permissions_setup', '1');
    await refresh();
    await _notifyNewAlerts();
  }

  Future<void> _notifyNewAlerts() async {
    if (!await NotificationService.instance.notificationsEnabled()) return;
    final seenRaw = await DatabaseService.instance.getSetting(
      'mobile_seen_alerts',
    );
    final seen = <String>{};
    if (seenRaw != null) {
      try {
        seen.addAll((jsonDecode(seenRaw) as List).map((item) => '$item'));
      } catch (_) {}
    }
    final current = alerts.map(alertKey).toList();
    for (final stale in seen.difference(current.toSet())) {
      await NotificationService.instance.cancel(
        NotificationService.instance.notificationIdForKey(stale),
      );
    }
    for (final alert in alerts) {
      final key = alertKey(alert);
      final type = '${alert['alert_type'] ?? ''}'.trim().isEmpty
          ? (alert['kind'] == 'subscription' ? 'اشتراك' : 'موعد')
          : '${alert['alert_type']}';
      final subject = alert['kind'] == 'subscription'
          ? 'المشترك: ${alert['title'] ?? ''}'
          : 'الخيل: ${alert['horse_name'] ?? ''}';
      final title =
          'تنبيه $type — ${alert['kind'] == 'subscription' ? alert['title'] ?? '' : alert['horse_name'] ?? ''}';
      final body =
          '$subject\nالسبب: ${alert['reason'] ?? alert['title'] ?? ''}\n${alert['event_date'] ?? ''} • ${alert['status'] ?? ''}';
      try {
        final notificationId = NotificationService.instance
            .notificationIdForAlert(alert);
        final scheduled = await NotificationService.instance.scheduleAlert(
          id: notificationId,
          title: title,
          body: body,
          alert: alert,
        );
        if (!scheduled && !seen.contains(key)) {
          await NotificationService.instance.showAlert(
            id: notificationId,
            title: title,
            body: body,
            alert: alert,
          );
        }
      } catch (_) {
        // A denied/broken notification channel does not affect app data.
      }
    }
    await DatabaseService.instance.setSetting(
      'mobile_seen_alerts',
      jsonEncode(current),
    );
  }

  static Color _parseColor(String? source, Color fallback) {
    if (source == null) return fallback;
    final hex = source.replaceFirst('#', '');
    final value = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    return value == null ? fallback : Color(value);
  }

  static Set<String> _decodeKeys(String? source) {
    if (source == null || source.isEmpty) return <String>{};
    try {
      return (jsonDecode(source) as List).map((item) => '$item').toSet();
    } catch (_) {
      return <String>{};
    }
  }
}
