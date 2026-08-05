import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/validators.dart';
import '../database/database_service.dart';

class ReportDefinition {
  const ReportDefinition(this.key, this.title, this.description);
  final String key;
  final String title;
  final String description;
}

class ReportData {
  const ReportData({
    required this.title,
    required this.columns,
    required this.rows,
    this.summary = const [],
    this.sections = const [],
    this.images = const [],
  });
  final String title;
  final List<MapEntry<String, String>> columns;
  final List<Map<String, Object?>> rows;
  final List<String> summary;
  final List<ReportSection> sections;
  final List<ReportImage> images;
}

class ReportSection {
  const ReportSection({
    required this.title,
    required this.columns,
    required this.rows,
  });

  final String title;
  final List<MapEntry<String, String>> columns;
  final List<Map<String, Object?>> rows;
}

class ReportImage {
  const ReportImage(this.label, this.path);
  final String label;
  final String path;
}

class ReportService {
  ReportService._();
  static final instance = ReportService._();

  static const definitions = <ReportDefinition>[
    ReportDefinition(
      'all_horses',
      'جميع الخيول',
      'بيانات الخيول والملاك والحالة',
    ),
    ReportDefinition(
      'daily_bookings',
      'إيرادات اليومية',
      'حجوزات وإيرادات اليوم',
    ),
    ReportDefinition('health', 'الحالة الصحية', 'السجلات الصحية لجميع الخيول'),
    ReportDefinition('upcoming', 'المواعيد القادمة', 'المواعيد خلال 7 أيام'),
    ReportDefinition(
      'overdue',
      'المواعيد المتأخرة',
      'المواعيد التي تجاوزت تاريخها',
    ),
    ReportDefinition(
      'monthly_expenses',
      'المصروفات الشهرية',
      'تفاصيل مصروفات الشهر الحالي',
    ),
    ReportDefinition(
      'expenses_category',
      'المصروفات حسب الفئة',
      'إجماليات الفئات',
    ),
    ReportDefinition(
      'all_subscribers',
      'جميع المشتركين',
      'الاشتراكات وبيانات التواصل',
    ),
    ReportDefinition(
      'active_subscribers',
      'الاشتراكات النشطة',
      'المشتركون النشطون',
    ),
    ReportDefinition(
      'expired_subscribers',
      'الاشتراكات المنتهية',
      'المشتركون المنتهية اشتراكاتهم',
    ),
    ReportDefinition(
      'monthly_payments',
      'مدفوعات الشهر',
      'الواردات من المشتركين هذا الشهر',
    ),
    ReportDefinition(
      'yearly_payments',
      'مدفوعات السنة',
      'الواردات من المشتركين هذه السنة',
    ),
    ReportDefinition(
      'financial_summary',
      'الملخص المالي',
      'إجمالي الوارد والمصروف والصافي',
    ),
    ReportDefinition(
      'financial_daily',
      'التقرير المالي اليومي',
      'عمليات اليوم',
    ),
    ReportDefinition(
      'financial_monthly',
      'التقرير المالي الشهري',
      'عمليات الشهر',
    ),
    ReportDefinition(
      'financial_yearly',
      'التقرير المالي السنوي',
      'عمليات السنة',
    ),
    ReportDefinition(
      'financial_subscriber',
      'المالي حسب المشترك',
      'تجميع العمليات حسب المشترك',
    ),
    ReportDefinition(
      'financial_horse',
      'المالي حسب الخيل',
      'تجميع العمليات حسب الخيل',
    ),
    ReportDefinition(
      'income_source',
      'الواردات حسب المصدر',
      'تجميع الواردات حسب المصدر',
    ),
    ReportDefinition(
      'budget_full',
      'الميزانية الشاملة',
      'الوارد والمخصوم وغير المخصوم والديون والصافي',
    ),
  ];

