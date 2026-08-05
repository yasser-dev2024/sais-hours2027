import 'package:flutter/material.dart';

import 'constants.dart';

enum FieldKind {
  text,
  longText,
  number,
  integer,
  date,
  time,
  choice,
  boolean,
  horse,
  subscriber,
  image,
  document,
}

class EntityField {
  const EntityField(
    this.key,
    this.label, {
    this.kind = FieldKind.text,
    this.required = false,
    this.options = const [],
    this.defaultValue,
  });

  final String key;
  final String label;
  final FieldKind kind;
  final bool required;
  final List<String> options;
  final Object? defaultValue;
}

class EntityConfig {
  const EntityConfig({
    required this.table,
    required this.title,
    required this.singular,
    required this.icon,
    required this.fields,
    required this.displayFields,
    this.orderBy = 'id DESC',
  });

  final String table;
  final String title;
  final String singular;
  final IconData icon;
  final List<EntityField> fields;
  final List<String> displayFields;
  final String orderBy;
}

abstract final class EntityConfigs {
  static const horse = EntityConfig(
    table: 'horses',
    title: 'إدارة الخيول',
    singular: 'خيل',
    icon: Icons.pets,
    orderBy: 'name',
    displayFields: [
      'name',
      'breed',
      'owner_name',
      'stable_location',
      'health_status',
      'ownership_type',
    ],
    fields: [
      EntityField('name', 'اسم الخيل', required: true),
      EntityField('image_path', 'الصورة', kind: FieldKind.image),
      EntityField(
        'breed',
        'السلالة',
        kind: FieldKind.choice,
        options: ['عربي أصيل', 'عربي', 'إنجليزي', 'أمريكي', 'أخرى'],
      ),
      EntityField(
        'gender',
        'الجنس',
        kind: FieldKind.choice,
        options: ['ذكر', 'أنثى'],
      ),
      EntityField(
        'color',
        'اللون',
        kind: FieldKind.choice,
        options: ['أبيض', 'بني', 'أسود', 'رمادي', 'كستنائي', 'أشقر', 'أخرى'],
      ),
      EntityField('chip_id', 'رقم الشريحة'),
      EntityField('birth_date', 'تاريخ الميلاد', kind: FieldKind.date),
      EntityField(
        'subscriber_id',
        'المشترك المرتبط',
        kind: FieldKind.subscriber,
      ),
      EntityField('owner_name', 'اسم المالك'),
      EntityField(
        'stable_location',
        'موقع الإسطبل',
        kind: FieldKind.choice,
        options: [
          'الإسطبل الرئيسي',
          'الإسطبل الغربي',
          'الإسطبل الشرقي',
          'أخرى',
        ],
      ),
      EntityField(
        'health_status',
        'الحالة الصحية',
        kind: FieldKind.choice,
        options: ['جيدة', 'تحت العلاج', 'مريض', 'نقاهة'],
        defaultValue: 'جيدة',
      ),
      EntityField(
        'ownership_type',
        'نوع الملكية',
        kind: FieldKind.choice,
        options: ['إيواء', 'تابع للإسطبل'],
        defaultValue: 'إيواء',
      ),
      EntityField('notes', 'ملاحظات', kind: FieldKind.longText),
    ],
  );

