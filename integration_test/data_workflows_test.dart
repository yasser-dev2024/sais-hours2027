import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import 'package:horse_club_mobile/backup/backup_service.dart';
import 'package:horse_club_mobile/database/database_service.dart';
import 'package:horse_club_mobile/reports/report_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('دورة البيانات الكاملة والنسخ والتقرير وبقاء البيانات', (
    tester,
  ) async {
    final database = DatabaseService.instance;
    await database.initialize();
    final baseline = <String, int>{
      for (final table in const [
        'horses',
        'subscribers',
        'payments',
        'expenses',
        'health_records',
        'appointments',
        'subscription_history',
      ])
        table: await _count(table),
    };
    final original = await BackupService.instance.createBackup();
    final marker = 'اختبار-تكامل-${DateTime.now().microsecondsSinceEpoch}';
    File? corrupt;
    var originalRestored = false;

    try {
      final horseId = await database.saveRecord('horses', {
        'name': '$marker-خيل',
        'breed': 'عربي أصيل',
        'gender': 'ذكر',
        'health_status': 'جيدة',
        'ownership_type': 'تابع للإسطبل',
      });
      expect((await database.row('horses', horseId))?['name'], '$marker-خيل');

      await database.saveRecord('horses', {
        'color': 'أشهب',
        'stable_location': 'غرفة الاختبار',
      }, id: horseId);
      expect((await database.row('horses', horseId))?['color'], 'أشهب');

      final subscriberId = await database.saveRecord('subscribers', {
        'name': '$marker-عضو',
        'phone': '+966501234567',
        'horse_id': horseId,
        'subscription_type': 'إيواء + تدريب',
        'duration': 'شهري',
        'amount': 1200,
        'start_date': '2026-08-01',
        'end_date': '2026-08-31',
        'status': 'نشط',
        'payment_method': 'تحويل بنكي',
      });
      final subscriber = await database.row('subscribers', subscriberId);
      expect(subscriber?['member_code'], isNotEmpty);
      expect(subscriber?['horse_id'], horseId);
      expect(
        await database.db.query(
          'financial_transactions',
          where: 'ref_type=? AND ref_id=?',
          whereArgs: ['subscriber', subscriberId],
        ),
        isEmpty,
        reason: 'قيمة الاشتراك لا تُحتسب قبضًا قبل إدخال دفعة فعلية',
      );

      await database.renewSubscription(subscriberId, {
        'subscription_type': 'إيواء + تدريب',
        'duration': 'شهري',
        'amount': 1250,
        'start_date': '2026-09-01',
        'end_date': '2026-09-30',
        'payment_method': 'نقدي',
        'notes': marker,
      });
      expect(
        await _count(
          'subscription_history',
          where: 'subscriber_id=?',
          whereArgs: [subscriberId],
        ),
        1,
      );

      final paymentId = await database.saveRecord('payments', {
        'subscriber_id': subscriberId,
        'amount': 300,
        'payment_date': '2026-08-03',
        'payment_method': 'نقدي',
        'notes': marker,
      });
      final payment = await database.row('payments', paymentId);
      expect(payment, isNotNull);
      final boardingPaymentId = (payment!['boarding_payment_id'] as num)
          .toInt();
      final mirroredBoarding = await database.row(
        'boarding_payments',
        boardingPaymentId,
      );
      expect(mirroredBoarding?['payment_id'], paymentId);
      final linkedIncome = await database.db.query(
        'financial_transactions',
        where: '(ref_type=? AND ref_id=?) OR (ref_type=? AND ref_id=?)',
        whereArgs: [
          'payment',
          paymentId,
          'boarding_payment',
          boardingPaymentId,
        ],
      );
      expect(linkedIncome, hasLength(1));
      expect(linkedIncome.single['amount'], 300.0);

      final expenseId = await database.saveRecord('expenses', {
        'horse_id': horseId,
        'category': 'تطعيم',
        'amount': 175,
        'expense_date': '2026-08-03',
        'description': '$marker-مصروف',
        'payer_type': 'stable',
        'is_paid': 1,
      });
      expect(await database.row('expenses', expenseId), isNotNull);
      final expenseTransaction = await database.db.query(
        'financial_transactions',
        where: 'ref_type=? AND ref_id=?',
        whereArgs: ['expense', expenseId],
        limit: 1,
      );
      expect(expenseTransaction, hasLength(1));
      expect(expenseTransaction.first['affects_budget'], 1);

      final boardingHorseId = await database.saveRecord('horses', {
        'name': '$marker-خيل-إيواء',
        'ownership_type': 'إيواء',
      });
      final ownerExpenseId = await database.saveRecord('expenses', {
        'horse_id': boardingHorseId,
        'category': 'تحذية',
        'amount': 90,
        'expense_date': '2026-08-03',
        'payer_type': 'owner',
      });
      expect(
        await database.db.query(
          'financial_transactions',
          where: 'ref_type=? AND ref_id=?',
          whereArgs: ['expense', ownerExpenseId],
        ),
        isEmpty,
      );
      final debtExpenseId = await database.saveRecord('expenses', {
        'horse_id': boardingHorseId,
        'category': 'علاج',
        'amount': 210,
        'expense_date': '2026-08-03',
        'payer_type': 'stable',
        'affects_budget': 0,
        'charge_to_subscriber': 1,
        'debt_settled': 0,
      });
      final debtTransaction = await database.db.query(
        'financial_transactions',
        where: 'ref_type=? AND ref_id=?',
        whereArgs: ['expense', debtExpenseId],
        limit: 1,
      );
      expect(debtTransaction, hasLength(1));
      expect(debtTransaction.first['affects_budget'], 0);
      expect(debtTransaction.first['is_subscriber_debt'], 1);

      final vaccineId = await database.saveRecord('health_records', {
        'horse_id': horseId,
        'record_type': 'تطعيم',
        'title': '$marker-تطعيم',
        'record_date': '2026-08-03',
        'next_date': '2027-08-03',
      });
      expect(await database.row('health_records', vaccineId), isNotNull);

      await database.saveRecord('appointments', {
        'horse_id': horseId,
        'appointment_type': 'تطعيم',
        'title': '$marker-تنبيه',
        'description': '$marker-سبب التطعيم',
        'appointment_date': '2001-01-01',
        'reminder_days': 3,
        'status': 'مجدول',
      });
      final alerts = await database.alerts();
      expect(alerts.any((row) => row['title'] == '$marker-تنبيه'), isTrue);
      final linkedAlert = alerts.firstWhere(
        (row) => row['title'] == '$marker-تنبيه',
      );
      expect(linkedAlert['alert_type'], 'تطعيم');
      expect(linkedAlert['reason'], '$marker-سبب التطعيم');
      expect(linkedAlert['related_id'], horseId);

      await database.saveRecord('daily_bookings', {
        'customer_name': '$marker-حجز',
        'service_type': 'تدريب',
        'duration_minutes': 30,
        'price': 150,
        'booking_date': '2026-08-03',
        'booking_time': '10:00',
      });

      final search = await database.rows(
        'horses',
        where: 'name=?',
        whereArgs: ['$marker-خيل'],
      );
      expect(search, hasLength(1));

      final generated = await ReportService.instance.buildPdf(
        await ReportService.instance.load('all_horses'),
      );
      expect(generated.length, greaterThan(1000));
      expect(String.fromCharCodes(generated.take(4)), '%PDF');
      final subscriberReport = await ReportService.instance.buildPdf(
        await ReportService.instance.loadSubscriberComplete(subscriberId),
      );
      expect(subscriberReport.length, greaterThan(1000));
      final horseReport = await ReportService.instance.buildPdf(
        await ReportService.instance.loadHorseComplete(horseId, period: 'week'),
      );
      expect(horseReport.length, greaterThan(1000));

      final testBackup = await BackupService.instance.createBackup();
      expect(await testBackup.file.exists(), isTrue);
      expect(testBackup.sha256, hasLength(64));
      expect(await database.integrityCheck(testBackup.file.path), equals('ok'));

      await database.close();
      await database.initialize();
      expect(await database.row('horses', horseId), isNotNull);

      corrupt = File(p.join(database.appDirectory.path, 'corrupt_workflow.db'));
      await corrupt.writeAsBytes(List<int>.filled(2048, 0x41), flush: true);
      await expectLater(
        BackupService.instance.restore(corrupt),
        throwsFormatException,
      );

      await BackupService.instance.restore(original.file);
      originalRestored = true;
      expect(
        await database.rows(
          'horses',
          where: 'name LIKE ?',
          whereArgs: ['%$marker%'],
        ),
        isEmpty,
      );
      for (final entry in baseline.entries) {
        expect(await _count(entry.key), entry.value, reason: entry.key);
      }
    } finally {
      if (!originalRestored) {
        await database.initialize();
        await BackupService.instance.restore(original.file);
      }
      if (corrupt != null && await corrupt.exists()) {
        await corrupt.delete();
      }
    }
  });
}

Future<int> _count(
  String table, {
  String? where,
  List<Object?>? whereArgs,
}) async {
  final suffix = where == null ? '' : ' WHERE $where';
  final result = await DatabaseService.instance.db.rawQuery(
    'SELECT COUNT(*) total FROM "$table"$suffix',
    whereArgs,
  );
  return (result.first['total'] as num).toInt();
}
