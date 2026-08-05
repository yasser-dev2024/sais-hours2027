import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../core/validators.dart';
import 'schema.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;
  late String _databasePath;
  late Directory _appDirectory;

  Database get db {
    final value = _database;
    if (value == null) throw StateError('قاعدة البيانات غير مهيأة');
    return value;
  }

  String get databasePath => _databasePath;
  Directory get appDirectory => _appDirectory;

  Future<void> initialize() async {
    if (_database != null) return;
    final documents = await getApplicationDocumentsDirectory();
    _appDirectory = Directory(p.join(documents.path, 'horse_club_mobile'));
    await _appDirectory.create(recursive: true);
    _databasePath = p.join(_appDirectory.path, AppConstants.databaseName);
    _database = await openDatabase(
      _databasePath,
      version: AppConstants.databaseVersion,
      onConfigure: (database) async {
        await database.rawQuery('PRAGMA foreign_keys=ON');
        await database.rawQuery('PRAGMA journal_mode=WAL');
        await database.rawQuery('PRAGMA secure_delete=ON');
        await database.rawQuery('PRAGMA busy_timeout=5000');
      },
      onCreate: (database, _) => _ensureSchema(database),
      onUpgrade: (database, _, __) => _ensureSchema(database),
      onOpen: _ensureSchema,
    );
    await _insertDefaultSettings();
    await _reconcilePaymentSources();
    await autoUpdateSubscriberStatuses();
  }

  @visibleForTesting
  Future<void> initializeForTesting({
    required Database database,
    required Directory appDirectory,
  }) async {
    await _database?.close();
    _database = database;
    _appDirectory = appDirectory;
    await _appDirectory.create(recursive: true);
    _databasePath = database.path;
    await database.execute('PRAGMA foreign_keys=ON');
    await _ensureSchema(database);
    await _insertDefaultSettings();
    await _reconcilePaymentSources();
    await autoUpdateSubscriberStatuses();
  }

  Future<void> _ensureSchema(Database database) async {
    for (final statement in DatabaseSchema.statements) {
      await database.execute(statement);
    }
    await _ensureColumn(
      database,
      'horses',
      'ownership_type',
      "TEXT DEFAULT 'إيواء'",
    );
    await _ensureColumn(database, 'horses', 'subscriber_id', 'INTEGER');
    await _ensureColumn(database, 'subscribers', 'image_path', 'TEXT');
    await _ensureColumn(database, 'subscribers', 'horse_id', 'INTEGER');
    await _ensureColumn(database, 'subscribers', 'member_code', 'TEXT');
    await _ensureColumn(database, 'subscribers', 'is_vip', 'INTEGER DEFAULT 0');
    await _ensureColumn(database, 'payments', 'horse_id', 'INTEGER');
    await _ensureColumn(database, 'payments', 'boarding_payment_id', 'INTEGER');
    await _ensureColumn(
      database,
      'boarding_payments',
      'subscriber_id',
      'INTEGER',
    );
    await _ensureColumn(
      database,
      'boarding_payments',
      'payment_method',
      'TEXT',
    );
    await _ensureColumn(database, 'boarding_payments', 'payment_id', 'INTEGER');
    await _ensureColumn(database, 'expenses', 'invoice_path', 'TEXT');
    await _ensureColumn(
      database,
      'expenses',
      'payer_type',
      "TEXT DEFAULT 'owner'",
    );
    await _ensureColumn(database, 'expenses', 'is_paid', 'INTEGER DEFAULT 1');
    await _ensureColumn(
      database,
      'expenses',
      'affects_budget',
      'INTEGER DEFAULT 1',
    );
    await _ensureColumn(
      database,
      'expenses',
      'charge_to_subscriber',
      'INTEGER DEFAULT 0',
    );
    await _ensureColumn(
      database,
      'expenses',
      'debt_settled',
      'INTEGER DEFAULT 0',
    );
    await _ensureColumn(database, 'farrier_records', 'image_path', 'TEXT');
    await _ensureColumn(database, 'farrier_records', 'expense_id', 'INTEGER');
    await _ensureColumn(database, 'health_records', 'expense_id', 'INTEGER');
    await _ensureColumn(database, 'health_records', 'image_path', 'TEXT');
    await _ensureColumn(database, 'appointments', 'image_path', 'TEXT');
    await _ensureColumn(database, 'daily_notes', 'image_path', 'TEXT');
    await _ensureColumn(database, 'expenses', 'image_path', 'TEXT');
    await _ensureColumn(database, 'daily_bookings', 'image_path', 'TEXT');
    await _ensureColumn(database, 'boarding_payments', 'image_path', 'TEXT');
    await _ensureColumn(database, 'treatment_records', 'image_path', 'TEXT');
    await _ensureColumn(
      database,
      'treatment_records',
      'payer_type',
      "TEXT DEFAULT 'stable'",
    );
    await _ensureColumn(
      database,
      'treatment_records',
      'affects_budget',
      'INTEGER DEFAULT 1',
    );
    await _ensureColumn(
      database,
      'treatment_records',
      'charge_to_subscriber',
      'INTEGER DEFAULT 0',
    );
    await _ensureColumn(
      database,
      'treatment_records',
      'debt_settled',
      'INTEGER DEFAULT 0',
    );
    await _ensureColumn(
      database,
      'stable_general_expenses',
      'affects_budget',
      'INTEGER DEFAULT 1',
    );
    await _ensureColumn(
      database,
      'financial_transactions',
      'affects_budget',
      'INTEGER DEFAULT 1',
    );
    await _ensureColumn(
      database,
      'financial_transactions',
      'is_subscriber_debt',
      'INTEGER DEFAULT 0',
    );
    await _ensureColumn(
      database,
      'financial_transactions',
      'debt_settled',
      'INTEGER DEFAULT 0',
    );
    await _ensureColumn(
      database,
      'boarding_contracts',
      'pdf_path',
      "TEXT DEFAULT ''",
    );
    await database.execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_subscriber_member_code ON subscribers(member_code) WHERE member_code IS NOT NULL AND member_code<>''",
    );
    await database.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_boarding_link ON payments(boarding_payment_id) WHERE boarding_payment_id IS NOT NULL',
    );
    await database.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_boarding_payment_link ON boarding_payments(payment_id) WHERE payment_id IS NOT NULL',
    );
    await database.rawUpdate(
      "UPDATE subscribers SET member_code='S-' || printf('%05d',id) WHERE member_code IS NULL OR trim(member_code)=''",
    );
    await database.rawUpdate(
      "UPDATE subscribers SET is_vip=1 WHERE COALESCE(is_vip,0)=0 AND (amount>=10000 OR notes LIKE '%مميز%')",
    );
  }

  Future<void> _ensureColumn(
    Database database,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await database.rawQuery('PRAGMA table_info("$table")');
    if (!columns.any((row) => row['name'] == column)) {
      await database.execute(
        'ALTER TABLE "$table" ADD COLUMN "$column" $definition',
      );
    }
  }

  Future<void> _insertDefaultSettings() async {
    const values = <String, String>{
      'app_name': 'سايس الخيل',
      'club_name': 'نادي الخيل',
      'reminder_days': '3',
      'subscription_alert_days': '7',
      'primary_color': '#10233F',
      'accent_color': '#C9A56A',
      'danger_color': '#C94141',
      'warning_color': '#D99B2B',
      'success_color': '#21845A',
      'price_training_5': '50',
      'price_training_10': '80',
      'price_training_15': '100',
      'price_training_30': '150',
      'price_training_60': '250',
      'price_riding_5': '50',
      'price_riding_10': '80',
      'price_riding_15': '100',
      'price_riding_30': '150',
      'price_riding_60': '250',
      'price_shooting_5': '60',
      'price_shooting_10': '100',
      'price_shooting_15': '130',
      'price_shooting_30': '200',
      'price_shooting_60': '350',
    };
    final batch = db.batch();
    for (final entry in values.entries) {
      batch.rawInsert('INSERT OR IGNORE INTO settings(key,value) VALUES(?,?)', [
        entry.key,
        entry.value,
      ]);
    }
    await batch.commit(noResult: true);
    await db.insert('settings', {
      'key': 'app_name',
      'value': 'سايس الخيل',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  void _checkTable(String table) {
    if (!DatabaseSchema.columns.containsKey(table)) {
      throw ArgumentError.value(table, 'table', 'جدول غير مسموح');
    }
  }

  Map<String, Object?> _validatedData(
    String table,
    Map<String, Object?> input, {
    bool enforceRequired = true,
  }) {
    _checkTable(table);
    final allowed = DatabaseSchema.columns[table]!;
    final result = <String, Object?>{};
    for (final entry in input.entries) {
      if (!allowed.contains(entry.key)) continue;
      var value = entry.value;
      if (value is String) {
        if (entry.key.contains('notes') || entry.key == 'contract_text') {
          value = AppValidators.text(
            value,
            max: entry.key == 'contract_text' ? 20000 : 2000,
          );
        } else if (entry.key == 'name' || entry.key.endsWith('_name')) {
          value = AppValidators.name(value);
        } else if (entry.key == 'phone') {
          value = AppValidators.phone(value);
        } else {
          value = AppValidators.text(value);
        }
      }
      result[entry.key] = value;
    }

    final required =
        <String, List<String>>{
          'horses': ['name'],
          'subscribers': ['name'],
          'health_records': ['horse_id', 'record_type', 'title', 'record_date'],
          'appointments': [
            'horse_id',
            'appointment_type',
            'title',
            'appointment_date',
          ],
          'farrier_records': ['horse_id', 'last_visit'],
          'expenses': ['category', 'amount', 'expense_date'],
          'daily_notes': ['horse_id', 'note_date'],
          'daily_bookings': [
            'customer_name',
            'service_type',
            'duration_minutes',
            'price',
            'booking_date',
          ],
          'payments': ['subscriber_id', 'amount', 'payment_date'],
          'boarding_payments': ['horse_id', 'amount', 'payment_date'],
          'treatment_records': ['horse_id', 'amount', 'treatment_date'],
          'stable_general_expenses': ['category', 'amount', 'expense_date'],
          'stable_income_records': ['amount', 'income_date'],
          'financial_transactions': [
            'type',
            'amount',
            'title',
            'transaction_date',
          ],
          'boarding_contracts': ['signed_date'],
        }[table] ??
        const [];
    for (final key in required) {
      if (!enforceRequired && !result.containsKey(key)) continue;
      final value = result[key];
      if (value == null || (value is String && value.trim().isEmpty)) {
        throw FormatException('الحقل المطلوب غير مكتمل: $key');
      }
    }

    const amountKeys = {'amount', 'price', 'cost'};
    for (final key in amountKeys) {
      if (result.containsKey(key))
        result[key] = AppValidators.amount(result[key]);
    }
    if (result.containsKey('duration_minutes')) {
      result['duration_minutes'] = AppValidators.integer(
        result['duration_minutes'],
        min: 1,
        max: 1440,
      );
    }
    if (result.containsKey('reminder_days')) {
      result['reminder_days'] = AppValidators.integer(
        result['reminder_days'],
        max: 365,
      );
    }
    for (final key in result.keys.where(
      (key) => key.endsWith('_date') || key == 'due_date',
    )) {
      if (!AppValidators.validDate(result[key]))
        throw const FormatException('التاريخ غير صحيح');
    }
    if (result['ownership_type'] case final String value
        when !const {'إيواء', 'تابع للإسطبل'}.contains(value)) {
      throw const FormatException('نوع ملكية الخيل غير صحيح');
    }
    if (result['type'] case final String value
        when table == 'financial_transactions' &&
            !const {'income', 'expense'}.contains(value)) {
      throw const FormatException('نوع العملية المالية غير صحيح');
    }
    return result;
  }

  Future<List<Map<String, Object?>>> rows(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    _checkTable(table);
    return db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<Map<String, Object?>?> row(String table, int id) async {
    final result = await rows(table, where: 'id=?', whereArgs: [id], limit: 1);
    return result.isEmpty ? null : result.first;
  }

  Future<int> saveRecord(
    String table,
    Map<String, Object?> input, {
    int? id,
  }) async {
    final data = _validatedData(table, input, enforceRequired: id == null);
    return db.transaction((txn) async {
      final isNew = id == null;
      late final int recordId;
      if (isNew) {
        await _rejectDuplicateLinkedPayment(txn, table, data);
        recordId = await txn.insert(table, data);
      } else {
        recordId = id;
        await txn.update(table, data, where: 'id=?', whereArgs: [recordId]);
      }
      if (table == 'subscribers' &&
          isNew &&
          '${data['member_code'] ?? ''}'.trim().isEmpty) {
        data['member_code'] = 'S-${recordId.toString().padLeft(5, '0')}';
        await txn.update(
          table,
          {'member_code': data['member_code']},
          where: 'id=?',
          whereArgs: [recordId],
        );
      }
      final storedRows = await txn.query(
        table,
        where: 'id=?',
        whereArgs: [recordId],
        limit: 1,
      );
      final stored = Map<String, Object?>.from(storedRows.single);
      await _syncRelationships(txn, table, recordId, stored, isNew: isNew);
      await _syncFinancial(txn, table, recordId, stored, isNew: isNew);
      return recordId;
    });
  }

  Future<void> _syncRelationships(
    Transaction txn,
    String table,
    int id,
    Map<String, Object?> data, {
    required bool isNew,
  }) async {
    if (table == 'horses') {
      final subscriberId = data['subscriber_id'] as int?;
      await txn.update(
        'subscribers',
        {'horse_id': null},
        where: 'horse_id=? AND id<>?',
        whereArgs: [id, subscriberId ?? -1],
      );
      if (subscriberId != null) {
        await txn.update(
          'subscribers',
          {'horse_id': id, 'updated_at': _nowSql},
          where: 'id=?',
          whereArgs: [subscriberId],
        );
      }
    } else if (table == 'subscribers') {
      final horseId = data['horse_id'] as int?;
      await txn.update(
        'horses',
        {'subscriber_id': null},
        where: 'subscriber_id=? AND id<>?',
        whereArgs: [id, horseId ?? -1],
      );
      if (horseId != null) {
        await txn.update(
          'horses',
          {
            'subscriber_id': id,
            'owner_name': data['name'],
            'updated_at': _nowSql,
          },
          where: 'id=?',
          whereArgs: [horseId],
        );
      }
    } else if (table == 'payments') {
      await _syncPaymentLink(txn, id, data);
    } else if (table == 'boarding_payments') {
      await _syncBoardingPaymentLink(txn, id, data);
    } else if (table == 'expenses') {
      final horseId = data['horse_id'] as int?;
      final category = '${data['category'] ?? ''}';
      if (horseId != null && category == 'تحذية') {
        final found = await txn.query(
          'farrier_records',
          columns: ['id'],
          where: 'expense_id=?',
          whereArgs: [id],
          limit: 1,
        );
        final values = <String, Object?>{
          'horse_id': horseId,
          'last_visit': data['expense_date'],
          'cost': data['amount'],
          'notes': data['notes'] ?? data['description'] ?? '',
          'shoe_type': 'تحذية',
          'expense_id': id,
        };
        if (found.isEmpty) {
          await txn.insert('farrier_records', values);
        } else {
          await txn.update(
            'farrier_records',
            values,
            where: 'id=?',
            whereArgs: [found.first['id']],
          );
        }
      }
      const healthMap = <String, String>{
        'أدوية وعلاج': 'علاج',
        'بيطري': 'فحص',
        'تطعيم': 'تطعيم',
        'علاج': 'علاج',
        'إصابة': 'إصابة',
        'عملية': 'عملية',
        'فحص': 'فحص',
        'حساسية': 'حساسية',
        'دواء': 'علاج',
      };
      if (horseId != null && healthMap.containsKey(category)) {
        final found = await txn.query(
          'health_records',
          columns: ['id'],
          where: 'expense_id=?',
          whereArgs: [id],
          limit: 1,
        );
        final values = <String, Object?>{
          'horse_id': horseId,
          'record_type': healthMap[category],
          'title': data['description'] ?? category,
          'description': data['description'] ?? '',
          'record_date': data['expense_date'],
          'notes': data['notes'] ?? '',
          'expense_id': id,
        };
        if (found.isEmpty) {
          await txn.insert('health_records', values);
        } else {
          await txn.update(
            'health_records',
            values,
            where: 'id=?',
            whereArgs: [found.first['id']],
          );
        }
      }
    }
  }

  Future<Map<String, Object?>?> _subscriberPaymentContext(
    Transaction txn,
    Object? subscriberValue,
  ) async {
    final subscriberId = (subscriberValue as num?)?.toInt();
    if (subscriberId == null) return null;
    final rows = await txn.query(
      'subscribers',
      where: 'id=?',
      whereArgs: [subscriberId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final subscriber = rows.first;
    var horseId = (subscriber['horse_id'] as num?)?.toInt();
    horseId ??= Sqflite.firstIntValue(
      await txn.rawQuery(
        'SELECT id FROM horses WHERE subscriber_id=? ORDER BY id LIMIT 1',
        [subscriberId],
      ),
    );
    return {
      'subscriber_id': subscriberId,
      'horse_id': horseId,
      'is_boarding': '${subscriber['subscription_type'] ?? ''}'.contains(
        'إيواء',
      ),
    };
  }

  Future<Map<String, Object?>?> _horsePaymentContext(
    Transaction txn,
    Object? horseValue,
  ) async {
    final horseId = (horseValue as num?)?.toInt();
    if (horseId == null) return null;
    final rows = await txn.query(
      'horses',
      where: 'id=?',
      whereArgs: [horseId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    var subscriberId = (rows.first['subscriber_id'] as num?)?.toInt();
    subscriberId ??= Sqflite.firstIntValue(
      await txn.rawQuery(
        'SELECT id FROM subscribers WHERE horse_id=? ORDER BY id LIMIT 1',
        [horseId],
      ),
    );
    return {'horse_id': horseId, 'subscriber_id': subscriberId};
  }

  Future<void> _rejectDuplicateLinkedPayment(
    Transaction txn,
    String table,
    Map<String, Object?> data,
  ) async {
    if (table == 'payments') {
      final context = await _subscriberPaymentContext(
        txn,
        data['subscriber_id'],
      );
      if (context == null ||
          context['is_boarding'] != true ||
          context['horse_id'] == null) {
        return;
      }
      final duplicate = await txn.query(
        'boarding_payments',
        columns: ['id'],
        where:
            'horse_id=? AND amount=? AND payment_date=? AND is_paid=1 AND payment_id IS NOT NULL',
        whereArgs: [context['horse_id'], data['amount'], data['payment_date']],
        limit: 1,
      );
      if (duplicate.isNotEmpty) {
        throw const FormatException(
          'هذه الدفعة مسجلة بالفعل في ملف الخيل وتظهر تلقائيًا للمشترك.',
        );
      }
    } else if (table == 'boarding_payments' &&
        (data['is_paid'] as num? ?? 1) == 1) {
      final context = await _horsePaymentContext(txn, data['horse_id']);
      if (context?['subscriber_id'] == null) return;
      final duplicate = await txn.query(
        'payments',
        columns: ['id'],
        where:
            'subscriber_id=? AND amount=? AND payment_date=? AND boarding_payment_id IS NOT NULL',
        whereArgs: [
          context!['subscriber_id'],
          data['amount'],
          data['payment_date'],
        ],
        limit: 1,
      );
      if (duplicate.isNotEmpty) {
        throw const FormatException(
          'هذه الدفعة مسجلة بالفعل للمشترك وتظهر تلقائيًا في ملف الخيل.',
        );
      }
    }
  }

  Future<void> _syncPaymentLink(
    Transaction txn,
    int paymentId,
    Map<String, Object?> data,
  ) async {
    final context = await _subscriberPaymentContext(txn, data['subscriber_id']);
    var boardingId = (data['boarding_payment_id'] as num?)?.toInt();
    final shouldLink =
        context != null &&
        context['is_boarding'] == true &&
        context['horse_id'] != null;
    if (!shouldLink) {
      if (boardingId != null) {
        await _deleteFinancialByRef(txn, 'boarding_payment', boardingId);
        await txn.delete(
          'boarding_payments',
          where: 'id=? AND payment_id=?',
          whereArgs: [boardingId, paymentId],
        );
      }
      await txn.update(
        'payments',
        {'horse_id': null, 'boarding_payment_id': null},
        where: 'id=?',
        whereArgs: [paymentId],
      );
      data['horse_id'] = null;
      data['boarding_payment_id'] = null;
      return;
    }

    final boardingValues = <String, Object?>{
      'horse_id': context['horse_id'],
      'subscriber_id': context['subscriber_id'],
      'amount': data['amount'],
      'payment_date': data['payment_date'],
      'is_paid': 1,
      'payment_method': data['payment_method'],
      'notes': data['notes'] ?? '',
      'payment_id': paymentId,
    };
    if (boardingId == null ||
        await txn.update(
              'boarding_payments',
              boardingValues,
              where: 'id=?',
              whereArgs: [boardingId],
            ) ==
            0) {
      boardingId = await txn.insert('boarding_payments', boardingValues);
    }
    await txn.update(
      'payments',
      {'horse_id': context['horse_id'], 'boarding_payment_id': boardingId},
      where: 'id=?',
      whereArgs: [paymentId],
    );
    data['horse_id'] = context['horse_id'];
    data['boarding_payment_id'] = boardingId;
    await _deleteFinancialByRef(txn, 'payment', paymentId);
  }

  Future<void> _syncBoardingPaymentLink(
    Transaction txn,
    int boardingId,
    Map<String, Object?> data,
  ) async {
    final context = await _horsePaymentContext(txn, data['horse_id']);
    var paymentId = (data['payment_id'] as num?)?.toInt();
    final paid = (data['is_paid'] as num? ?? 1) == 1;
    if (!paid || context?['subscriber_id'] == null) {
      if (paymentId != null) {
        await _deleteFinancialByRef(txn, 'payment', paymentId);
        await txn.delete(
          'payments',
          where: 'id=? AND boarding_payment_id=?',
          whereArgs: [paymentId, boardingId],
        );
      }
      await txn.update(
        'boarding_payments',
        {'subscriber_id': context?['subscriber_id'], 'payment_id': null},
        where: 'id=?',
        whereArgs: [boardingId],
      );
      data['subscriber_id'] = context?['subscriber_id'];
      data['payment_id'] = null;
      return;
    }

    final paymentValues = <String, Object?>{
      'subscriber_id': context!['subscriber_id'],
      'horse_id': context['horse_id'],
      'amount': data['amount'],
      'payment_date': data['payment_date'],
      'payment_method': data['payment_method'],
      'notes': data['notes'] ?? '',
      'boarding_payment_id': boardingId,
    };
    if (paymentId == null ||
        await txn.update(
              'payments',
              paymentValues,
              where: 'id=?',
              whereArgs: [paymentId],
            ) ==
            0) {
      paymentId = await txn.insert('payments', paymentValues);
    }
    await txn.update(
      'boarding_payments',
      {'subscriber_id': context['subscriber_id'], 'payment_id': paymentId},
      where: 'id=?',
      whereArgs: [boardingId],
    );
    data['subscriber_id'] = context['subscriber_id'];
    data['payment_id'] = paymentId;
    await _deleteFinancialByRef(txn, 'payment', paymentId);
  }

  Future<void> _reconcilePaymentSources() async {
    await db.transaction((txn) async {
      // قيمة الاشتراك هي استحقاق تعاقدي وليست قبضًا ماليًا. الإيراد لا ينشأ
      // إلا من سجل دفعة فعلي في أحد الملفين.
      await txn.delete(
        'financial_transactions',
        where: "ref_type IN ('subscriber','subscription_history')",
      );

      final boardingRows = await txn.query(
        'boarding_payments',
        where: 'is_paid=1',
        orderBy: 'payment_date, id',
      );
      for (final source in boardingRows) {
        final boarding = Map<String, Object?>.from(source);
        final boardingId = (boarding['id'] as num).toInt();
        if (boarding['payment_id'] == null) {
          final context = await _horsePaymentContext(txn, boarding['horse_id']);
          final subscriberId = context?['subscriber_id'];
          if (subscriberId != null) {
            final matches = await txn.rawQuery(
              '''SELECT * FROM payments
                 WHERE subscriber_id=? AND boarding_payment_id IS NULL
                   AND amount=?
                   AND strftime('%Y-%m',payment_date)=strftime('%Y-%m',?)
                 ORDER BY CASE WHEN payment_date=? THEN 0 ELSE 1 END, id
                 LIMIT 1''',
              [
                subscriberId,
                boarding['amount'],
                boarding['payment_date'],
                boarding['payment_date'],
              ],
            );
            if (matches.isNotEmpty) {
              final payment = matches.first;
              final paymentId = (payment['id'] as num).toInt();
              await txn.update(
                'payments',
                {
                  'horse_id': boarding['horse_id'],
                  'boarding_payment_id': boardingId,
                },
                where: 'id=?',
                whereArgs: [paymentId],
              );
              await txn.update(
                'boarding_payments',
                {
                  'subscriber_id': subscriberId,
                  'payment_id': paymentId,
                  'payment_method':
                      boarding['payment_method'] ?? payment['payment_method'],
                },
                where: 'id=?',
                whereArgs: [boardingId],
              );
              boarding['subscriber_id'] = subscriberId;
              boarding['payment_id'] = paymentId;
              boarding['payment_method'] =
                  boarding['payment_method'] ?? payment['payment_method'];
              await _deleteFinancialByRef(txn, 'payment', paymentId);
            }
          }
        }
        if (boarding['payment_id'] == null) {
          await _syncBoardingPaymentLink(txn, boardingId, boarding);
        }
      }

      final unlinkedPayments = await txn.query(
        'payments',
        where: 'boarding_payment_id IS NULL',
        orderBy: 'payment_date, id',
      );
      for (final source in unlinkedPayments) {
        final payment = Map<String, Object?>.from(source);
        final context = await _subscriberPaymentContext(
          txn,
          payment['subscriber_id'],
        );
        if (context?['is_boarding'] == true && context?['horse_id'] != null) {
          await _syncPaymentLink(txn, (payment['id'] as num).toInt(), payment);
        }
      }

      final allBoarding = await txn.query('boarding_payments');
      for (final source in allBoarding) {
        final boarding = Map<String, Object?>.from(source);
        await _syncFinancial(
          txn,
          'boarding_payments',
          (boarding['id'] as num).toInt(),
          boarding,
          isNew: false,
        );
      }
      final allPayments = await txn.query('payments');
      for (final source in allPayments) {
        final payment = Map<String, Object?>.from(source);
        await _syncFinancial(
          txn,
          'payments',
          (payment['id'] as num).toInt(),
          payment,
          isNew: false,
        );
      }
    });
  }

  Future<void> _syncFinancial(
    Transaction txn,
    String table,
    int id,
    Map<String, Object?> data, {
    required bool isNew,
  }) async {
    Map<String, Object?>? tx;
    String? refType;
    switch (table) {
      case 'subscribers':
        // قيمة الاشتراك استحقاق وليست قبضًا؛ القبض ينشأ فقط من جدول الدفعات.
        await _deleteFinancialByRef(txn, 'subscriber', id);
        return;
      case 'daily_bookings':
        refType = 'booking';
        tx = {
          'type': 'income',
          'amount': data['price'],
          'title': '${data['service_type']} - ${data['customer_name']}',
          'description': data['notes'] ?? '',
          'source_type': 'booking',
          'category': '${data['service_type']}'.contains('تدريب')
              ? 'تدريب'
              : 'اشتراك يومي',
          'transaction_date': data['booking_date'],
        };
        break;
      case 'payments':
        refType = 'payment';
        final boardingId = (data['boarding_payment_id'] as num?)?.toInt();
        if (boardingId != null) {
          await _deleteFinancialByRef(txn, refType, id);
          final boarding = await txn.query(
            'boarding_payments',
            where: 'id=?',
            whereArgs: [boardingId],
            limit: 1,
          );
          if (boarding.isNotEmpty) {
            await _syncFinancial(
              txn,
              'boarding_payments',
              boardingId,
              boarding.first,
              isNew: false,
            );
          }
          return;
        }
        final sub = await txn.query(
          'subscribers',
          where: 'id=?',
          whereArgs: [data['subscriber_id']],
          limit: 1,
        );
        tx = {
          'type': 'income',
          'amount': data['amount'],
          'title': 'دفعة - ${sub.isEmpty ? '' : sub.first['name']}',
          'description': data['notes'] ?? '',
          'source_type': 'subscriber',
          'source_id': data['subscriber_id'],
          'subscriber_id': data['subscriber_id'],
          'horse_id': sub.isEmpty ? null : sub.first['horse_id'],
          'category': _subscriptionIncomeCategory(
            sub.isEmpty ? null : sub.first['subscription_type'],
          ),
          'payment_method': data['payment_method'],
          'transaction_date': data['payment_date'],
        };
        break;
      case 'boarding_payments':
        refType = 'boarding_payment';
        if ((data['is_paid'] as num? ?? 1) == 0) {
          await _deleteFinancialByRef(txn, refType, id);
          return;
        }
        final horse = await txn.query(
          'horses',
          where: 'id=?',
          whereArgs: [data['horse_id']],
          limit: 1,
        );
        tx = {
          'type': 'income',
          'amount': data['amount'],
          'title': 'دفعة إيواء - ${horse.isEmpty ? '' : horse.first['name']}',
          'description': data['notes'] ?? '',
          'source_type': 'horse',
          'source_id': data['horse_id'],
          'horse_id': data['horse_id'],
          'subscriber_id': horse.isEmpty ? null : horse.first['subscriber_id'],
          'category': 'إيواء',
          'payment_method': data['payment_method'],
          'affects_budget': 1,
          'transaction_date': data['payment_date'],
        };
        break;
      case 'treatment_records':
        refType = 'treatment';
        final horse = await txn.query(
          'horses',
          where: 'id=?',
          whereArgs: [data['horse_id']],
          limit: 1,
        );
        final stableOwned =
            horse.isNotEmpty && horse.first['ownership_type'] == 'تابع للإسطبل';
        final clubPaid = stableOwned || data['payer_type'] == 'stable';
        if (!clubPaid) {
          await _deleteFinancialByRef(txn, refType, id);
          return;
        }
        final subscriberId = horse.isEmpty
            ? null
            : (horse.first['subscriber_id'] as int?) ??
                  Sqflite.firstIntValue(
                    await txn.rawQuery(
                      'SELECT id FROM subscribers WHERE horse_id=? LIMIT 1',
                      [data['horse_id']],
                    ),
                  );
        final isDebt =
            !stableOwned &&
            data['payer_type'] == 'stable' &&
            (data['charge_to_subscriber'] as num? ?? 0) == 1;
        tx = {
          'type': 'expense',
          'amount': data['amount'],
          'title':
              'علاج - ${data['medicine_name'] ?? data['treatment_type'] ?? ''} - ${horse.isEmpty ? '' : horse.first['name']}',
          'description': data['notes'] ?? '',
          'source_type': 'horse',
          'source_id': data['horse_id'],
          'horse_id': data['horse_id'],
          'subscriber_id': subscriberId,
          'category': 'علاج',
          'transaction_date': data['treatment_date'],
          'affects_budget': data['affects_budget'] ?? 1,
          'is_subscriber_debt': isDebt ? 1 : 0,
          'debt_settled': data['debt_settled'] ?? 0,
        };
        break;
      case 'stable_general_expenses':
        refType = 'stable_expense';
        tx = {
          'type': 'expense',
          'amount': data['amount'],
          'title': data['description'] ?? data['category'],
          'description': data['notes'] ?? '',
          'source_type': 'stable',
          'category': data['category'],
          'transaction_date': data['expense_date'],
          'affects_budget': data['affects_budget'] ?? 1,
        };
        break;
      case 'stable_income_records':
        refType = 'stable_income';
        tx = {
          'type': 'income',
          'amount': data['amount'],
          'title': data['description'] ?? data['source'] ?? 'وارد',
          'description': data['notes'] ?? '',
          'source_type': 'stable',
          'category': data['source'] ?? 'أخرى',
          'transaction_date': data['income_date'],
          'affects_budget': 1,
        };
        break;
      case 'expenses':
        refType = 'expense';
        final horseId = data['horse_id'] as int?;
        var stableOwned = horseId == null;
        int? subscriberId;
        if (horseId != null) {
          final horse = await txn.query(
            'horses',
            where: 'id=?',
            whereArgs: [horseId],
            limit: 1,
          );
          stableOwned =
              horse.isNotEmpty &&
              horse.first['ownership_type'] == 'تابع للإسطبل';
          subscriberId = horse.isEmpty
              ? null
              : horse.first['subscriber_id'] as int?;
          final sub = await txn.query(
            'subscribers',
            columns: ['id'],
            where: 'horse_id=?',
            whereArgs: [horseId],
            limit: 1,
          );
          subscriberId ??= sub.isEmpty ? null : sub.first['id'] as int?;
        }
        final clubPaid = stableOwned || data['payer_type'] == 'stable';
        if (!clubPaid) {
          await _deleteFinancialByRef(txn, refType, id);
          return;
        }
        final isDebt =
            !stableOwned &&
            data['payer_type'] == 'stable' &&
            (data['charge_to_subscriber'] as num? ?? 0) == 1;
        tx = {
          'type': 'expense',
          'amount': data['amount'],
          'title': data['description'] ?? data['category'],
          'description': data['notes'] ?? '',
          'source_type': 'stable',
          'source_id': horseId,
          'horse_id': horseId,
          'subscriber_id': subscriberId,
          'category': data['category'],
          'transaction_date': data['expense_date'],
          'affects_budget': data['affects_budget'] ?? 1,
          'is_subscriber_debt': isDebt ? 1 : 0,
          'debt_settled': data['debt_settled'] ?? 0,
        };
        break;
      default:
        return;
    }
    await _upsertFinancial(txn, {...tx, 'ref_type': refType, 'ref_id': id});
  }

  Future<int?> _upsertFinancial(
    Transaction txn,
    Map<String, Object?> data,
  ) async {
    final amount = AppValidators.amount(data['amount'], allowZero: false);
    final refType = data['ref_type'] as String?;
    final refId = data['ref_id'] as int?;
    final values = <String, Object?>{
      'type': const {'income', 'expense'}.contains(data['type'])
          ? data['type']
          : 'expense',
      'amount': amount,
      'title': AppValidators.text(data['title'], max: 200),
      'description': AppValidators.notes(data['description']),
      'source_type':
          const {
            'subscriber',
            'horse',
            'stable',
            'booking',
            'manual',
          }.contains(data['source_type'])
          ? data['source_type']
          : 'manual',
      'source_id': data['source_id'],
      'subscriber_id': data['subscriber_id'],
      'horse_id': data['horse_id'],
      'category': AppValidators.text(data['category'] ?? 'أخرى', max: 100),
      'payment_method': data['payment_method'],
      'transaction_date': data['transaction_date'] ?? _today,
      'ref_type': refType,
      'ref_id': refId,
      'affects_budget': data['affects_budget'] ?? 1,
      'is_subscriber_debt': data['is_subscriber_debt'] ?? 0,
      'debt_settled': data['debt_settled'] ?? 0,
      'updated_at': _nowSql,
    };
    if (refType != null && refId != null) {
      final found = await txn.query(
        'financial_transactions',
        columns: ['id'],
        where: 'ref_type=? AND ref_id=?',
        whereArgs: [refType, refId],
        limit: 1,
      );
      if (found.isNotEmpty) {
        final id = found.first['id'] as int;
        await txn.update(
          'financial_transactions',
          values,
          where: 'id=?',
          whereArgs: [id],
        );
        return id;
      }
    }
    return txn.insert('financial_transactions', values);
  }

  Future<void> _deleteFinancialByRef(
    Transaction txn,
    String refType,
    int refId,
  ) => txn.delete(
    'financial_transactions',
    where: 'ref_type=? AND ref_id=?',
    whereArgs: [refType, refId],
  );

  Future<void> deleteRecord(String table, int id) async {
    _checkTable(table);
    await db.transaction((txn) async {
      final currentRows = await txn.query(
        table,
        where: 'id=?',
        whereArgs: [id],
        limit: 1,
      );
      final current = currentRows.isEmpty ? null : currentRows.first;
      const refs = <String, String>{
        'expenses': 'expense',
        'daily_bookings': 'booking',
        'payments': 'payment',
        'boarding_payments': 'boarding_payment',
        'treatment_records': 'treatment',
        'stable_general_expenses': 'stable_expense',
        'stable_income_records': 'stable_income',
      };
      final ref = refs[table];
      if (ref != null) await _deleteFinancialByRef(txn, ref, id);
      if (table == 'payments') {
        final boardingId = (current?['boarding_payment_id'] as num?)?.toInt();
        if (boardingId != null) {
          await _deleteFinancialByRef(txn, 'boarding_payment', boardingId);
          await txn.delete(
            'boarding_payments',
            where: 'id=? AND payment_id=?',
            whereArgs: [boardingId, id],
          );
        }
      } else if (table == 'boarding_payments') {
        final paymentId = (current?['payment_id'] as num?)?.toInt();
        if (paymentId != null) {
          await _deleteFinancialByRef(txn, 'payment', paymentId);
          await txn.delete(
            'payments',
            where: 'id=? AND boarding_payment_id=?',
            whereArgs: [paymentId, id],
          );
        }
      }
      if (table == 'expenses') {
        await txn.delete(
          'farrier_records',
          where: 'expense_id=?',
          whereArgs: [id],
        );
        await txn.delete(
          'health_records',
          where: 'expense_id=?',
          whereArgs: [id],
        );
      } else if (table == 'horses') {
        final linked = await txn.rawQuery(
          '''SELECT p.* FROM payments p
             JOIN boarding_payments bp ON bp.payment_id=p.id
             WHERE bp.horse_id=?''',
          [id],
        );
        for (final source in linked) {
          final payment = Map<String, Object?>.from(source)
            ..['horse_id'] = null
            ..['boarding_payment_id'] = null;
          final paymentId = (payment['id'] as num).toInt();
          await txn.update(
            'payments',
            {'horse_id': null, 'boarding_payment_id': null},
            where: 'id=?',
            whereArgs: [paymentId],
          );
          await _syncFinancial(
            txn,
            'payments',
            paymentId,
            payment,
            isNew: false,
          );
        }
        final boarding = await txn.query(
          'boarding_payments',
          columns: ['id'],
          where: 'horse_id=?',
          whereArgs: [id],
        );
        for (final row in boarding) {
          await _deleteFinancialByRef(
            txn,
            'boarding_payment',
            (row['id'] as num).toInt(),
          );
        }
        await txn.update(
          'financial_transactions',
          {'horse_id': null},
          where: 'horse_id=?',
          whereArgs: [id],
        );
        await txn.update(
          'subscribers',
          {'horse_id': null},
          where: 'horse_id=?',
          whereArgs: [id],
        );
      } else if (table == 'subscribers') {
        await txn.rawUpdate(
          '''UPDATE boarding_payments SET subscriber_id=NULL, payment_id=NULL
             WHERE subscriber_id=? OR payment_id IN
               (SELECT id FROM payments WHERE subscriber_id=?)''',
          [id, id],
        );
        await txn.update(
          'financial_transactions',
          {'subscriber_id': null},
          where: 'subscriber_id=?',
          whereArgs: [id],
        );
        await txn.update(
          'horses',
          {'subscriber_id': null},
          where: 'subscriber_id=?',
          whereArgs: [id],
        );
      }
      await txn.delete(table, where: 'id=?', whereArgs: [id]);
    });
  }

  Future<void> markPaid(String table, int id, bool paid) async {
    if (!const {
      'expenses',
      'boarding_payments',
      'treatment_records',
    }.contains(table)) {
      throw ArgumentError('لا يمكن تغيير حالة السداد لهذا الجدول');
    }
    await db.transaction((txn) async {
      await txn.update(
        table,
        {'is_paid': paid ? 1 : 0},
        where: 'id=?',
        whereArgs: [id],
      );
      if (table == 'boarding_payments') {
        final record = await txn.query(
          table,
          where: 'id=?',
          whereArgs: [id],
          limit: 1,
        );
        if (record.isNotEmpty) {
          final data = Map<String, Object?>.from(record.first);
          await _syncRelationships(txn, table, id, data, isNew: false);
          await _syncFinancial(txn, table, id, data, isNew: false);
        }
      }
    });
  }

  Future<void> renewSubscription(
    int subscriberId,
    Map<String, Object?> input,
  ) async {
    final data = _validatedData('subscribers', input, enforceRequired: false);
    await db.transaction((txn) async {
      final rows = await txn.query(
        'subscribers',
        where: 'id=?',
        whereArgs: [subscriberId],
        limit: 1,
      );
      if (rows.isEmpty) throw const FormatException('المشترك غير موجود');
      final current = rows.first;
      final count =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM subscription_history WHERE subscriber_id=?',
              [subscriberId],
            ),
          ) ??
          0;
      await txn.insert('subscription_history', {
        'subscriber_id': subscriberId,
        'subscription_number': count + 1,
        'subscription_type': current['subscription_type'],
        'duration': current['duration'],
        'amount': current['amount'],
        'start_date': current['start_date'],
        'end_date': current['end_date'],
        'status': 'مكتمل',
        'payment_method': current['payment_method'],
        'notes': current['notes'],
      });
      await txn.update(
        'subscribers',
        {
          'subscription_type':
              data['subscription_type'] ?? current['subscription_type'],
          'duration': data['duration'] ?? current['duration'],
          'amount': data['amount'] ?? current['amount'],
          'start_date': data['start_date'],
          'end_date': data['end_date'],
          'status': 'نشط',
          'payment_method': data['payment_method'] ?? current['payment_method'],
          'notes': data['notes'] ?? '',
          'updated_at': _nowSql,
        },
        where: 'id=?',
        whereArgs: [subscriberId],
      );
      await txn.delete(
        'financial_transactions',
        where:
            "ref_type='subscription_history' AND ref_id IN (SELECT id FROM subscription_history WHERE subscriber_id=?)",
        whereArgs: [subscriberId],
      );
    });
  }

  Future<void> autoUpdateSubscriberStatuses() async {
    final days =
        int.tryParse(await getSetting('subscription_alert_days') ?? '7') ?? 7;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        "UPDATE subscribers SET status='منتهي' WHERE end_date < date('now','localtime') AND status NOT IN ('منتهي','موقوف')",
      );
      await txn.rawUpdate(
        "UPDATE subscribers SET status='قريب الانتهاء' WHERE end_date >= date('now','localtime') AND end_date <= date('now','localtime','+' || ? || ' days') AND status NOT IN ('قريب الانتهاء','موقوف')",
        [days],
      );
      await txn.rawUpdate(
        "UPDATE subscribers SET status='نشط' WHERE end_date > date('now','localtime','+' || ? || ' days') AND status IN ('منتهي','قريب الانتهاء')",
        [days],
      );
    });
  }

  Future<String?> getSetting(String key) async {
    final result = await db.query(
      'settings',
      columns: ['value'],
      where: 'key=?',
      whereArgs: [key],
      limit: 1,
    );
    return result.isEmpty ? null : result.first['value'] as String?;
  }

  Future<Map<String, String>> settings() async {
    final result = await db.query('settings');
    return {for (final row in result) '${row['key']}': '${row['value'] ?? ''}'};
  }

  Future<void> setSetting(String key, String value) async {
    await db.insert('settings', {
      'key': AppValidators.text(key, max: 100),
      'value': AppValidators.text(value, max: 20000),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> financialTransactions({
    String? type,
    String? source,
    String? category,
    String? from,
    String? to,
    int? subscriberId,
    int? horseId,
    String? search,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];
    if (const {'income', 'expense'}.contains(type)) {
      conditions.add('ft.type=?');
      args.add(type);
    }
    if (const {
      'subscriber',
      'horse',
      'stable',
      'booking',
      'manual',
    }.contains(source)) {
      conditions.add('ft.source_type=?');
      args.add(source);
    }
    if (category?.isNotEmpty == true) {
      conditions.add('ft.category=?');
      args.add(category);
    }
    if (from?.isNotEmpty == true) {
      conditions.add('ft.transaction_date>=?');
      args.add(from);
    }
    if (to?.isNotEmpty == true) {
      conditions.add('ft.transaction_date<=?');
      args.add(to);
    }
    if (subscriberId != null) {
      conditions.add('''(ft.subscriber_id=? OR ft.horse_id IN (
          SELECT id FROM horses WHERE subscriber_id=?
          OR id=(SELECT horse_id FROM subscribers WHERE id=?)))''');
      args.addAll([subscriberId, subscriberId, subscriberId]);
    }
    if (horseId != null) {
      conditions.add('ft.horse_id=?');
      args.add(horseId);
    }
    if (search?.trim().isNotEmpty == true) {
      conditions.add('(ft.title LIKE ? OR ft.description LIKE ?)');
      final term = '%${AppValidators.text(search)}%';
      args.addAll([term, term]);
    }
    return db.rawQuery('''SELECT ft.*, s.name subscriber_name, h.name horse_name
      FROM financial_transactions ft
      LEFT JOIN subscribers s ON s.id=ft.subscriber_id
      LEFT JOIN horses h ON h.id=ft.horse_id
      ${conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}'}
      ORDER BY ft.transaction_date DESC, ft.created_at DESC''', args);
  }

  Future<Map<String, Object?>> dashboardStats() async {
    Future<num> scalar(String sql, [List<Object?>? args]) async =>
        (Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0);
    final subscriberCounts = await db.rawQuery(
      '''SELECT
      COUNT(*) total,
      SUM(CASE WHEN status='نشط' THEN 1 ELSE 0 END) active,
      SUM(CASE WHEN status='قريب الانتهاء' THEN 1 ELSE 0 END) expiring,
      SUM(CASE WHEN status='منتهي' THEN 1 ELSE 0 END) expired FROM subscribers''',
    );
    final finance = await db.rawQuery(
      "SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END),0) income, COALESCE(SUM(CASE WHEN type='expense' AND COALESCE(affects_budget,1)=1 THEN amount ELSE 0 END),0) expense FROM financial_transactions WHERE strftime('%Y-%m',transaction_date)=strftime('%Y-%m','now','localtime')",
    );
    return {
      'total_horses': await scalar('SELECT COUNT(*) FROM horses'),
      'healthy_horses': await scalar(
        "SELECT COUNT(*) FROM horses WHERE health_status='جيدة'",
      ),
      'sick_horses': await scalar(
        "SELECT COUNT(*) FROM horses WHERE health_status<>'جيدة'",
      ),
      'upcoming_appointments': await scalar(
        "SELECT COUNT(*) FROM appointments WHERE appointment_date BETWEEN date('now','localtime') AND date('now','localtime','+7 days') AND status<>'مكتمل'",
      ),
      'overdue_appointments': await scalar(
        "SELECT COUNT(*) FROM appointments WHERE appointment_date<date('now','localtime') AND status NOT IN ('مكتمل','ملغي')",
      ),
      'overdue_boarding': await scalar(
        "SELECT COUNT(*) FROM boarding_payments WHERE is_paid=0 AND due_date<date('now','localtime')",
      ),
      'vip_subscribers': await scalar(
        'SELECT COUNT(*) FROM subscribers WHERE COALESCE(is_vip,0)=1',
      ),
      ...subscriberCounts.first,
      'month_income': finance.first['income'] ?? 0,
      'month_expense': finance.first['expense'] ?? 0,
    };
  }

  Future<List<Map<String, Object?>>> alerts() => db.rawQuery('''
    SELECT 'appointment' kind, a.id, a.horse_id related_id, a.title, a.appointment_date event_date,
      h.name horse_name, a.status, a.reminder_days,
      COALESCE(NULLIF(TRIM(a.appointment_type),''),'موعد') alert_type,
      COALESCE(NULLIF(TRIM(a.description),''),NULLIF(TRIM(a.title),''),'موعد يحتاج متابعة') reason
      FROM appointments a
      LEFT JOIN horses h ON h.id=a.horse_id
      WHERE a.status NOT IN ('مكتمل','ملغي') AND a.appointment_date<=date('now','localtime','+7 days')
    UNION ALL
    SELECT 'subscription', s.id, s.id, s.name, s.end_date, NULL, s.status, 3,
      COALESCE(NULLIF(TRIM(s.subscription_type),''),'اشتراك'),
      'انتهاء الاشتراك بتاريخ ' || COALESCE(s.end_date,'غير محدد')
      FROM subscribers s
      WHERE s.status IN ('قريب الانتهاء','منتهي')
    UNION ALL
    SELECT 'boarding', bp.id, bp.horse_id, 'دفعة إيواء', bp.due_date, h.name,
      CASE WHEN bp.due_date<date('now','localtime') THEN 'متأخر' ELSE 'قادم' END, 3,
      'إيواء',
      'دفعة إيواء غير مسددة' ||
        CASE WHEN COALESCE(TRIM(bp.room_number),'')<>'' THEN ' للغرفة ' || bp.room_number ELSE '' END ||
        CASE WHEN COALESCE(TRIM(bp.notes),'')<>'' THEN ' — ' || bp.notes ELSE '' END
      FROM boarding_payments bp LEFT JOIN horses h ON h.id=bp.horse_id
      WHERE bp.is_paid=0 AND bp.due_date<=date('now','localtime','+7 days')
    ORDER BY event_date''');

  Future<Map<String, Object?>> subscriberProfileStats(int subscriberId) async {
    final history = await db.rawQuery(
      'SELECT COUNT(*) count,COALESCE(SUM(amount),0) total FROM subscription_history WHERE subscriber_id=?',
      [subscriberId],
    );
    final payments = await db.rawQuery(
      'SELECT COUNT(*) count,COALESCE(SUM(amount),0) total FROM payments WHERE subscriber_id=?',
      [subscriberId],
    );
    final finance = await db.rawQuery(
      '''SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END),0) income,
      COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END),0) expense
      FROM financial_transactions WHERE subscriber_id=? OR horse_id IN (
        SELECT id FROM horses WHERE subscriber_id=?
        OR id=(SELECT horse_id FROM subscribers WHERE id=?))''',
      [subscriberId, subscriberId, subscriberId],
    );
    final subscriber = await row('subscribers', subscriberId);
    final currentAmount = (subscriber?['amount'] as num?)?.toDouble() ?? 0;
    final historyCount = (history.first['count'] as num?)?.toInt() ?? 0;
    final historyTotal = (history.first['total'] as num?)?.toDouble() ?? 0;
    return {
      'subscription_count': historyCount + 1,
      'subscription_value': historyTotal + currentAmount,
      'payment_count': payments.first['count'] ?? 0,
      'payments_total': payments.first['total'] ?? 0,
      'income': finance.first['income'] ?? 0,
      'expense': finance.first['expense'] ?? 0,
      'horse_count':
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(DISTINCT id) FROM horses WHERE subscriber_id=? OR id=(SELECT horse_id FROM subscribers WHERE id=?)',
              [subscriberId, subscriberId],
            ),
          ) ??
          0,
      'contract_count':
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM boarding_contracts WHERE subscriber_id=?',
              [subscriberId],
            ),
          ) ??
          0,
    };
  }

  Future<List<Map<String, Object?>>> subscriberHorses(int subscriberId) =>
      db.rawQuery(
        '''SELECT DISTINCT h.* FROM horses h
        WHERE h.subscriber_id=? OR h.id=(SELECT horse_id FROM subscribers WHERE id=?)
        ORDER BY h.name''',
        [subscriberId, subscriberId],
      );

  Future<List<Map<String, Object?>>> horseTimeline(int horseId) async {
    final result = await db.rawQuery(
      '''
      SELECT 'تطعيم/علاج' type, record_type subtype, title, record_date event_date, description, image_path FROM health_records WHERE horse_id=?
      UNION ALL SELECT 'موعد', appointment_type, title, appointment_date, description, image_path FROM appointments WHERE horse_id=?
      UNION ALL SELECT 'تحذية', 'تحذية', shoe_type, last_visit, notes, image_path FROM farrier_records WHERE horse_id=?
      UNION ALL SELECT 'مصروف', category, description, expense_date, notes, image_path FROM expenses WHERE horse_id=?
      UNION ALL SELECT 'تمرين/متابعة', 'ملاحظة', general_notes, note_date, symptoms, image_path FROM daily_notes WHERE horse_id=?
      UNION ALL SELECT 'علاج', treatment_type, COALESCE(medicine_name,treatment_type), treatment_date, notes, image_path FROM treatment_records WHERE horse_id=?
      UNION ALL SELECT 'إيواء/غرفة', 'إيواء', 'الغرفة ' || COALESCE(room_number,''), payment_date, notes, image_path FROM boarding_payments WHERE horse_id=?
      ORDER BY event_date DESC''',
      [horseId, horseId, horseId, horseId, horseId, horseId, horseId],
    );
    return result;
  }

  Future<String> integrityCheck([String? path]) async {
    if (path == null || path == _databasePath) {
      final result = await db.rawQuery('PRAGMA integrity_check');
      return '${result.first.values.first}';
    }
    final candidate = await openDatabase(
      path,
      readOnly: true,
      singleInstance: false,
    );
    try {
      final result = await candidate.rawQuery('PRAGMA integrity_check');
      return '${result.first.values.first}';
    } finally {
      await candidate.close();
    }
  }

  Future<void> checkpoint() async {
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  static String get _today => DateTime.now().toIso8601String().substring(0, 10);
  static String get _nowSql => DateTime.now().toIso8601String();

  static String _subscriptionIncomeCategory(Object? value) {
    final text = '$value';
    if (text.contains('إيواء') && text.contains('تدريب')) {
      return 'إيواء وتدريب';
    }
    if (text.contains('إيواء')) return 'إيواء';
    if (text.contains('تدريب')) return 'تدريب';
    return 'اشتراك يومي';
  }
}
