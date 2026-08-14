import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horse_club_mobile/license/license_gate.dart';
import 'package:horse_club_mobile/license/license_service.dart';
import 'package:horse_club_mobile/license/license_storage.dart';

void main() {
  testWidgets('التعهد غير محدد ولا يسمح بالدخول قبل الموافقة', (tester) async {
    final storage = _MemoryStorage();
    final service = LicenseService(storage: storage);
    var initializationCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: LicenseGate(
            service: service,
            onAccessGranted: () async => initializationCount++,
            child: const Text('التطبيق الحالي'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إقرار وتعهد'), findsOneWidget);
    expect(find.text('التطبيق الحالي'), findsNothing);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(initializationCount, 0);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('أوافق وأتابع'));
    await tester.pumpAndSettle();

    expect(find.text('إقرار وتعهد'), findsNothing);
    expect(find.text('التطبيق الحالي'), findsOneWidget);
    expect(initializationCount, 1);
  });

  testWidgets('يعرض شاشة التفعيل بعد انتهاء 20 يومًا', (tester) async {
    final now = DateTime.utc(2026, 8, 1);
    final started = now.subtract(const Duration(days: 20));
    final storage = _MemoryStorage()
      ..value = _record(
        started.millisecondsSinceEpoch,
        agreementAccepted: true,
      );
    final service = LicenseService(storage: storage, clock: () => now);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: LicenseGate(
            service: service,
            child: const Text('التطبيق الحالي'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('انتهت الفترة التجريبية'), findsOneWidget);
    expect(find.text('لطلب التفعيل والتواصل واتساب فقط'), findsOneWidget);
    expect(find.text('0501894192'), findsOneWidget);
    expect(find.text('Device ID / Installation ID'), findsOneWidget);
    expect(find.text('Serial Number / Activation Code'), findsOneWidget);
    expect(find.text('تفعيل'), findsOneWidget);
    expect(find.text('التطبيق الحالي'), findsNothing);
  });
}

String _record(int startedMs, {required bool agreementAccepted}) =>
    '{"v":1,"installation_id":"TEST-DEVICE-1234",'
    '"trial_started_at_utc_ms":$startedMs,'
    '"last_seen_at_utc_ms":$startedMs,'
    '"agreement_accepted_at_utc_ms":'
    '${agreementAccepted ? startedMs : 'null'},'
    '"activation_code":null,"activated_at_utc_ms":null}';

class _MemoryStorage implements LicenseStorage {
  String? value;

  @override
  Future<String?> readState() async => value;

  @override
  Future<void> writeState(String value) async => this.value = value;
}
