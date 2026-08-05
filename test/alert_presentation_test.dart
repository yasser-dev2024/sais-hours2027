import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horse_club_mobile/providers/app_provider.dart';
import 'package:horse_club_mobile/services/alert_actions.dart';
import 'package:horse_club_mobile/services/notification_service.dart';

void main() {
  group('عرض التنبيهات وربط أقسامها', () {
    test('يعرض نوع وسبب التطعيم ويفتح السجل الصحي', () {
      final alert = <String, Object?>{
        'kind': 'appointment',
        'alert_type': 'تطعيم',
        'reason': 'الجرعة السنوية',
      };

      expect(AlertPresentation.kind(alert), 'موعد تطعيم');
      expect(AlertPresentation.reason(alert), 'الجرعة السنوية');
      expect(AlertPresentation.horseTab(alert), 1);
      expect(AlertPresentation.targetLabel(alert), 'السجل الصحي');
      expect(AlertPresentation.icon(alert), Icons.health_and_safety_outlined);
    });

    test('يربط العلاج والتحذية والإيواء والاشتراك بأماكنها الدقيقة', () {
      expect(
        AlertPresentation.horseTab({
          'kind': 'appointment',
          'alert_type': 'علاج',
        }),
        2,
      );
      expect(
        AlertPresentation.horseTab({
          'kind': 'appointment',
          'alert_type': 'تحذية',
        }),
        4,
      );
      expect(
        AlertPresentation.targetLabel({
          'kind': 'boarding',
          'alert_type': 'إيواء',
        }),
        'قسم الإيواء والغرفة',
      );
      expect(
        AlertPresentation.targetLabel({
          'kind': 'subscription',
          'alert_type': 'إيواء شهري',
        }),
        'قسم الاشتراكات',
      );
    });

    test('يميز المنتهي والمتأخر كتنبيه عاجل', () {
      expect(AlertPresentation.urgent({'status': 'منتهي'}), isTrue);
      expect(AlertPresentation.urgent({'status': 'متأخر'}), isTrue);
      expect(AlertPresentation.urgent({'status': 'قادم'}), isFalse);
    });

    test('تغيير التاريخ أو السبب ينشئ هوية تنبيه محدثة', () {
      final provider = AppProvider();
      final original = <String, Object?>{
        'kind': 'appointment',
        'id': 7,
        'status': 'مجدول',
        'event_date': '2026-08-03',
        'alert_type': 'تطعيم',
        'reason': 'الجرعة الأولى',
      };
      final changedDate = {...original, 'event_date': '2026-09-10'};
      final changedReason = {...original, 'reason': 'الجرعة الثانية'};

      expect(
        provider.alertKey(changedDate),
        isNot(provider.alertKey(original)),
      );
      expect(
        provider.alertKey(changedReason),
        isNot(provider.alertKey(original)),
      );
    });

    test('تحديث تاريخ التنبيه يستبدل إشعار النظام نفسه', () {
      final service = NotificationService.instance;
      final original = <String, Object?>{
        'kind': 'appointment',
        'id': 7,
        'status': 'مجدول',
        'event_date': '2026-08-03',
      };
      final changedDate = {...original, 'event_date': '2026-09-10'};

      expect(
        service.notificationIdForAlert(original),
        service.notificationIdForKey(AppProvider().alertKey(changedDate)),
      );
    });
  });
}