  Future<ReportData> load(String key) async {
    final database = DatabaseService.instance.db;
    switch (key) {
      case 'all_horses':
        return ReportData(
          title: 'تقرير جميع الخيول',
          columns: _cols(const {
            'name': 'الاسم',
            'breed': 'السلالة',
            'gender': 'الجنس',
            'owner_name': 'المالك',
            'stable_location': 'الإسطبل',
            'health_status': 'الحالة',
          }),
          rows: await database.query('horses', orderBy: 'name'),
        );
      case 'daily_bookings':
        final rows = await database.query(
          'daily_bookings',
          where: "booking_date=date('now','localtime')",
          orderBy: 'booking_time',
        );
        return ReportData(
          title: 'تقرير إيرادات اليومية',
          columns: _cols(const {
            'customer_name': 'العميل',
            'service_type': 'الخدمة',
            'duration_minutes': 'المدة',
            'price': 'المبلغ',
            'booking_time': 'الوقت',
            'phone': 'الجوال',
          }),
          rows: rows,
          summary: [
            'عدد الحجوزات: ${rows.length}',
            'الإجمالي: ${_sum(rows, 'price').toStringAsFixed(2)} ر.س',
          ],
        );
      case 'health':
        return ReportData(
          title: 'تقرير الحالة الصحية',
          columns: _cols(const {
            'horse_name': 'الخيل',
            'record_type': 'النوع',
            'title': 'العنوان',
            'record_date': 'التاريخ',
            'next_date': 'الموعد القادم',
            'vet_name': 'الطبيب',
          }),
          rows: await database.rawQuery(
            'SELECT hr.*,h.name horse_name FROM health_records hr LEFT JOIN horses h ON h.id=hr.horse_id ORDER BY record_date DESC',
          ),
        );
      case 'upcoming':
      case 'overdue':
        final upcoming = key == 'upcoming';
        return ReportData(
          title: upcoming
              ? 'تقرير المواعيد القادمة'
              : 'تقرير المواعيد المتأخرة',
          columns: _cols(const {
            'horse_name': 'الخيل',
            'appointment_type': 'النوع',
            'title': 'العنوان',
            'appointment_date': 'التاريخ',
            'status': 'الحالة',
          }),
          rows: await database.rawQuery(
            '''SELECT a.*,h.name horse_name FROM appointments a
            LEFT JOIN horses h ON h.id=a.horse_id WHERE ${upcoming ? "a.appointment_date BETWEEN date('now','localtime') AND date('now','localtime','+7 days')" : "a.appointment_date<date('now','localtime')"}
            AND a.status NOT IN ('مكتمل','ملغي') ORDER BY a.appointment_date''',
          ),
        );
      case 'monthly_expenses':
        final rows = await database.rawQuery(
          "SELECT e.*,h.name horse_name FROM expenses e LEFT JOIN horses h ON h.id=e.horse_id WHERE strftime('%Y-%m',expense_date)=strftime('%Y-%m','now','localtime') ORDER BY expense_date DESC",
        );
        return ReportData(
          title: 'تقرير المصروفات الشهرية',
          columns: _cols(const {
            'expense_date': 'التاريخ',
            'horse_name': 'الخيل',
            'category': 'الفئة',
            'description': 'الوصف',
            'amount': 'المبلغ',
          }),
          rows: rows,
          summary: ['الإجمالي: ${_sum(rows, 'amount').toStringAsFixed(2)} ر.س'],
        );
      case 'expenses_category':
        return ReportData(
          title: 'تقرير المصروفات حسب الفئة',
          columns: _cols(const {
            'category': 'الفئة',
            'total': 'الإجمالي',
            'count': 'العمليات',
          }),
          rows: await database.rawQuery(
            'SELECT category,SUM(amount) total,COUNT(*) count FROM expenses GROUP BY category ORDER BY total DESC',
          ),
        );
      case 'all_subscribers':
      case 'active_subscribers':
      case 'expired_subscribers':
        final where = key == 'active_subscribers'
            ? "status='نشط'"
            : key == 'expired_subscribers'
            ? "status='منتهي'"
            : null;
        return ReportData(
          title: key == 'all_subscribers'
              ? 'تقرير جميع المشتركين'
              : key == 'active_subscribers'
              ? 'تقرير الاشتراكات النشطة'
              : 'تقرير الاشتراكات المنتهية',
          columns: _cols(const {
            'name': 'الاسم',
            'phone': 'الجوال',
            'subscription_type': 'النوع',
            'amount': 'القيمة',
            'start_date': 'البداية',
            'end_date': 'النهاية',
            'status': 'الحالة',
          }),
          rows: await database.query(
            'subscribers',
            where: where,
            orderBy: 'end_date',
          ),
        );
      case 'monthly_payments':
      case 'yearly_payments':
        final monthly = key == 'monthly_payments';
        final rows = await database.rawQuery(
          "SELECT ft.*,s.name subscriber_name FROM financial_transactions ft LEFT JOIN subscribers s ON s.id=ft.subscriber_id WHERE ft.type='income' AND ft.source_type='subscriber' AND strftime('${monthly ? '%Y-%m' : '%Y'}',transaction_date)=strftime('${monthly ? '%Y-%m' : '%Y'}','now','localtime') ORDER BY transaction_date DESC",
        );
        return ReportData(
          title: monthly ? 'تقرير مدفوعات الشهر' : 'تقرير مدفوعات السنة',
          columns: _cols(const {
            'transaction_date': 'التاريخ',
            'subscriber_name': 'المشترك',
            'title': 'البيان',
            'payment_method': 'طريقة الدفع',
            'amount': 'المبلغ',
          }),
          rows: rows,
          summary: ['الإجمالي: ${_sum(rows, 'amount').toStringAsFixed(2)} ر.س'],
        );
      case 'financial_summary':
        final rows = await database.rawQuery(
          "SELECT type,category,COALESCE(affects_budget,1) affects_budget,SUM(amount) total,COUNT(*) count FROM financial_transactions GROUP BY type,category,COALESCE(affects_budget,1) ORDER BY type,total DESC",
        );
        final all = await database.rawQuery(
          "SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END),0) income,COALESCE(SUM(CASE WHEN type='expense' AND COALESCE(affects_budget,1)=1 THEN amount ELSE 0 END),0) expense,COALESCE(SUM(CASE WHEN type='expense' AND COALESCE(affects_budget,1)=0 THEN amount ELSE 0 END),0) excluded FROM financial_transactions",
        );
        final income = (all.first['income'] as num?)?.toDouble() ?? 0;
        final expense = (all.first['expense'] as num?)?.toDouble() ?? 0;
        return ReportData(
          title: 'الملخص المالي الشامل',
          columns: _cols(const {
            'type': 'النوع',
            'category': 'الفئة',
            'affects_budget': 'يدخل الميزانية',
            'count': 'العمليات',
            'total': 'الإجمالي',
          }),
          rows: rows,
          summary: [
            'إجمالي الواردات: ${income.toStringAsFixed(2)} ر.س',
            'إجمالي المصاريف: ${expense.toStringAsFixed(2)} ر.س',
            'مصروفات غير مخصومة: ${((all.first['excluded'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} ر.س',
            'الصافي: ${(income - expense).toStringAsFixed(2)} ر.س',
          ],
        );
      case 'financial_daily':
      case 'financial_monthly':
      case 'financial_yearly':
        final format = key == 'financial_daily'
            ? '%Y-%m-%d'
            : key == 'financial_monthly'
            ? '%Y-%m'
            : '%Y';
        final rows = await database.rawQuery(
          "SELECT * FROM financial_transactions WHERE strftime('$format',transaction_date)=strftime('$format','now','localtime') ORDER BY transaction_date DESC",
        );
        return ReportData(
          title: key == 'financial_daily'
              ? 'التقرير المالي اليومي'
              : key == 'financial_monthly'
              ? 'التقرير المالي الشهري'
              : 'التقرير المالي السنوي',
          columns: _cols(const {
            'transaction_date': 'التاريخ',
            'type': 'النوع',
            'title': 'البيان',
            'source_type': 'المصدر',
            'category': 'الفئة',
            'amount': 'المبلغ',
          }),
          rows: rows,
          summary: _financialSummary(rows),
        );
      case 'financial_subscriber':
        return ReportData(
          title: 'تقرير مالي حسب المشترك',
          columns: _cols(const {
            'name': 'المشترك',
            'income': 'الواردات',
            'expense': 'المصاريف',
            'net': 'الصافي',
          }),
          rows: await database.rawQuery(
            "SELECT COALESCE(s.name,'بدون مشترك') name,SUM(CASE WHEN ft.type='income' THEN ft.amount ELSE 0 END) income,SUM(CASE WHEN ft.type='expense' AND COALESCE(ft.affects_budget,1)=1 THEN ft.amount ELSE 0 END) expense,SUM(CASE WHEN ft.type='income' THEN ft.amount WHEN COALESCE(ft.affects_budget,1)=1 THEN -ft.amount ELSE 0 END) net FROM financial_transactions ft LEFT JOIN subscribers s ON s.id=ft.subscriber_id GROUP BY ft.subscriber_id ORDER BY name",
          ),
        );
      case 'financial_horse':
        return ReportData(
          title: 'تقرير مالي حسب الخيل',
          columns: _cols(const {
            'name': 'الخيل',
            'income': 'الواردات',
            'expense': 'المصاريف',
            'net': 'الصافي',
          }),
          rows: await database.rawQuery(
            "SELECT COALESCE(h.name,'بدون خيل') name,SUM(CASE WHEN ft.type='income' THEN ft.amount ELSE 0 END) income,SUM(CASE WHEN ft.type='expense' AND COALESCE(ft.affects_budget,1)=1 THEN ft.amount ELSE 0 END) expense,SUM(CASE WHEN ft.type='income' THEN ft.amount WHEN COALESCE(ft.affects_budget,1)=1 THEN -ft.amount ELSE 0 END) net FROM financial_transactions ft LEFT JOIN horses h ON h.id=ft.horse_id GROUP BY ft.horse_id ORDER BY name",
          ),
        );
      case 'income_source':
        return ReportData(
          title: 'تقرير الواردات حسب المصدر',
          columns: _cols(const {
            'source_type': 'المصدر',
            'category': 'الفئة',
            'count': 'العمليات',
            'total': 'الإجمالي',
          }),
          rows: await database.rawQuery(
            "SELECT source_type,category,COUNT(*) count,SUM(amount) total FROM financial_transactions WHERE type='income' GROUP BY source_type,category ORDER BY total DESC",
          ),
        );
      case 'budget_full':
        final rows = await database.rawQuery(
          """SELECT type,category,COALESCE(affects_budget,1) affects_budget,
          COALESCE(is_subscriber_debt,0) is_subscriber_debt,
          COALESCE(debt_settled,0) debt_settled,COUNT(*) count,SUM(amount) total
          FROM financial_transactions
          GROUP BY type,category,COALESCE(affects_budget,1),
          COALESCE(is_subscriber_debt,0),COALESCE(debt_settled,0)
          ORDER BY type DESC,total DESC""",
        );
        final totals = await database.rawQuery("""SELECT
          COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END),0) income,
          COALESCE(SUM(CASE WHEN type='expense' AND COALESCE(affects_budget,1)=1 THEN amount ELSE 0 END),0) expense,
          COALESCE(SUM(CASE WHEN type='expense' AND COALESCE(affects_budget,1)=0 THEN amount ELSE 0 END),0) excluded,
          COALESCE(SUM(CASE WHEN COALESCE(is_subscriber_debt,0)=1 AND COALESCE(debt_settled,0)=0 THEN amount ELSE 0 END),0) debt
          FROM financial_transactions""");
        final income = (totals.first['income'] as num?)?.toDouble() ?? 0;
        final expense = (totals.first['expense'] as num?)?.toDouble() ?? 0;
        return ReportData(
          title: 'تقرير الميزانية الشامل',
          columns: _cols(const {
            'type': 'النوع',
            'category': 'المصدر/الفئة',
            'affects_budget': 'يدخل الميزانية',
            'is_subscriber_debt': 'دين مشترك',
            'debt_settled': 'مسدد',
            'count': 'العمليات',
            'total': 'الإجمالي',
          }),
          rows: rows,
          summary: [
            'الوارد: ${income.toStringAsFixed(2)} ر.س',
            'المخصوم: ${expense.toStringAsFixed(2)} ر.س',
            'غير المخصوم: ${((totals.first['excluded'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} ر.س',
            'ديون المشتركين: ${((totals.first['debt'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} ر.س',
            'الصافي: ${(income - expense).toStringAsFixed(2)} ر.س',
          ],
        );
      default:
        throw ArgumentError.value(key, 'key', 'تقرير غير معروف');
    }
  }