  static const subscriber = EntityConfig(
    table: 'subscribers',
    title: 'إدارة المشتركين',
    singular: 'مشترك',
    icon: Icons.groups,
    orderBy: 'created_at DESC',
    displayFields: [
      'name',
      'member_code',
      'is_vip',
      'phone',
      'subscription_type',
      'amount',
      'start_date',
      'end_date',
      'status',
    ],
    fields: [
      EntityField('name', 'اسم المشترك', required: true),
      EntityField('member_code', 'رقم العضوية'),
      EntityField(
        'is_vip',
        'مشترك مميز',
        kind: FieldKind.boolean,
        defaultValue: 0,
      ),
      EntityField('image_path', 'الصورة', kind: FieldKind.image),
      EntityField('phone', 'رقم الجوال'),
      EntityField('horse_id', 'الخيل المرتبط', kind: FieldKind.horse),
      EntityField(
        'subscription_type',
        'نوع الاشتراك',
        kind: FieldKind.choice,
        options: [
          'إيواء شهري',
          'تدريب يومي',
          'إيواء + تدريب',
          'عناية خاصة',
          'أخرى',
        ],
      ),
      EntityField(
        'duration',
        'المدة',
        kind: FieldKind.choice,
        options: ['1 شهر', '3 أشهر', '6 أشهر', '12 شهر', 'سنوي'],
      ),
      EntityField('amount', 'المبلغ', kind: FieldKind.number, defaultValue: 0),
      EntityField('start_date', 'تاريخ البداية', kind: FieldKind.date),
      EntityField('end_date', 'تاريخ النهاية', kind: FieldKind.date),
      EntityField(
        'status',
        'الحالة',
        kind: FieldKind.choice,
        options: ['نشط', 'قريب الانتهاء', 'منتهي', 'موقوف'],
        defaultValue: 'نشط',
      ),
      EntityField(
        'payment_method',
        'طريقة الدفع',
        kind: FieldKind.choice,
        options: ['نقدي', 'تحويل بنكي', 'بطاقة ائتمان', 'نقد', 'شيك'],
      ),
      EntityField('linked_owner', 'ربط بمالك'),
      EntityField('notes', 'ملاحظات', kind: FieldKind.longText),
    ],
  );

  static const appointment = EntityConfig(
    table: 'appointments',
    title: 'المواعيد والتنبيهات',
    singular: 'موعد',
    icon: Icons.event,
    orderBy: 'appointment_date',
    displayFields: ['title', 'appointment_type', 'appointment_date', 'status'],
    fields: [
      EntityField('horse_id', 'الخيل', kind: FieldKind.horse, required: true),
      EntityField(
        'appointment_type',
        'النوع',
        kind: FieldKind.choice,
        options: AppConstants.appointmentTypes,
        required: true,
      ),
      EntityField('title', 'عنوان الموعد', required: true),
      EntityField('description', 'الوصف', kind: FieldKind.longText),
      EntityField(
        'appointment_date',
        'التاريخ',
        kind: FieldKind.date,
        required: true,
      ),
      EntityField(
        'reminder_days',
        'التنبيه قبل (أيام)',
        kind: FieldKind.integer,
        defaultValue: 3,
      ),
      EntityField(
        'status',
        'الحالة',
        kind: FieldKind.choice,
        options: ['مجدول', 'مكتمل', 'متأخر', 'ملغي'],
        defaultValue: 'مجدول',
      ),
      EntityField(
        'image_path',
        'صورة الموعد / المتابعة',
        kind: FieldKind.image,
      ),
      EntityField('notes', 'ملاحظات', kind: FieldKind.longText),
    ],
  );

  static const subscriptionHistory = EntityConfig(
    table: 'subscription_history',
    title: 'سجل الاشتراكات',
    singular: 'دورة اشتراك',
    icon: Icons.history,
    orderBy: 'subscription_number DESC',
    displayFields: [
      'subscription_number',
      'subscription_type',
      'start_date',
      'end_date',
      'amount',
      'status',
    ],
    fields: [
      EntityField(
        'subscriber_id',
        'المشترك',
        kind: FieldKind.subscriber,
        required: true,
      ),
      EntityField('subscription_number', 'رقم الدورة', kind: FieldKind.integer),
      EntityField('subscription_type', 'نوع الاشتراك'),
      EntityField('duration', 'المدة'),
      EntityField('amount', 'المبلغ', kind: FieldKind.number),
      EntityField('start_date', 'تاريخ البداية', kind: FieldKind.date),
      EntityField('end_date', 'تاريخ النهاية', kind: FieldKind.date),
      EntityField(
        'status',
        'الحالة',
        kind: FieldKind.choice,
        options: ['مكتمل', 'منتهي', 'موقوف'],
      ),
      EntityField('payment_method', 'طريقة الدفع'),
      EntityField('notes', 'ملاحظات', kind: FieldKind.longText),
    ],
  );

