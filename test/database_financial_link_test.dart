import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:horse_club_mobile/database/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory directory;
  late Database database;
  final service = DatabaseService.instance;

  Future<void> openDatabaseForTest() async {
    database = await databaseFactoryFfi.openDatabase(
      p.join(directory.path, 'finance_test.db'),
    );
    await service.initializeForTesting(
      database: database,
      appDirectory: directory,
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sayes-finance-test-');
    await openDatabaseForTest();
  });

  tearDown(() async {
    await service.close();
    await directory.delete(recursive: true);
  });

  test('قاعدة التثبيت الجديد تبدأ بلا خيول أو مشتركين', () async {
    expect(await _count(database, 'horses'), 0);
    expect(await _count(database, 'subscribers'), 0);
    expect(await _count(database, 'financial_transactions'), 0);
  });

  test('دفعة الإيواء من المشترك والخيل تنتج قيدًا ماليًا واحدًا', () async {
    final ids = await _createBoardingMember(service);

    expect(
      await database.query(
        'financial_transactions',
        where: "ref_type='subscriber'",
      ),
      isEmpty,
      reason: 'قيمة الاشتراك ليست قبضًا ماليًا قبل تسجيل دفعة فعلية',
    );

    final paymentId = await service.saveRecord('payments', {
      'subscriber_id': ids.subscriber,
      'amount': 1200,
      'payment_date': '2026-08-04',
      'payment_method': 'تحويل بنكي',
      'notes': 'إيواء أغسطس',
    });
    final payment = await service.row('payments', paymentId);
    final boardingId = (payment!['boarding_payment_id'] as num).toInt();
    final boarding = await service.row('boarding_payments', boardingId);

    expect(payment['horse_id'], ids.horse);
    expect(boarding?['payment_id'], paymentId);
    expect(boarding?['subscriber_id'], ids.subscriber);
    expect(boarding?['amount'], 1200.0);

    final transactions = await database.query('financial_transactions');
    expect(transactions, hasLength(1));
    expect(transactions.single['ref_type'], 'boarding_payment');
    expect(transactions.single['amount'], 1200.0);

    await service.saveRecord('boarding_payments', {
      'amount': 1250,
      'payment_date': '2026-08-05',
      'payment_method': 'نقدي',
    }, id: boardingId);
    final mirroredPayment = await service.row('payments', paymentId);
    final updatedLedger = await database.query('financial_transactions');
    expect(mirroredPayment?['amount'], 1250.0);
    expect(mirroredPayment?['payment_date'], '2026-08-05');
    expect(updatedLedger, hasLength(1));
    expect(updatedLedger.single['amount'], 1250.0);

    expect(
      () => service.saveRecord('payments', {
        'subscriber_id': ids.subscriber,
        'amount': 1250,
        'payment_date': '2026-08-05',
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('الإدخال من ملف الخيل يظهر تلقائيًا في دفعات المشترك', () async {
    final ids = await _createBoardingMember(service);
    final boardingId = await service.saveRecord('boarding_payments', {
      'horse_id': ids.horse,
      'amount': 1200,
      'payment_date': '2026-08-04',
      'is_paid': 1,
      'payment_method': 'نقدي',
    });
    final boarding = await service.row('boarding_payments', boardingId);
    final paymentId = (boarding!['payment_id'] as num).toInt();
    final payment = await service.row('payments', paymentId);

    expect(payment?['subscriber_id'], ids.subscriber);
    expect(payment?['boarding_payment_id'], boardingId);
    expect(await _count(database, 'financial_transactions'), 1);

    await service.deleteRecord('boarding_payments', boardingId);
    expect(await service.row('payments', paymentId), isNull);
    expect(await _count(database, 'financial_transactions'), 0);
  });

  test('الترحيل يربط السجلين القديمين ويحذف القيد المكرر', () async {
    final ids = await _createBoardingMember(service);
    await service.close();
    database = await databaseFactoryFfi.openDatabase(
      p.join(directory.path, 'finance_test.db'),
    );
    final paymentId = await database.insert('payments', {
      'subscriber_id': ids.subscriber,
      'amount': 1200,
      'payment_date': '2026-08-02',
      'payment_method': 'نقدي',
    });
    final boardingId = await database.insert('boarding_payments', {
      'horse_id': ids.horse,
      'amount': 1200,
      'payment_date': '2026-08-20',
      'is_paid': 1,
    });
    await database.insert('financial_transactions', {
      'type': 'income',
      'amount': 1200,
      'title': 'دفعة مشترك قديمة',
      'source_type': 'subscriber',
      'transaction_date': '2026-08-02',
      'ref_type': 'payment',
      'ref_id': paymentId,
    });
    await database.insert('financial_transactions', {
      'type': 'income',
      'amount': 1200,
      'title': 'دفعة إيواء قديمة',
      'source_type': 'horse',
      'transaction_date': '2026-08-20',
      'ref_type': 'boarding_payment',
      'ref_id': boardingId,
    });
    await database.close();

    await openDatabaseForTest();
    final payment = await service.row('payments', paymentId);
    final boarding = await service.row('boarding_payments', boardingId);
    expect(payment?['boarding_payment_id'], boardingId);
    expect(boarding?['payment_id'], paymentId);
    expect(await _count(database, 'financial_transactions'), 1);
  });
}

Future<({int horse, int subscriber})> _createBoardingMember(
  DatabaseService service,
) async {
  final horse = await service.saveRecord('horses', {
    'name': 'الخيل التجريبي',
    'ownership_type': 'إيواء',
  });
  final subscriber = await service.saveRecord('subscribers', {
    'name': 'مشترك الاختبار',
    'horse_id': horse,
    'subscription_type': 'إيواء شهري',
    'amount': 1200,
    'start_date': '2026-08-01',
    'end_date': '2026-08-31',
    'status': 'نشط',
  });
  return (horse: horse, subscriber: subscriber);
}

Future<int> _count(Database database, String table) async =>
    Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM $table'),
    ) ??
    0;
