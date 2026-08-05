import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/entity_config.dart';
import '../database/database_service.dart';
import '../providers/app_provider.dart';
import '../screens/horse_details_screen.dart';
import '../screens/subscriber_details_screen.dart';
import '../widgets/entity_editor.dart';

abstract final class AlertPresentation {
  static String type(Map<String, Object?> alert) {
    final value = '${alert['alert_type'] ?? ''}'.trim();
    if (value.isNotEmpty) return value;
    return switch ('${alert['kind']}') {
      'subscription' => 'اشتراك',
      'boarding' => 'إيواء',
      _ => 'موعد',
    };
  }

  static String kind(Map<String, Object?> alert) =>
      switch ('${alert['kind']}') {
        'subscription' => 'اشتراك',
        'boarding' => 'إيواء',
        _ => 'موعد ${type(alert)}',
      };

  static String reason(Map<String, Object?> alert) {
    final value = '${alert['reason'] ?? ''}'.trim();
    if (value.isNotEmpty) return value;
    final title = '${alert['title'] ?? ''}'.trim();
    return title.isEmpty ? 'يحتاج إلى متابعة' : title;
  }

  static String subject(Map<String, Object?> alert) =>
      alert['kind'] == 'subscription'
      ? '${alert['title'] ?? 'المشترك'}'
      : '${alert['horse_name'] ?? alert['title'] ?? 'الخيل'}';

  static IconData icon(Map<String, Object?> alert) {
    final value = type(alert);
    if (alert['kind'] == 'subscription') return Icons.card_membership;
    if (alert['kind'] == 'boarding' || value.contains('إيواء')) {
      return Icons.home_work_outlined;
    }
    if (value.contains('علاج') || value.contains('دواء')) {
      return Icons.medication_outlined;
    }
    if (value.contains('تطعيم') || value.contains('فحص')) {
      return Icons.health_and_safety_outlined;
    }
    if (value.contains('تحذية')) return Icons.build_outlined;
    if (value.contains('تدريب') || value.contains('تمرين')) {
      return Icons.fitness_center;
    }
    return Icons.event_note_outlined;
  }

  static int horseTab(Map<String, Object?> alert) {
    if (alert['kind'] == 'boarding') return 3;
    final value = type(alert);
    if (value.contains('علاج') || value.contains('دواء')) return 2;
    if (value.contains('تطعيم') || value.contains('فحص')) return 1;
    if (value.contains('إيواء') || value.contains('غرفة')) return 3;
    if (value.contains('تحذية')) return 4;
    if (value.contains('تدريب') || value.contains('تمرين')) return 5;
    return 7;
  }

  static String targetLabel(Map<String, Object?> alert) {
    if (alert['kind'] == 'subscription') return 'قسم الاشتراكات';
    return switch (horseTab(alert)) {
      1 => 'السجل الصحي',
      2 => 'قسم العلاج والأدوية',
      3 => 'قسم الإيواء والغرفة',
      4 => 'قسم التحذية',
      5 => 'قسم اليومية والتمارين',
      _ => 'قسم المواعيد',
    };
  }

  static bool urgent(Map<String, Object?> alert) {
    final status = '${alert['status'] ?? ''}';
    return status.contains('متأخر') || status.contains('منتهي');
  }
}

