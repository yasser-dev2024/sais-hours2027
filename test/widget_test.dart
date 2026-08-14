import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horse_club_mobile/app/app.dart';
import 'package:horse_club_mobile/app/app_theme.dart';
import 'package:horse_club_mobile/providers/app_provider.dart';
import 'package:horse_club_mobile/screens/alerts_screen.dart';
import 'package:horse_club_mobile/screens/dashboard_screen.dart';
import 'package:horse_club_mobile/screens/home_shell.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('تعرض شاشة البدء اسم سايس الخيل بالعربية', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: AppProvider(),
        child: const HorseClubApp(),
      ),
    );

    expect(find.text('سايس الخيل'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('يعرض تنسيق الجوال الضيق دون تجاوزات', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppProvider();
    addTearDown(app.dispose);

    await tester.pumpWidget(_host(app, const DashboardScreen()));
    await tester.pumpAndSettle();

    expect(find.text('إضافة سريعة'), findsOneWidget);
    expect(find.text('إضافة خيل'), findsOneWidget);
    expect(find.text('إضافة حجز يومي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('يعزل تنسيق التنبيهات بين الجوال واللوحي', (tester) async {
    final app = AppProvider();
    addTearDown(app.dispose);

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host(app, const AlertsScreen()));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Scaffold)).width, 360);
    expect(find.text('اختبار الصوت', skipOffstage: false), findsOneWidget);
    expect(find.text('اختبار صوت jrs.mp3', skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1000, 800);
    await tester.pumpWidget(_host(app, const AlertsScreen()));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Scaffold)).width, 1000);
    expect(
      find.text('اختبار صوت jrs.mp3', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('اختبار الصوت', skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('يعرض جرس التنبيه ويفتح مركز التنبيهات على الجوال', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = AppProvider()
      ..alerts = [
        <String, Object?>{
          'kind': 'appointment',
          'id': 1,
          'related_id': 1,
          'alert_type': 'تطعيم',
          'reason': 'موعد التطعيم',
          'horse_name': 'الخيل',
          'event_date': '2026-08-15',
          'status': 'متأخر',
        },
      ];
    addTearDown(app.dispose);

    await tester.pumpWidget(
      _host(
        app,
        Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('الرئيسية'),
              actions: [
                buildAlertBellForTesting(
                  count: app.alerts.length,
                  compact: true,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AlertsScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('فتح مركز التنبيهات'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active), findsOneWidget);

    await tester.tap(find.byTooltip('فتح مركز التنبيهات'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('مركز التنبيهات'), findsOneWidget);
    expect(find.text('كل التنبيهات'), findsOneWidget);
    expect(find.text('نوع التنبيه: موعد تطعيم'), findsOneWidget);
    expect(find.text('اختبار الصوت'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _host(AppProvider app, Widget child) => ChangeNotifierProvider.value(
  value: app,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    home: Directionality(textDirection: TextDirection.rtl, child: child),
  ),
);