  static const boardingContract = EntityConfig(
    table: 'boarding_contracts',
    title: 'عقود الإيواء',
    singular: 'عقد إيواء',
    icon: Icons.description,
    orderBy: 'created_at DESC',
    displayFields: ['horse_name', 'signed_date'],
    fields: [
      EntityField(
        'subscriber_id',
        'المشترك',
        kind: FieldKind.subscriber,
        required: true,
      ),
      EntityField('horse_id', 'الخيل', kind: FieldKind.horse),
      EntityField('horse_name', 'اسم الخيل'),
      EntityField(
        'contract_text',
        'نص العقد',
        kind: FieldKind.longText,
        required: true,
      ),
      EntityField(
        'signed_date',
        'تاريخ التوقيع',
        kind: FieldKind.date,
        required: true,
      ),
      EntityField('signature_path', 'صورة التوقيع', kind: FieldKind.image),
      EntityField('pdf_path', 'ملف العقد PDF', kind: FieldKind.document),
    ],
  );

  static const health = EntityConfig(
    table: 'health_records',
    title: 'السجل الصحي',
    singular: 'سجل صحي',
    icon: Icons.health_and_safety,
    orderBy: 'record_date DESC',
    displayFields: [
      'title',
      'record_type',
      'record_date',
      'next_date',
      'vet_name',
    ],
    fields: [
      EntityField('horse_id', 'الخيل', kind: FieldKind.horse, required: true),
      EntityField(
        'record_type',
        'النوع',
        kind: FieldKind.choice,
        options: AppConstants.healthTypes,
        required: true,
      ),
      EntityField('title', 'العنوان', required: true),
      EntityField('description', 'الوصف', kind: FieldKind.longText),
      EntityField('vet_name', 'الطبيب البيطري'),
      EntityField(
        'record_date',
        'التاريخ',
        kind: FieldKind.date,
        required: true,
      ),
      EntityField('next_date', 'الموعد القادم', kind: FieldKind.date),
      EntityField('image_path', 'صورة الحالة / العلاج', kind: FieldKind.image),
      EntityField('attachments', 'المرفق', kind: FieldKind.document),
      EntityField('notes', 'ملاحظات', kind: FieldKind.longText),
    ],
  );

  static const farrier = EntityConfig(
    table: 'farrier_records',
    title: 'التحذية والحوافر',
    singular: 'سجل تحذية',
    icon: Icons.build,
    orderBy: 'last_visit DESC',
    displayFields: [
      'last_visit',
      'next_visit',
      'shoe_type',
      'farrier_name',
      'cost',
    ],
    fields: [
      EntityField('horse_id', 'الخيل', kind: FieldKind.horse, required: true),
      EntityField(
        'last_visit',
        'تاريخ الزيارة',
        kind: FieldKind.date,
        required: true,
      ),
      EntityField('next_visit', 'الموعد القادم', kind: FieldKind.date),
      EntityField(
        'shoe_type',
        'نوع الحدوة',
        kind: FieldKind.choice,
        options: [
          'حديد عادي',
          'حديد خفيف',
          'حديد طبي',
          'ألمونيوم',
          'بدون حدوة',
        ],
      ),
      EntityField('farrier_name', 'اسم الحذّاء'),
      EntityField('cost', 'التكلفة', kind: FieldKind.number, defaultValue: 0),
      EntityField('image_path', 'الصورة', kind: FieldKind.image),
      EntityField('notes', 'ملاحظات', kind: FieldKind.longText),
    ],
  );

  static const dailyNote = EntityConfig(
    table: 'daily_notes',
    title: 'الملاحظات اليومية',
    singular: 'ملاحظة',
    icon: Icons.note_alt,
    orderBy: 'note_date DESC',
    displayFields: [
      'note_date',
      'appetite',
      'activity',
      'behavior',
      'symptoms',
    ],
    fields: [
      EntityField('horse_id', 'الخيل', kind: FieldKind.horse, required: true),
      EntityField('note_date', 'التاريخ', kind: FieldKind.date, required: true),
      EntityField(
        'appetite',
        'الشهية',
        kind: FieldKind.choice,
        options: ['ممتازة', 'جيدة', 'متوسطة', 'ضعيفة', 'لا يأكل'],
      ),
      EntityField(
        'activity',
        'النشاط',
        kind: FieldKind.choice,
        options: [
          'نشيط جداً',
          'نشيط',
          'متوسط',
          'خامل قليلاً',
          'خامل',
          'لا يتحرك',
        ],
      ),
      EntityField(
        'behavior',
        'السلوك',
        kind: FieldKind.choice,
        options: ['هادئ', 'طبيعي', 'قلق', 'عصبي', 'عدواني'],
      ),
      EntityField('symptoms', 'الأعراض', kind: FieldKind.longText),
      EntityField(
        'image_path',
        'صورة التمرين / المتابعة',
        kind: FieldKind.image,
      ),
      EntityField('general_notes', 'ملاحظات عامة', kind: FieldKind.longText),
    ],
  );