abstract final class AlertActions {
  static Future<void> openLinkedSection(
    BuildContext context,
    Map<String, Object?> alert,
  ) async {
    if (!await _confirmExpiredAlert(context, alert, action: 'فتح ومعالجة')) {
      return;
    }
    if (!context.mounted) return;
    if (alert['kind'] == 'subscription') {
      final id = (alert['id'] as num?)?.toInt();
      if (id == null) return;
      final subscriber = await DatabaseService.instance.row('subscribers', id);
      if (subscriber != null && context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SubscriberDetailsScreen(subscriber: subscriber, initialTab: 1),
          ),
        );
      }
      return;
    }
    final horseId = (alert['related_id'] as num?)?.toInt();
    if (horseId == null) return;
    final horse = await DatabaseService.instance.row('horses', horseId);
    if (horse != null && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HorseDetailsScreen(
            horse: horse,
            initialTab: AlertPresentation.horseTab(alert),
          ),
        ),
      );
    }
  }

  static Future<bool> edit(
    BuildContext context,
    Map<String, Object?> alert,
  ) async {
    if (!await _confirmExpiredAlert(context, alert, action: 'تعديل')) {
      return false;
    }
    final config = configFor(alert);
    final id = (alert['id'] as num?)?.toInt();
    if (id == null) return false;
    final record = await DatabaseService.instance.row(config.table, id);
    if (record == null || !context.mounted) return false;
    final changed = await EntityEditorDialog.show(
      context,
      config: config,
      record: record,
    );
    if (changed && context.mounted) {
      await context.read<AppProvider>().dataChanged();
    }
    return changed;
  }

  static Future<bool> dismiss(
    BuildContext context,
    Map<String, Object?> alert,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        icon: const Icon(
          Icons.notifications_off_outlined,
          color: Colors.red,
          size: 42,
        ),
        title: const Text('إخفاء التنبيه من القائمة'),
        content: Text(
          'سيُخفى تنبيه «${AlertPresentation.reason(alert)}» فقط. سيبقى السجل الأصلي محفوظًا في ملف الخيل والخط الزمني والتقرير، ويمكن أن يظهر تنبيه جديد إذا عُدّل تاريخه أو سببه.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.visibility_off_outlined),
            label: const Text('إخفاء التنبيه فقط'),
          ),
        ],
      ),
    );
    if (accepted != true) return false;
    if (!context.mounted) return false;
    await context.read<AppProvider>().dismissAlert(alert);
    return true;
  }

  static EntityConfig configFor(Map<String, Object?> alert) =>
      switch ('${alert['kind']}') {
        'subscription' => EntityConfigs.subscriber,
        'boarding' => EntityConfigs.boardingPayment,
        _ => EntityConfigs.appointment,
      };

  static Future<bool> confirmExpiredRecord(
    BuildContext context,
    EntityConfig config,
    Map<String, Object?> record, {
    String action = 'متابعة التعديل',
  }) async {
    final message = _expiredRecordMessage(config, record);
    if (message == null) return true;
    return await _showExpiredDialog(
          context,
          title: 'السجل منتهي — تأكيد التغيير',
          message: message,
          action: action,
        ) ??
        false;
  }

  static String? _expiredRecordMessage(
    EntityConfig config,
    Map<String, Object?> record,
  ) {
    if (config.table == 'subscribers' &&
        (_datePassed(record['end_date']) || record['status'] == 'منتهي')) {
      final boarding = '${record['subscription_type'] ?? ''}'.contains('إيواء');
      return boarding
          ? 'اشتراك الإيواء للمشترك «${record['name'] ?? ''}» منتهي بتاريخ ${record['end_date'] ?? 'غير محدد'}. عدّل التاريخ أو الحالة فقط إذا كنت تريد تجديده أو تصحيح بياناته.'
          : 'اشتراك المشترك «${record['name'] ?? ''}» منتهي بتاريخ ${record['end_date'] ?? 'غير محدد'}. عدّل التاريخ أو الحالة فقط إذا كنت تريد تجديده أو تصحيح بياناته.';
    }
    if (config.table == 'boarding_payments' &&
        record['is_paid'] != 1 &&
        _datePassed(record['due_date'])) {
      return 'استحقاق الإيواء منتهي منذ ${record['due_date'] ?? 'تاريخ غير محدد'} وما زال غير مسدد. يمكنك الآن تسجيل السداد أو تعديل بيانات الاستحقاق.';
    }
    return null;
  }

  static Future<bool> _confirmExpiredAlert(
    BuildContext context,
    Map<String, Object?> alert, {
    required String action,
  }) async {
    if (!AlertPresentation.urgent(alert) ||
        !const {'subscription', 'boarding'}.contains(alert['kind'])) {
      return true;
    }
    final subject = AlertPresentation.subject(alert);
    final type = alert['kind'] == 'boarding' ? 'استحقاق الإيواء' : 'الاشتراك';
    return await _showExpiredDialog(
          context,
          title: '$type منتهي',
          message:
              '$type الخاص بـ «$subject» منتهي أو متأخر بتاريخ ${alert['event_date'] ?? 'غير محدد'}. سيتم فتح ${AlertPresentation.targetLabel(alert)} مباشرة لمعالجته.',
          action: action,
        ) ??
        false;
  }

  static Future<bool?> _showExpiredDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      icon: Icon(Icons.update_rounded, color: Colors.orange.shade800, size: 46),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(Icons.arrow_circle_left_outlined),
          label: Text(action),
        ),
      ],
    ),
  );

  static bool _datePassed(Object? value) {
    final date = DateTime.tryParse('${value ?? ''}');
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return date.isBefore(today);
  }
}
