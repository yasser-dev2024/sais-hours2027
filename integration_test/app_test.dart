import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:horse_club_mobile/main.dart' as app;
import 'package:horse_club_mobile/database/database_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('يفتح التطبيق خلال التجربة دون مفتاح ويتنقل بين الوحدات', (
    tester,
  ) async {
    app.main();
    await tester.pump();
    expect(find.text('سايس الخيل'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    final agreement = find.text('قرأت وأوافق على التعهد');
    if (agreement.evaluate().isNotEmpty) {
      await tester.tap(agreement);
      await tester.pump();
      await tester.tap(find.text('أوافق وأتابع'));
    }
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 600));
    final skipPermissions = find.text('الدخول الآن وإكمال الأذونات لاحقًا');
    if (skipPermissions.evaluate().isNotEmpty) {
      await tester.tap(skipPermissions);
      await tester.pump(const Duration(milliseconds: 900));
    }
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.textContaining('مرحبًا بك في سايس الخيل'), findsOneWidget);
    expect(find.textContaining('مفتاح التفعيل'), findsNothing);

    expect(find.byTooltip('فتح مركز التنبيهات'), findsOneWidget);
    await tester.tap(find.byTooltip('فتح مركز التنبيهات'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('مركز التنبيهات'), findsOneWidget);
    expect(find.text('إشعارات الجهاز • jrs.mp3'), findsOneWidget);
    expect(find.text('اختبار الصوت'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('الخيول').last);
    await tester.pump(const Duration(milliseconds: 900));
    final horses = await DatabaseService.instance.rows(
      'horses',
      orderBy: 'name',
      limit: 1,
    );
    expect(horses, isNotEmpty);
    await tester.tap(find.text('${horses.first['name']}').first);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('العلاج'), findsOneWidget);
    expect(find.text('الإيواء والغرفة'), findsOneWidget);
    expect(find.text('اليومية والتمارين'), findsOneWidget);
    expect(find.text('تصوير الخيل'), findsOneWidget);
    expect(find.text('اختيار من المعرض'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 500));

    const destinations = [
      'الخيول',
      'المالية',
      'المشتركون',
      'الحجوزات اليومية',
      'السجل المالي',
      'التقارير',
      'الإعدادات',
      'الرئيسية',
    ];
    for (final destination in destinations) {
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(destination).last);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(destination), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });
}