  Future<ReportData> loadSubscriberComplete(
    int subscriberId, {
    String period = 'all',
  }) async {
    final database = DatabaseService.instance.db;
    final subscriber = await DatabaseService.instance.row(
      'subscribers',
      subscriberId,
    );
    if (subscriber == null) throw const FormatException('المشترك غير موجود');
    final horses = await DatabaseService.instance.subscriberHorses(
      subscriberId,
    );
    final horseIds = horses.map((row) => row['id'] as int).toList();
    final history = await database.rawQuery(
      "SELECT * FROM subscription_history WHERE subscriber_id=? ${_periodSql(period, 'start_date')} ORDER BY start_date DESC",
      [subscriberId],
    );
    final payments = await database.rawQuery(
      "SELECT * FROM payments WHERE subscriber_id=? ${_periodSql(period, 'payment_date')} ORDER BY payment_date DESC",
      [subscriberId],
    );
    final financeWhere = horseIds.isEmpty
        ? 'subscriber_id=?'
        : '(subscriber_id=? OR horse_id IN (${List.filled(horseIds.length, '?').join(',')}))';
    final finance = await database.rawQuery(
      "SELECT * FROM financial_transactions WHERE $financeWhere ${_periodSql(period, 'transaction_date')} ORDER BY transaction_date DESC",
      [subscriberId, ...horseIds],
    );
    final contracts = await database.rawQuery(
      "SELECT * FROM boarding_contracts WHERE subscriber_id=? ${_periodSql(period, 'signed_date')} ORDER BY signed_date DESC",
      [subscriberId],
    );
    final images = <ReportImage>[
      if ('${subscriber['image_path'] ?? ''}'.isNotEmpty)
        ReportImage(
          'صورة المشترك - ${subscriber['name']}',
          '${subscriber['image_path']}',
        ),
      ...await _horseImages(horses, period),
    ];
    final paid = _sum(payments, 'amount');
    final income = finance
        .where((row) => row['type'] == 'income')
        .fold<double>(
          0,
          (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
        );
    final expense = finance
        .where((row) => row['type'] == 'expense' && row['affects_budget'] != 0)
        .fold<double>(
          0,
          (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
        );
    return ReportData(
      title:
          'الملف الشامل للمشترك - ${subscriber['name']} (${_periodLabel(period)})',
      columns: _cols(const {
        'member_code': 'رقم العضوية',
        'name': 'الاسم',
        'phone': 'الجوال',
        'subscription_type': 'الاشتراك الحالي',
        'start_date': 'البداية',
        'end_date': 'النهاية',
        'status': 'الحالة',
        'is_vip': 'مميز',
      }),
      rows: [subscriber],
      summary: [
        'عدد الاشتراكات: ${history.length + 1}',
        'عدد الخيول: ${horses.length}',
        'عدد الدفعات: ${payments.length}',
        'إجمالي الدفعات: ${paid.toStringAsFixed(2)} ر.س',
        'الوارد المرتبط: ${income.toStringAsFixed(2)} ر.س',
        'المصروف المؤثر: ${expense.toStringAsFixed(2)} ر.س',
      ],
      sections: [
        ReportSection(
          title: 'سجل الاشتراكات السابقة',
          columns: _cols(const {
            'subscription_number': 'رقم',
            'subscription_type': 'النوع',
            'duration': 'المدة',
            'amount': 'القيمة',
            'start_date': 'البداية',
            'end_date': 'النهاية',
            'status': 'الحالة',
          }),
          rows: history,
        ),
        ReportSection(
          title: 'سجل الدفعات',
          columns: _cols(const {
            'payment_date': 'التاريخ',
            'amount': 'المبلغ',
            'payment_method': 'الطريقة',
            'notes': 'ملاحظات',
          }),
          rows: payments,
        ),
        ReportSection(
          title: 'الخيول التابعة للمشترك',
          columns: _cols(const {
            'name': 'الخيل',
            'breed': 'السلالة',
            'gender': 'الجنس',
            'ownership_type': 'الملكية',
            'stable_location': 'الموقع',
            'health_status': 'الصحة',
          }),
          rows: horses,
        ),
        ReportSection(
          title: 'السجل المالي المرتبط',
          columns: _cols(const {
            'transaction_date': 'التاريخ',
            'type': 'النوع',
            'title': 'البيان',
            'category': 'الفئة',
            'amount': 'المبلغ',
            'affects_budget': 'يؤثر بالميزانية',
            'is_subscriber_debt': 'دين',
            'debt_settled': 'مسدد',
          }),
          rows: finance,
        ),
        ReportSection(
          title: 'عقود الإيواء',
          columns: _cols(const {
            'horse_name': 'الخيل',
            'signed_date': 'التوقيع',
            'pdf_path': 'ملف العقد',
          }),
          rows: contracts,
        ),
      ],
      images: images,
    );
  }

  Future<ReportData> loadHorseComplete(
    int horseId, {
    String period = 'all',
  }) async {
    final database = DatabaseService.instance.db;
    final horse = await DatabaseService.instance.row('horses', horseId);
    if (horse == null) throw const FormatException('الخيل غير موجود');
    final subscriberRows = await database.rawQuery(
      'SELECT DISTINCT s.* FROM subscribers s WHERE s.id=? OR s.horse_id=? LIMIT 1',
      [horse['subscriber_id'] ?? -1, horseId],
    );
    final subscriber = subscriberRows.firstOrNull;
    final subscriberId = subscriber?['id'] as int?;
    Future<List<Map<String, Object?>>> records(
      String table,
      String dateColumn,
      String orderBy,
    ) => database.rawQuery(
      "SELECT * FROM $table WHERE horse_id=? ${_periodSql(period, dateColumn)} ORDER BY $orderBy DESC",
      [horseId],
    );
    final health = await records(
      'health_records',
      'record_date',
      'record_date',
    );
    final appointments = await records(
      'appointments',
      'appointment_date',
      'appointment_date',
    );
    final farrier = await records(
      'farrier_records',
      'last_visit',
      'last_visit',
    );
    final notes = await records('daily_notes', 'note_date', 'note_date');
    final expenses = await records('expenses', 'expense_date', 'expense_date');
    final treatments = await records(
      'treatment_records',
      'treatment_date',
      'treatment_date',
    );
    final boarding = await records(
      'boarding_payments',
      'payment_date',
      'payment_date',
    );
    final finance = await database.rawQuery(
      "SELECT * FROM financial_transactions WHERE horse_id=? ${_periodSql(period, 'transaction_date')} ORDER BY transaction_date DESC",
      [horseId],
    );
    final history = subscriberId == null
        ? <Map<String, Object?>>[]
        : await database.rawQuery(
            "SELECT * FROM subscription_history WHERE subscriber_id=? ${_periodSql(period, 'start_date')} ORDER BY start_date DESC",
            [subscriberId],
          );
    final payments = subscriberId == null
        ? <Map<String, Object?>>[]
        : await database.rawQuery(
            "SELECT * FROM payments WHERE subscriber_id=? ${_periodSql(period, 'payment_date')} ORDER BY payment_date DESC",
            [subscriberId],
          );
    final images = await _horseImages([horse], period);
    if (subscriber != null && '${subscriber['image_path'] ?? ''}'.isNotEmpty) {
      images.insert(
        0,
        ReportImage(
          'صورة المشترك - ${subscriber['name']}',
          '${subscriber['image_path']}',
        ),
      );
    }
    final allActivities =
        health.length +
        appointments.length +
        farrier.length +
        notes.length +
        expenses.length +
        treatments.length +
        boarding.length;
    return ReportData(
      title: 'الملف الشامل للخيل - ${horse['name']} (${_periodLabel(period)})',
      columns: _cols(const {
        'name': 'الاسم',
        'breed': 'السلالة',
        'gender': 'الجنس',
        'color': 'اللون',
        'chip_id': 'الشريحة',
        'birth_date': 'الميلاد',
        'ownership_type': 'الملكية',
        'stable_location': 'الموقع',
        'health_status': 'الصحة',
      }),
      rows: [horse],
      summary: [
        'المشترك: ${subscriber?['name'] ?? 'لا يوجد'}',
        'السجلات خلال الفترة: $allActivities',
        'المصاريف المسجلة: ${_sum(expenses, 'amount').toStringAsFixed(2)} ر.س',
        'العلاجات: ${_sum(treatments, 'amount').toStringAsFixed(2)} ر.س',
        'دفعات الإيواء: ${_sum(boarding, 'amount').toStringAsFixed(2)} ر.س',
      ],
      sections: [
        ReportSection(
          title: 'المشترك المرتبط',
          columns: _cols(const {
            'member_code': 'العضوية',
            'name': 'الاسم',
            'phone': 'الجوال',
            'subscription_type': 'الاشتراك',
            'end_date': 'النهاية',
            'status': 'الحالة',
          }),
          rows: subscriber == null ? const [] : [subscriber],
        ),
        ReportSection(
          title: 'السجل الصحي',
          columns: _cols(const {
            'record_date': 'التاريخ',
            'record_type': 'النوع',
            'title': 'العنوان',
            'vet_name': 'الطبيب',
            'next_date': 'التالي',
            'description': 'التفاصيل',
          }),
          rows: health,
        ),
        ReportSection(
          title: 'العلاجات والأدوية',
          columns: _cols(const {
            'treatment_date': 'التاريخ',
            'treatment_type': 'النوع',
            'medicine_name': 'العلاج',
            'amount': 'المبلغ',
            'payer_type': 'الدافع',
            'charge_to_subscriber': 'دين مشترك',
          }),
          rows: treatments,
        ),
        ReportSection(
          title: 'المواعيد والتنبيهات',
          columns: _cols(const {
            'appointment_date': 'التاريخ',
            'appointment_type': 'النوع',
            'title': 'العنوان',
            'status': 'الحالة',
            'description': 'التفاصيل',
          }),
          rows: appointments,
        ),
        ReportSection(
          title: 'التحذية',
          columns: _cols(const {
            'last_visit': 'آخر زيارة',
            'next_visit': 'القادمة',
            'shoe_type': 'النوع',
            'farrier_name': 'البيطار',
            'cost': 'التكلفة',
            'notes': 'ملاحظات',
          }),
          rows: farrier,
        ),
        ReportSection(
          title: 'التمارين والمتابعة اليومية',
          columns: _cols(const {
            'note_date': 'التاريخ',
            'appetite': 'الشهية',
            'activity': 'النشاط',
            'behavior': 'السلوك',
            'symptoms': 'الأعراض',
            'general_notes': 'الملاحظات',
          }),
          rows: notes,
        ),
        ReportSection(
          title: 'الإيواء والغرفة',
          columns: _cols(const {
            'payment_date': 'التاريخ',
            'room_number': 'الغرفة',
            'amount': 'المبلغ',
            'due_date': 'الاستحقاق',
            'is_paid': 'مسدد',
            'notes': 'ملاحظات',
          }),
          rows: boarding,
        ),
        ReportSection(
          title: 'المصاريف',
          columns: _cols(const {
            'expense_date': 'التاريخ',
            'category': 'الفئة',
            'description': 'الوصف',
            'amount': 'المبلغ',
            'payer_type': 'الدافع',
            'affects_budget': 'يخصم',
            'charge_to_subscriber': 'دين',
          }),
          rows: expenses,
        ),
        ReportSection(
          title: 'السجل المالي',
          columns: _cols(const {
            'transaction_date': 'التاريخ',
            'type': 'النوع',
            'title': 'البيان',
            'category': 'الفئة',
            'amount': 'المبلغ',
            'affects_budget': 'يؤثر',
            'is_subscriber_debt': 'دين',
            'debt_settled': 'مسدد',
          }),
          rows: finance,
        ),
        ReportSection(
          title: 'اشتراكات المشترك المرتبط',
          columns: _cols(const {
            'subscription_number': 'رقم',
            'subscription_type': 'النوع',
            'amount': 'القيمة',
            'start_date': 'البداية',
            'end_date': 'النهاية',
            'status': 'الحالة',
          }),
          rows: history,
        ),
        ReportSection(
          title: 'دفعات المشترك المرتبط',
          columns: _cols(const {
            'payment_date': 'التاريخ',
            'amount': 'المبلغ',
            'payment_method': 'الطريقة',
            'notes': 'ملاحظات',
          }),
          rows: payments,
        ),
      ],
      images: images,
    );
  }

  Future<List<ReportImage>> _horseImages(
    List<Map<String, Object?>> horses,
    String period,
  ) async {
    final result = <ReportImage>[];
    final seen = <String>{};
    for (final horse in horses) {
      final path = '${horse['image_path'] ?? ''}';
      if (path.isNotEmpty && seen.add(path)) {
        result.add(ReportImage('صورة الخيل - ${horse['name']}', path));
      }
    }
    final ids = horses.map((row) => row['id'] as int).toList();
    if (ids.isEmpty) return result;
    final placeholders = List.filled(ids.length, '?').join(',');
    const sources = <(String, String, String)>[
      ('health_records', 'record_date', 'سجل صحي'),
      ('appointments', 'appointment_date', 'موعد'),
      ('farrier_records', 'last_visit', 'تحذية'),
      ('daily_notes', 'note_date', 'تمرين ومتابعة'),
      ('expenses', 'expense_date', 'مصروف وخدمة'),
      ('treatment_records', 'treatment_date', 'علاج'),
      ('boarding_payments', 'payment_date', 'إيواء وغرفة'),
    ];
    for (final source in sources) {
      final rows = await DatabaseService.instance.db.rawQuery(
        "SELECT horse_id,image_path FROM ${source.$1} WHERE horse_id IN ($placeholders) AND image_path IS NOT NULL AND trim(image_path)<>'' ${_periodSql(period, source.$2)} ORDER BY ${source.$2} DESC",
        ids,
      );
      for (final row in rows) {
        final path = '${row['image_path']}';
        if (seen.add(path))
          result.add(
            ReportImage('${source.$3} للخيل رقم ${row['horse_id']}', path),
          );
      }
    }
    return result;
  }

  static String _periodSql(String period, String column) => switch (period) {
    'week' => "AND $column>=date('now','localtime','-6 days')",
    'month' => "AND $column>=date('now','localtime','-29 days')",
    _ => '',
  };

  static String _periodLabel(String period) => switch (period) {
    'week' => 'آخر 7 أيام',
    'month' => 'آخر 30 يومًا',
    _ => 'كامل السجل',
  };

  Future<Uint8List> buildPdf(ReportData data) async {
    final fontData = await rootBundle.load('assets/fonts/NotoSansArabic.ttf');
    final font = pw.Font.ttf(fontData);
    final clubName = await _clubName();
    final logoBytes = await _settingImage('report_logo');
    final clubSignatureBytes = await _settingImage('club_signature');
    final reportImages = <MapEntry<String, Uint8List>>[];
    for (final image in data.images) {
      final file = File(image.path);
      if (image.path.isEmpty || !await file.exists()) continue;
      try {
        reportImages.add(MapEntry(image.label, await file.readAsBytes()));
      } catch (_) {
        // لا يمنع ملف صورة تالف إنشاء بقية التقرير.
      }
    }
    final document = pw.Document(
      title: data.title,
      author: clubName,
      creator: 'Sayes Alkhayl Mobile',
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFC9A56A)),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  if (logoBytes != null) ...[
                    pw.Image(pw.MemoryImage(logoBytes), width: 34, height: 34),
                    pw.SizedBox(width: 7),
                  ],
                  pw.Text(
                    clubName,
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: const PdfColor.fromInt(0xFF10233F),
                    ),
                  ),
                ],
              ),
              pw.Text(
                data.title,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'صفحة ${context.pageNumber} من ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 12),
          if (data.summary.isNotEmpty)
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: data.summary
                  .map(
                    (text) => pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFFF4EBDD),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(text),
                    ),
                  )
                  .toList(),
            ),
          pw.SizedBox(height: 12),
          if (data.rows.isEmpty)
            pw.Center(child: pw.Text('لا توجد بيانات'))
          else
            _reportTable(data.columns, data.rows),
          ...data.sections.expand(
            (section) => <pw.Widget>[
              pw.SizedBox(height: 18),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 7,
                ),
                color: const PdfColor.fromInt(0xFFF4EBDD),
                child: pw.Text(
                  section.title,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              if (section.rows.isEmpty)
                pw.Text('لا توجد بيانات في هذا القسم')
              else
                _reportTable(section.columns, section.rows),
            ],
          ),
          if (reportImages.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'الصور والمرفقات المرئية',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            ...reportImages.map(
              (entry) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(7),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: const PdfColor.fromInt(0xFFD7DDE5),
                  ),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      entry.key,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Center(
                      child: pw.Image(
                        pw.MemoryImage(entry.value),
                        height: 190,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (clubSignatureBytes != null) ...[
            pw.SizedBox(height: 22),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Column(
                children: [
                  pw.Text(
                    'توقيع النادي',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Image(
                    pw.MemoryImage(clubSignatureBytes),
                    width: 145,
                    height: 72,
                    fit: pw.BoxFit.contain,
                  ),
                  pw.Text(clubName, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
    return document.save();
  }

  Future<File> saveReport(ReportData data) async {
    final directory = Directory(
      p.join(DatabaseService.instance.appDirectory.path, 'reports'),
    );
    await directory.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final safe = AppValidators.text(
      data.title,
      max: 50,
    ).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File(p.join(directory.path, '${safe}_$stamp.pdf'));
    await file.writeAsBytes(await buildPdf(data), flush: true);
    return file;
  }

  Future<Uint8List> buildDailyReceipt(Map<String, Object?> booking) async {
    return buildPdf(
      ReportData(
        title: 'إيصال حجز يومي',
        columns: _cols(const {
          'customer_name': 'العميل',
          'phone': 'الجوال',
          'service_type': 'الخدمة',
          'duration_minutes': 'المدة بالدقائق',
          'price': 'المبلغ',
          'booking_date': 'التاريخ',
          'booking_time': 'الوقت',
        }),
        rows: [booking],
        summary: const ['شكرًا لاختياركم خدمات النادي'],
      ),
    );
  }

  Future<Uint8List> buildBoardingContract({
    required String subscriberName,
    required String horseName,
    required String contractText,
    required String signedDate,
    required String signaturePath,
  }) async {
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic.ttf'),
    );
    final signature = File(signaturePath);
    final signatureBytes = await signature.exists()
        ? await signature.readAsBytes()
        : null;
    final clubName = await _clubName();
    final logoBytes = await _settingImage('report_logo');
    final clubSignatureBytes = await _settingImage('club_signature');
    final sealBytes = await _settingImage('club_seal');
    final document = pw.Document(
      title: 'عقد إيواء - $subscriberName',
      author: clubName,
    );
    document.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (_) => [
          if (logoBytes != null)
            pw.Center(
              child: pw.Image(pw.MemoryImage(logoBytes), width: 74, height: 74),
            ),
          pw.Center(
            child: pw.Text(
              clubName,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Center(
            child: pw.Text(
              'عقد الإيواء الإلكتروني',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text('المشترك: $subscriberName'),
          pw.Text('الخيل: $horseName'),
          pw.Text('تاريخ التوقيع: $signedDate'),
          pw.Divider(),
          pw.Text(contractText, textAlign: pw.TextAlign.right),
          pw.SizedBox(height: 24),
          pw.Text('التوقيع الإلكتروني:'),
          if (signatureBytes != null)
            pw.Image(pw.MemoryImage(signatureBytes), width: 180, height: 90),
          if (clubSignatureBytes != null) ...[
            pw.SizedBox(height: 12),
            pw.Text('توقيع النادي:'),
            pw.Image(
              pw.MemoryImage(clubSignatureBytes),
              width: 180,
              height: 90,
            ),
          ],
          if (sealBytes != null) ...[
            pw.SizedBox(height: 12),
            pw.Text('ختم المنشأة:'),
            pw.Image(pw.MemoryImage(sealBytes), width: 110, height: 110),
          ],
        ],
      ),
    );
    return document.save();
  }

  Future<Uint8List?> _settingImage(String key) async {
    final path = await DatabaseService.instance.getSetting(key);
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    return await file.exists() ? file.readAsBytes() : null;
  }

  Future<String> _clubName() async {
    final value = (await DatabaseService.instance.getSetting(
      'club_name',
    ))?.trim();
    return value == null || value.isEmpty ? 'نادي الخيل' : value;
  }

  static List<MapEntry<String, String>> _cols(Map<String, String> value) =>
      value.entries.toList();
  static pw.Widget _reportTable(
    List<MapEntry<String, String>> columns,
    List<Map<String, Object?>> rows,
  ) => pw.TableHelper.fromTextArray(
    headers: columns.map((entry) => entry.value).toList(),
    data: rows
        .map(
          (row) => columns
              .map((entry) => _displayField(entry.key, row[entry.key]))
              .toList(),
        )
        .toList(),
    headerStyle: pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
      fontSize: 8,
    ),
    headerDecoration: const pw.BoxDecoration(
      color: PdfColor.fromInt(0xFF10233F),
    ),
    cellStyle: const pw.TextStyle(fontSize: 7),
    cellAlignment: pw.Alignment.centerRight,
    oddRowDecoration: const pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFF8F5EE),
    ),
    border: pw.TableBorder.all(
      color: const PdfColor.fromInt(0xFFD7DDE5),
      width: .4,
    ),
  );
  static String _display(Object? value) {
    if (value == null) return '';
    if (value is num)
      return value is double ? value.toStringAsFixed(2) : '$value';
    final text = '$value';
    return text == 'income'
        ? 'وارد'
        : text == 'expense'
        ? 'مصروف'
        : text == '1'
        ? 'نعم'
        : text == '0'
        ? 'لا'
        : text;
  }

  static String _displayField(String key, Object? value) {
    if (const {
      'affects_budget',
      'is_subscriber_debt',
      'debt_settled',
      'charge_to_subscriber',
    }.contains(key)) {
      return value == 1 ? 'نعم' : 'لا';
    }
    if (key == 'is_paid') return value == 1 ? 'مسدد' : 'غير مسدد';
    if (key == 'is_vip') return value == 1 ? 'مميز' : 'عادي';
    if (value == 'owner') return 'صاحب الخيل';
    if (value == 'stable') return 'النادي';
    return _display(value);
  }

  static double _sum(List<Map<String, Object?>> rows, String key) =>
      rows.fold(0, (sum, row) => sum + ((row[key] as num?)?.toDouble() ?? 0));
  static List<String> _financialSummary(List<Map<String, Object?>> rows) {
    final income = rows
        .where((row) => row['type'] == 'income')
        .fold<double>(
          0,
          (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
        );
    final expense = rows
        .where((row) => row['type'] == 'expense' && row['affects_budget'] != 0)
        .fold<double>(
          0,
          (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
        );
    return [
      'الواردات: ${income.toStringAsFixed(2)} ر.س',
      'المصاريف: ${expense.toStringAsFixed(2)} ر.س',
      'الصافي: ${(income - expense).toStringAsFixed(2)} ر.س',
    ];
  }
}