  static const expense = EntityConfig(
    table: 'expenses',
    title: 'المصروفات',
    singular: 'مصروف',
    icon: Icons.receipt_long,
    orderBy: 'expense_date DESC',
    displayFields: [
      'category',
      'amount',
      'expense_date',
      'description',
      'payer_type',
      'is_paid',
      'affects_budget',
      'charge_to_subscriber',
    ],
    fields: [
      EntityField('horse_id', 'الخيل (اختياري)', kind: FieldKind.horse),
      EntityField(
        'category',
        'الفئة',
        kind: FieldKind.choice,
        options: AppConstants.expenseCategories,
        required: true,
      ),
      EntityField('amount', 'المبلغ', kind: FieldKind.number, required: true),
      EntityField(
        'expense_date',
        'التاريخ',
        kind: FieldKind.date,
        required: true,
      ),
      EntityField('description', 'الوصف'),
      EntityField(
        'payer_type',
        'من دفع؟',
        kind: FieldKind.choice,
        options: ['owner', 'stable'],
        defaultValue: 'owner',
      ),
      EntityField(
        'is_paid',
        'تم السداد',
        kind: FieldKind.boolean,
        defaultValue: 1,
      ),
      EntityField(
        'affects_budget',
        'يُخصم من ميزانية النادي',
        kind: FieldKind.boolean,
        defaultValue: 1,
      ),
      EntityField(
        'charge_to_subscriber',
        'يُسجّل دينًا على المشترك إذا دفع النادي',
        kind: FieldKind.boolean,
        defaultValue: 0,
      ),
      EntityField(
        'debt_settled',
        'تم سداد الدين للنادي',
        kind: FieldKind.boolean,
        defaultValue: 0,
      ),
      EntityField('invoice_path', 'الفاتورة', kind: FieldKind.document),
      EntityField('image_path', 'صورة المصروف / الخدمة', kind: FieldKind.image),
      EntityField('notes', 'ملاحظات', kind: FieldKind.longText),
    ],
  );

  static const booking = EntityConfig(
    table: 'daily_bookings',
    title: 'الحجوزات اليومية',
    singular: 'حجز',
    icon: Icons.calendar_month,
    orderBy: 'booking_date DESC, booking_time DESC',
    displayFields: [
      'customer_name',
      'phone',
      'service_type',
      'duration_minutes',
      'price',
      'booking_date',
      'booking_time',
    ],
    fields: [
      EntityField('customer_name', 'اسم العميل', required: true),
      EntityField('phone', 'الجوال'),
      EntityField(
        'service_type',
        'الخدمة',
        kind: FieldKind.choice,
        options: ['تدريب', 'ركوب', 'رماية', 'أخرى'],
        required: true,
      ),
      EntityField(
        'duration_minutes',
        'المدة بالدقائق',
        kind: FieldKind.integer,
        required: true,
        defaultValue: 30,
      ),
      EntityField('price', 'السعر', kind: FieldKind.number, required: true),
      EntityField(
        'booking_date',
        'التاريخ',
        kind: FieldKind.date,
        required: true,
      ),
      EntityField('booking_time', 'الوقت', kind: FieldKind.time),
      EntityField('image_path', 'صورة التدريب / الخدمة', kind: FieldKind.image),
      EntityField('notes', 'ملاحظات', kind: FieldKind.longText),
    ],
  );

