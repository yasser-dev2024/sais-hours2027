import 'package:flutter_test/flutter_test.dart';
import 'package:horse_club_mobile/core/constants.dart';
import 'package:horse_club_mobile/database/schema.dart';
import 'package:horse_club_mobile/reports/report_service.dart';
import 'package:horse_club_mobile/utils/display_formatters.dart';

void main() {
  test('اسم المنتج عربي وثابت', () {
    expect(AppConstants.appName, 'سايس الخيل');
    expect(AppConstants.packageId, 'com.abuammar.horseclub.mobile2026');
    expect(AppConstants.version, '2.1.1');
  });

  test('يحافظ مخطط الجوال على الجداول التجارية الثمانية عشر', () {
    const expected = {
      'horses',
      'health_records',
      'appointments',
      'farrier_records',
      'expenses',
      'daily_notes',
      'subscribers',
      'subscription_history',
      'settings',
      'daily_bookings',
      'payments',
      'payment_invoices',
      'financial_transactions',
      'boarding_payments',
      'treatment_records',
      'stable_general_expenses',
      'stable_income_records',
      'boarding_contracts',
    };
    expect(DatabaseSchema.columns.keys.toSet(), expected);
  });

  test('تتوفر جميع تعريفات التقارير', () {
    expect(ReportService.definitions, hasLength(20));
    expect(
      ReportService.definitions.map((report) => report.key).toSet(),
      hasLength(20),
    );
  });

  test('تدعم سجلات تفاصيل الخيل الصور من الكاميرا والمعرض', () {
    for (final table in const [
      'horses',
      'health_records',
      'appointments',
      'farrier_records',
      'expenses',
      'daily_notes',
      'daily_bookings',
      'boarding_payments',
      'treatment_records',
    ]) {
      expect(
        DatabaseSchema.columns[table],
        contains('image_path'),
        reason: table,
      );
    }
  });

  test('تنسيق المبلغ والتاريخ عربي وواضح', () {
    expect(DisplayFormatters.money(125), '125.00 ر.س');
    expect(DisplayFormatters.date('2026-08-03'), '2026-08-03');
    expect(DisplayFormatters.date('invalid'), '—');
  });
}