  static const payment = EntityConfig(
    table: 'payments',
    title: 'دفعات المشتركين',
    singular: 'دفعة',
    icon: Icons.payments,
    orderBy: 'payment_date DESC',
    displayFields: ['amount', 'payment_date', 'payment_method', 'notes'],
    fields: [
      EntityField(
        'subscriber_id',
        'المشترك',
        kind: FieldKind.subscriber,
        required: true,
      ),
      EntityField('amount', 'المبلغ', kind: FieldKind.number, required: true),
      EntityField(
        'payment_date',
        'التاريخ',
        kind: FieldKind.date,
        required: true,
      ),
      EntityField(
        'payment_method',
        'طريقة الدفع',
        kind: FieldKind.choice,
        options: ['نقدي', 'تحويل بنكي', 'بطاقة ائتمان', 'نقد', 'شيك'],
      ),
      EntityField('notes', 'ملاحظات', kind: FieldKind.longText),
    ],
  );

  static const boardingPayment = EntityConfig(
    table: 'boarding_payments',
    title: 'دفعات الإيواء',
    singular: 'دفعة إيواء',
    icon: Icons.home_work,
    orderBy: 'payment_date DESC',
    displayFields: [
      'room_number',
      'amount',
      'payment_date',
      'payment_method',
      'due_date',
      'is_paid',
    ],
    fields: [
      EntityField('horse_id', 'الخيل', kind: FieldKind.horse, required: true),
      EntityField('room_number', 'رقم الغرفة'),
      EntityField('amount', 'المبلغ', kind: FieldKind.number, required: true),
      EntityField(
        'payment_date',
        'تاريخ الدفع',
        kind: FieldKind.date,
        required: true,
      ),
      EntityField('due_date', 'تاريخ الاستحقاق', kind: FieldKind.date),
      EntityField(
        'payment_method',
        'طريقة الدفع',
        kind: FieldKind.choice,
        options: ['نقدي', 'تحويل بنكي', 'بطاقة ائتمان', 'نقد', 'شيك'],
      ),
      EntityField('is_paid', 'مسدد', kind: FieldKind.boolean, defaultValue: 1),
      EntityField('image_path', 'صورة الغرفة / الإيواء', kind: FieldKind.image),
      EntityField('notes', 'ملاحظات', kind: FieldKind.longText),
    ],
  );

  static const treatment = EntityConfig(
    table: 'treatment_records',
    title: 'العلاجات والأدوية',
    singular: 'علاج',
    icon: Icons.medication,
    orderBy: 'treatment_date DESC',
    displayFields: [
      'treatment_type',
      'medicine_name',
      'amount',
      'treatment_date',
      'is_paid',
      'payer_type',
      'affects_budget',
    ],
    fields: [
      EntityField('horse_id', 'الخيل', kind: FieldKind.horse, required: true),
      EntityField(
        'treatment_type',
        'نوع العلاج',
        kind: FieldKind.choice,
        options: [
          'علاج دوري',
          'تطعيم',
          'علاج جرح',
          'كشف بيطري',
          'عملية جراحية',
          'فحص دم',
          'أشعة',
          'تضميد',
          'إزالة طفيليات',
          'أخرى',
        ],
      ),
      EntityField('medicine_name', 'الدواء / العلاج'),
      EntityField('amount', 'المبلغ', kind: FieldKind.number, required: true),
      EntityField(
        'treatment_date',
        'التاريخ',
        kind: FieldKind.date,
        required: true,
      ),
      EntityField('is_paid', 'مسدد', kind: FieldKind.boolean, defaultValue: 0),
      EntityField(
        'payer_type',
        'من دفع تكلفة العلاج؟',
        kind: FieldKind.choice,
        options: ['owner', 'stable'],
        defaultValue: 'stable',
      ),
      EntityField(
        'affects_budget',
        'يُخصم من ميزانية النادي',
        kind: FieldKind.boolean,
        defaultValue: 1,
      ),
      EntityField(
        'charge_to_subscriber',
        'يُسجّل دينًا على المشترك إذا دفع النادي',
        kind: FieldKind.boolean,
        defaultValue: 0,
      ),
      EntityField(
        'debt_settled',
        'تم سداد الدين للنادي',
        kind: FieldKind.boolean,
        defaultValue: 0,
      ),
      EntityField('image_path', 'صورة العلاج', kind: FieldKind.image),
      EntityField('notes', 'ملاحظات', kind: FieldKind.longText),
    ],
  );

  static const generalExpense = EntityConfig(
    table: 'stable_general_expenses',
    title: 'مصاريف الإسطبل العامة',
    singular: 'مصروف عام',
    icon: Icons.construction,
    orderBy: 'expense_date DESC',
    displayFields: [
      'category',
      'amount',
      'expense_date',
      'description',
      'affects_budget',
    ],
    fields: [
      EntityField(
        'category',
        'الفئة',
        kind: FieldKind.choice,
        options: [
          'أعلاف وتغذية',
          'أدوية عامة',
          'نظافة وتعقيم',
          'رواتب عمال',
          'فواتير كهرباء',
          'فواتير مياه',
          'صيانة مبنى',
          'معدات وأدوات',
          'نقل وشحن',
          'وقود',
          'تأمين',
          'إيجار',
          'نثريات',
          'أخرى',
        ],
        required: true,
      ),
      EntityField('amount', 'المبلغ', kind: FieldKind.number, required: true),
      EntityField(
        'expense_date',
        'التاريخ',
        kind: FieldKind.date,
        required: true,
      ),
      EntityField('description', 'الوصف'),
      EntityField(
        'affects_budget',
        'يُخصم من ميزانية النادي',
        kind: FieldKind.boolean,
        defaultValue: 1,
      ),
      EntityField('notes', 'ملاحظات', kind: FieldKind.longText),
    ],
  );

  static const income = EntityConfig(
    table: 'stable_income_records',
    title: 'الوارد المالي',
    singular: 'وارد',
    icon: Icons.savings,
    orderBy: 'income_date DESC',
    displayFields: ['source', 'amount', 'income_date', 'description'],
    fields: [
      EntityField(
        'source',
        'المصدر',
        kind: FieldKind.choice,
        options: [
          'إيواء',
          'اشتراك يومي',
          'تدريب',
          'اشتراك شهري',
          'دفعة إيواء',
          'دفعة تدريب',
          'بيع خيل',
          'إيجار مرافق',
          'خدمات',
          'مدفوعات أخرى',
          'أخرى',
        ],
      ),
      EntityField('amount', 'المبلغ', kind: FieldKind.number, required: true),
      EntityField(
        'income_date',
        'التاريخ',
        kind: FieldKind.date,
        required: true,
      ),
      EntityField('description', 'الوصف'),
      EntityField('notes', 'ملاحظات', kind: FieldKind.longText),
    ],
  );

  static const manualTransaction = EntityConfig(
    table: 'financial_transactions',
    title: 'السجل المالي',
    singular: 'عملية مالية',
    icon: Icons.account_balance_wallet,
    orderBy: 'transaction_date DESC',
    displayFields: [
      'type',
      'title',
      'source_type',
      'category',
      'transaction_date',
      'amount',
    ],
    fields: [
      EntityField(
        'type',
        'النوع',
        kind: FieldKind.choice,
        options: ['income', 'expense'],
        required: true,
      ),
      EntityField('title', 'العنوان', required: true),
      EntityField('amount', 'المبلغ', kind: FieldKind.number, required: true),
      EntityField(
        'transaction_date',
        'التاريخ',
        kind: FieldKind.date,
        required: true,
      ),
      EntityField(
        'category',
        'الفئة',
        kind: FieldKind.choice,
        options: AppConstants.transactionCategories,
        defaultValue: 'أخرى',
      ),
      EntityField('subscriber_id', 'المشترك', kind: FieldKind.subscriber),
      EntityField('horse_id', 'الخيل', kind: FieldKind.horse),
      EntityField('payment_method', 'طريقة الدفع'),
      EntityField('description', 'الوصف', kind: FieldKind.longText),
      EntityField(
        'affects_budget',
        'تدخل في حساب الميزانية',
        kind: FieldKind.boolean,
        defaultValue: 1,
      ),
    ],
  );
}
