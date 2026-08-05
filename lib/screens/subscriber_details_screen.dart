import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../core/entity_config.dart';
import '../database/database_service.dart';
import '../providers/app_provider.dart';
import '../reports/report_service.dart';
import '../services/alert_actions.dart';
import '../services/file_service.dart';
import '../widgets/entity_editor.dart';
import '../widgets/entity_list.dart';
import '../widgets/signature_pad.dart';
import 'horse_details_screen.dart';

class SubscriberDetailsScreen extends StatelessWidget {
  const SubscriberDetailsScreen({
    super.key,
    required this.subscriber,
    this.initialTab = 0,
  });
  final Map<String, Object?> subscriber;
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final id = subscriber['id'] as int;
    final revision = context.watch<AppProvider>().revision;
    return FutureBuilder<Map<String, Object?>?>(
      key: ValueKey('member-profile:$id:$revision'),
      future: DatabaseService.instance.row('subscribers', id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final member = snapshot.data ?? subscriber;
        final vip = member['is_vip'] == 1;
        return DefaultTabController(
          length: 6,
          initialIndex: initialTab.clamp(0, 5),
          child: Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Flexible(child: Text('${member['name']}')),
                  if (vip) ...[
                    const SizedBox(width: 7),
                    const Icon(
                      Icons.workspace_premium,
                      color: Color(0xFFC18B2C),
                    ),
                  ],
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () => _editMember(context, member),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'تعديل بيانات المشترك',
                ),
                IconButton(
                  onPressed: () => _deleteMember(context, member),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'حذف المشترك',
                ),
                PopupMenuButton<String>(
                  tooltip: 'المزيد من إجراءات العضو',
                  onSelected: (value) => _handleMore(context, member, value),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'vip',
                      child: ListTile(
                        leading: Icon(
                          vip ? Icons.star : Icons.star_border,
                          color: vip ? const Color(0xFFC18B2C) : null,
                        ),
                        title: Text(vip ? 'إلغاء التمييز' : 'تمييز المشترك'),
                      ),
                    ),
                    if ('${member['phone'] ?? ''}'.isNotEmpty)
                      const PopupMenuItem(
                        value: 'whatsapp',
                        child: ListTile(
                          leading: Icon(Icons.chat),
                          title: Text('واتساب'),
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'share',
                      child: ListTile(
                        leading: Icon(Icons.share),
                        title: Text('مشاركة ملخص العضو'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'renew',
                      child: ListTile(
                        leading: Icon(Icons.autorenew),
                        title: Text('إضافة دورة/تجديد'),
                      ),
                    ),
                  ],
                ),
              ],
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(icon: Icon(Icons.account_box), text: 'ملف العضو'),
                  Tab(icon: Icon(Icons.history), text: 'الاشتراكات'),
                  Tab(icon: Icon(Icons.payments), text: 'الدفعات'),
                  Tab(icon: Icon(Icons.receipt_long), text: 'السجل المالي'),
                  Tab(icon: Icon(Icons.pets), text: 'الخيل التابعة'),
                  Tab(icon: Icon(Icons.draw), text: 'العقود'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _SubscriberInfo(subscriber: member),
                _HistoryTab(subscriber: member),
                EntityList(
                  config: EntityConfigs.payment,
                  forcedValues: {'subscriber_id': id},
                  where: 'subscriber_id=?',
                  whereArgs: [id],
                  compact: true,
                  onOpen: (payment) =>
                      _InvoiceSheet.show(context, payment['id'] as int),
                ),
                _MemberFinancialTab(subscriberId: id),
                _MemberHorsesTab(subscriberId: id),
                _ContractsTab(subscriber: member),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleMore(
    BuildContext context,
    Map<String, Object?> member,
    String action,
  ) async {
    switch (action) {
      case 'vip':
        await _toggleVip(context, member);
        return;
      case 'whatsapp':
        await FileService.instance.openWhatsApp('${member['phone']}');
        return;
      case 'share':
        await _shareMember(member);
        return;
      case 'renew':
        if (context.mounted) await _RenewDialog.show(context, member);
        return;
    }
  }

  Future<void> _editMember(
    BuildContext context,
    Map<String, Object?> member,
  ) async {
    if (!await AlertActions.confirmExpiredRecord(
      context,
      EntityConfigs.subscriber,
      member,
    )) {
      return;
    }
    if (!context.mounted) return;
    final changed = await EntityEditorDialog.show(
      context,
      config: EntityConfigs.subscriber,
      record: member,
    );
    if (changed && context.mounted) {
      await context.read<AppProvider>().dataChanged();
    }
  }

  Future<void> _deleteMember(
    BuildContext context,
    Map<String, Object?> member,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        icon: const Icon(
          Icons.person_remove_outlined,
          color: Colors.red,
          size: 42,
        ),
        title: const Text('حذف ملف المشترك'),
        content: Text(
          'سيتم حذف «${member['name']}» واشتراكاته وسجلاته المرتبطة نهائيًا.',
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
            icon: const Icon(Icons.delete_outline),
            label: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await DatabaseService.instance.deleteRecord(
      'subscribers',
      member['id'] as int,
    );
    if (!context.mounted) return;
    await context.read<AppProvider>().dataChanged();
    if (context.mounted) Navigator.pop(context, true);
  }

  Future<void> _toggleVip(
    BuildContext context,
    Map<String, Object?> member,
  ) async {
    await DatabaseService.instance.saveRecord('subscribers', {
      ...member,
      'is_vip': member['is_vip'] == 1 ? 0 : 1,
    }, id: member['id'] as int);
    if (context.mounted) await context.read<AppProvider>().dataChanged();
  }

  Future<void> _shareMember(Map<String, Object?> member) async {
    final stats = await DatabaseService.instance.subscriberProfileStats(
      member['id'] as int,
    );
    await FileService.instance.shareText('''ملف عضو سايس الخيل
الاسم: ${member['name']}
رقم العضوية: ${member['member_code'] ?? '—'}
الجوال: ${member['phone'] ?? '—'}
الحالة: ${member['status'] ?? '—'}
نوع الاشتراك: ${member['subscription_type'] ?? '—'}
عدد دورات الاشتراك: ${stats['subscription_count']}
الخيل التابعة: ${stats['horse_count']}
إجمالي الوارد المرتبط: ${stats['income']} ر.س''');
  }
}

class _SubscriberInfo extends StatelessWidget {
  const _SubscriberInfo({required this.subscriber});
  final Map<String, Object?> subscriber;
  @override
  Widget build(BuildContext context) {
    final path = '${subscriber['image_path'] ?? ''}';
    final id = subscriber['id'] as int;
    final items = <String, Object?>{
      'رقم العضوية': subscriber['member_code'],
      'الاسم': subscriber['name'],
      'رقم الجوال': subscriber['phone'],
      'نوع الاشتراك': subscriber['subscription_type'],
      'المدة': subscriber['duration'],
      'المبلغ': subscriber['amount'],
      'تاريخ البداية': subscriber['start_date'],
      'تاريخ النهاية': subscriber['end_date'],
      'الحالة': subscriber['status'],
      'طريقة الدفع': subscriber['payment_method'],
      'المالك المرتبط': subscriber['linked_owner'],
      'تاريخ الانضمام': '${subscriber['created_at'] ?? ''}'.split(' ').first,
    };
    return FutureBuilder<Map<String, Object?>>(
      future: DatabaseService.instance.subscriberProfileStats(id),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? const {};
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final avatar = CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: .2),
                      backgroundImage:
                          path.isNotEmpty && File(path).existsSync()
                          ? FileImage(File(path))
                          : null,
                      child: path.isEmpty || !File(path).existsSync()
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    );
                    final identity = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${subscriber['name']}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (subscriber['is_vip'] == 1) ...[
                              const SizedBox(width: 8),
                              const Chip(
                                avatar: Icon(
                                  Icons.workspace_premium,
                                  color: Color(0xFFC18B2C),
                                  size: 20,
                                ),
                                label: Text('مشترك مميز'),
                                backgroundColor: Color(0xFFFFF4D8),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${subscriber['member_code'] ?? '—'}',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${subscriber['phone'] ?? ''}',
                          textDirection: TextDirection.ltr,
                        ),
                        const SizedBox(height: 8),
                        _StatusPill(status: '${subscriber['status'] ?? '—'}'),
                      ],
                    );
                    return constraints.maxWidth > 540
                        ? Row(
                            children: [
                              avatar,
                              const SizedBox(width: 18),
                              Expanded(child: identity),
                            ],
                          )
                        : Column(
                            children: [
                              avatar,
                              const SizedBox(height: 12),
                              identity,
                            ],
                          );
                  },
                ),
              ),
            ),
            if (snapshot.connectionState != ConnectionState.done)
              const LinearProgressIndicator()
            else
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width > 650 ? 4 : 2,
                childAspectRatio: 1.75,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _MemberMetric(
                    label: 'دورات الاشتراك',
                    value: '${stats['subscription_count'] ?? 1}',
                    icon: Icons.autorenew,
                    color: const Color(0xFF6B5FB5),
                  ),
                  _MemberMetric(
                    label: 'الخيل التابعة',
                    value: '${stats['horse_count'] ?? 0}',
                    icon: Icons.pets,
                    color: const Color(0xFF2A6592),
                  ),
                  _MemberMetric(
                    label: 'إجمالي الوارد',
                    value: '${stats['income'] ?? 0} ر.س',
                    icon: Icons.savings,
                    color: const Color(0xFF21845A),
                  ),
                  _MemberMetric(
                    label: 'العقود',
                    value: '${stats['contract_count'] ?? 0}',
                    icon: Icons.description,
                    color: const Color(0xFFC18B2C),
                  ),
                ],
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'بيانات العضو والاشتراك الحالي',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Divider(),
                    ...items.entries.map(
                      (entry) => ListTile(
                        dense: true,
                        title: Text(entry.key),
                        trailing: SizedBox(
                          width: 190,
                          child: Text(
                            '${entry.value ?? '—'}',
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    if ('${subscriber['notes'] ?? ''}'.isNotEmpty)
                      ListTile(
                        title: const Text('ملاحظات'),
                        subtitle: Text('${subscriber['notes']}'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.subscriber});
  final Map<String, Object?> subscriber;
  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, Object?>>>(
    future: DatabaseService.instance.rows(
      'subscription_history',
      where: 'subscriber_id=?',
      whereArgs: [subscriber['id']],
      orderBy: 'subscription_number DESC',
    ),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Center(child: CircularProgressIndicator());
      final rows = snapshot.data ?? const [];
      final total = rows.length + 1;
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 27,
                    child: Text(
                      '$total',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إجمالي دورات الاشتراك',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        Text('الدورة الحالية مع كل الدورات المؤرشفة'),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _RenewDialog.show(context, subscriber),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة/تجديد'),
                  ),
                ],
              ),
            ),
          ),
          _SubscriptionCard(
            record: subscriber,
            number: total,
            current: true,
            onEdit: () => _edit(context, subscriber, current: true),
          ),
          if (rows.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'لا توجد دورات سابقة بعد. عند التجديد تُؤرشف الدورة الحالية هنا بكل تفاصيلها.',
                ),
              ),
            )
          else
            ...rows.map(
              (row) => _SubscriptionCard(
                record: row,
                number: (row['subscription_number'] as num?)?.toInt() ?? 1,
                onEdit: () => _edit(context, row),
                onDelete: () => _delete(context, row),
              ),
            ),
        ],
      );
    },
  );

  Future<void> _edit(
    BuildContext context,
    Map<String, Object?> record, {
    bool current = false,
  }) async {
    final config = current
        ? EntityConfigs.subscriber
        : EntityConfigs.subscriptionHistory;
    if (!await AlertActions.confirmExpiredRecord(context, config, record)) {
      return;
    }
    if (!context.mounted) return;
    final changed = await EntityEditorDialog.show(
      context,
      config: config,
      record: record,
      forcedValues: current ? const {} : {'subscriber_id': subscriber['id']},
    );
    if (changed && context.mounted) {
      await context.read<AppProvider>().dataChanged();
    }
  }

  Future<void> _delete(
    BuildContext context,
    Map<String, Object?> record,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('حذف دورة الاشتراك'),
        content: Text(
          'حذف دورة الاشتراك رقم ${record['subscription_number'] ?? ''} من السجل؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('حذف'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await DatabaseService.instance.deleteRecord(
      'subscription_history',
      record['id'] as int,
    );
    if (context.mounted) await context.read<AppProvider>().dataChanged();
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.record,
    required this.number,
    this.current = false,
    this.onEdit,
    this.onDelete,
  });
  final Map<String, Object?> record;
  final int number;
  final bool current;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) => Card(
    color: current ? const Color(0xFFF2F8F5) : Colors.white,
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: current ? Colors.green.shade100 : null,
        child: Text('$number'),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${record['subscription_type'] ?? 'اشتراك'}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          if (current)
            Chip(
              avatar: Icon(
                Icons.check_circle,
                color: Colors.green.shade800,
                size: 18,
              ),
              label: Text(
                'الحالي',
                style: TextStyle(
                  color: Colors.green.shade900,
                  fontWeight: FontWeight.w900,
                ),
              ),
              backgroundColor: Colors.green.shade50,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
      subtitle: Text(
        '${record['start_date'] ?? ''} ← ${record['end_date'] ?? ''}\n${record['duration'] ?? ''} • ${record['payment_method'] ?? '—'} • ${record['status'] ?? '—'}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${record['amount'] ?? 0} ر.س',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              tooltip: 'تعديل دورة الاشتراك',
              icon: const Icon(Icons.edit_outlined),
            ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              tooltip: 'حذف دورة الاشتراك',
              color: Colors.red.shade700,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      isThreeLine: true,
    ),
  );
}

class _MemberFinancialTab extends StatelessWidget {
  const _MemberFinancialTab({required this.subscriberId});
  final int subscriberId;
  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, Object?>>>(
    future: DatabaseService.instance.financialTransactions(
      subscriberId: subscriberId,
    ),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Center(child: CircularProgressIndicator());
      final rows = snapshot.data ?? const [];
      final income = rows
          .where((row) => row['type'] == 'income')
          .fold<double>(
            0,
            (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
          );
      final expense = rows
          .where((row) => row['type'] == 'expense')
          .fold<double>(
            0,
            (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
          );
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: _MemberMetric(
                    label: 'الوارد',
                    value: '${income.toStringAsFixed(2)} ر.س',
                    icon: Icons.arrow_downward,
                    color: Colors.green.shade700,
                  ),
                ),
                Expanded(
                  child: _MemberMetric(
                    label: 'المصروف',
                    value: '${expense.toStringAsFixed(2)} ر.س',
                    icon: Icons.arrow_upward,
                    color: Colors.red.shade700,
                  ),
                ),
                Expanded(
                  child: _MemberMetric(
                    label: 'الرصيد',
                    value: '${(income - expense).toStringAsFixed(2)} ر.س',
                    icon: Icons.account_balance_wallet,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text('لا توجد عمليات مالية مرتبطة بهذا العضو'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: rows.length,
                    itemBuilder: (_, index) {
                      final row = rows[index];
                      final isIncome = row['type'] == 'income';
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                (isIncome ? Colors.green : Colors.red)
                                    .withValues(alpha: .12),
                            child: Icon(
                              isIncome ? Icons.south_west : Icons.north_east,
                              color: isIncome
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                          title: Text(
                            '${row['title'] ?? 'عملية مالية'}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            '${row['transaction_date'] ?? ''} • ${row['category'] ?? ''}\n${row['description'] ?? ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${row['amount'] ?? 0} ر.س',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: isIncome
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _edit(context, row),
                                tooltip: 'تعديل العملية',
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () => _delete(context, row),
                                tooltip: 'حذف العملية',
                                color: Colors.red.shade700,
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    },
  );

  Future<void> _edit(BuildContext context, Map<String, Object?> record) async {
    final changed = await EntityEditorDialog.show(
      context,
      config: EntityConfigs.manualTransaction,
      record: record,
    );
    if (changed && context.mounted) {
      await context.read<AppProvider>().dataChanged();
    }
  }

  Future<void> _delete(
    BuildContext context,
    Map<String, Object?> record,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('حذف العملية المالية'),
        content: Text(
          'هل تريد حذف «${record['title'] ?? 'العملية'}» من السجل؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('حذف'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await DatabaseService.instance.deleteRecord(
      'financial_transactions',
      record['id'] as int,
    );
    if (context.mounted) await context.read<AppProvider>().dataChanged();
  }
}

class _MemberHorsesTab extends StatelessWidget {
  const _MemberHorsesTab({required this.subscriberId});
  final int subscriberId;
  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, Object?>>>(
    future: DatabaseService.instance.subscriberHorses(subscriberId),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Center(child: CircularProgressIndicator());
      final rows = snapshot.data ?? const [];
      if (rows.isEmpty)
        return const Center(child: Text('لا توجد خيل مرتبطة بهذا العضو بعد'));
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        itemCount: rows.length,
        itemBuilder: (_, index) {
          final horse = rows[index];
          final imagePath = '${horse['image_path'] ?? ''}';
          return Card(
            child: ListTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HorseDetailsScreen(horse: horse),
                ),
              ),
              leading: CircleAvatar(
                backgroundImage:
                    imagePath.isNotEmpty && File(imagePath).existsSync()
                    ? FileImage(File(imagePath))
                    : null,
                child: imagePath.isEmpty || !File(imagePath).existsSync()
                    ? const Icon(Icons.pets)
                    : null,
              ),
              title: Text(
                '${horse['name']}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${horse['breed'] ?? '—'} • ${horse['gender'] ?? '—'}\n${horse['health_status'] ?? '—'} • ${horse['stable_location'] ?? '—'}',
              ),
              trailing: const Icon(Icons.chevron_left),
              isThreeLine: true,
            ),
          );
        },
      );
    },
  );
}

class _MemberMetric extends StatelessWidget {
  const _MemberMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = status == 'نشط'
        ? Colors.green
        : status == 'قريب الانتهاء'
        ? Colors.orange
        : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status,
        style: TextStyle(color: color.shade700, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _ContractsTab extends StatelessWidget {
  const _ContractsTab({required this.subscriber});
  final Map<String, Object?> subscriber;
  @override
  Widget build(BuildContext context) {
    final revision = context.watch<AppProvider>().revision;
    final id = subscriber['id'] as int;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.draw),
              label: const Text('إضافة وتوقيع عقد إيواء'),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            key: ValueKey('contracts:$revision'),
            future: DatabaseService.instance.rows(
              'boarding_contracts',
              where: 'subscriber_id=?',
              whereArgs: [id],
              orderBy: 'created_at DESC',
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const Center(child: CircularProgressIndicator());
              final rows = snapshot.data ?? const [];
              if (rows.isEmpty)
                return const Center(child: Text('لا توجد عقود إيواء مسجلة'));
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final row = rows[i];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.description),
                      ),
                      title: Text(
                        '${row['horse_name'] ?? 'عقد إيواء'}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text('تم التوقيع: ${row['signed_date'] ?? ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: '${row['pdf_path'] ?? ''}'.isEmpty
                                ? null
                                : () => FileService.instance.shareFile(
                                    '${row['pdf_path']}',
                                    text: 'عقد إيواء - سايس الخيل',
                                  ),
                            icon: const Icon(Icons.share),
                            tooltip: 'مشاركة PDF',
                          ),
                          IconButton(
                            onPressed: () => _edit(context, row),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'تعديل العقد',
                          ),
                          IconButton(
                            onPressed: () => _delete(context, row),
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red.shade700,
                            tooltip: 'حذف العقد',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    const fallback =
        'أتعهد بصحة البيانات والمحافظة على أنظمة الإسطبل وسداد الرسوم في مواعيدها، وأوافق على إجراءات الرعاية والسلامة المعتمدة.';
    final terms =
        await DatabaseService.instance.getSetting('boarding_contract_text') ??
        fallback;
    if (!context.mounted) return;
    final signature = await SignatureDialog.show(context, terms);
    if (signature == null || !context.mounted) return;
    final horseId = subscriber['horse_id'] as int?;
    final horse = horseId == null
        ? null
        : await DatabaseService.instance.row('horses', horseId);
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final data = <String, Object?>{
      'subscriber_id': subscriber['id'],
      'horse_id': horseId,
      'horse_name': horse?['name'] ?? '',
      'contract_text': terms,
      'signed_date': date,
      'signature_path': signature,
      'pdf_path': '',
    };
    final contractId = await DatabaseService.instance.saveRecord(
      'boarding_contracts',
      data,
    );
    final bytes = await ReportService.instance.buildBoardingContract(
      subscriberName: '${subscriber['name']}',
      horseName: '${horse?['name'] ?? ''}',
      contractText: terms,
      signedDate: date,
      signaturePath: signature,
    );
    final dir = Directory(
      p.join(DatabaseService.instance.appDirectory.path, 'contracts'),
    );
    await dir.create(recursive: true);
    final pdf = File(
      p.join(dir.path, 'contract_${DateTime.now().millisecondsSinceEpoch}.pdf'),
    );
    await pdf.writeAsBytes(bytes, flush: true);
    data['pdf_path'] = pdf.path;
    await DatabaseService.instance.saveRecord(
      'boarding_contracts',
      data,
      id: contractId,
    );
    if (context.mounted) {
      await context.read<AppProvider>().dataChanged();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم توقيع العقد وحفظ ملف PDF بنجاح')),
      );
    }
  }

  Future<void> _edit(
    BuildContext context,
    Map<String, Object?> contract,
  ) async {
    final changed = await EntityEditorDialog.show(
      context,
      config: EntityConfigs.boardingContract,
      record: contract,
      forcedValues: {'subscriber_id': subscriber['id']},
    );
    if (changed && context.mounted) {
      await context.read<AppProvider>().dataChanged();
    }
  }

  Future<void> _delete(
    BuildContext context,
    Map<String, Object?> contract,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('حذف عقد الإيواء'),
        content: Text(
          'حذف عقد «${contract['horse_name'] ?? 'الإيواء'}» نهائيًا؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('حذف'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await DatabaseService.instance.deleteRecord(
      'boarding_contracts',
      contract['id'] as int,
    );
    if (context.mounted) await context.read<AppProvider>().dataChanged();
  }
}

class _RenewDialog extends StatefulWidget {
  const _RenewDialog({required this.subscriber});
  final Map<String, Object?> subscriber;
  static Future<void> show(
    BuildContext context,
    Map<String, Object?> subscriber,
  ) async {
    if (!await AlertActions.confirmExpiredRecord(
      context,
      EntityConfigs.subscriber,
      subscriber,
      action: 'متابعة التجديد',
    )) {
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RenewDialog(subscriber: subscriber),
    );
  }

  @override
  State<_RenewDialog> createState() => _RenewDialogState();
}

class _RenewDialogState extends State<_RenewDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _amount, _start, _end, _notes;
  String _type = 'إيواء شهري', _duration = '1 شهر', _method = 'نقدي';
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _type = '${widget.subscriber['subscription_type'] ?? 'إيواء شهري'}';
    _amount = TextEditingController(
      text: '${widget.subscriber['amount'] ?? 0}',
    );
    final now = DateTime.now();
    _start = TextEditingController(
      text: now.toIso8601String().substring(0, 10),
    );
    _end = TextEditingController(
      text: DateTime(
        now.year,
        now.month + 1,
        now.day,
      ).toIso8601String().substring(0, 10),
    );
    _notes = TextEditingController();
  }

  @override
  void dispose() {
    _amount.dispose();
    _start.dispose();
    _end.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    title: Text('تجديد اشتراك ${widget.subscriber['name']}'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField(
                value: _type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'نوع الاشتراك'),
                items:
                    [
                          'إيواء شهري',
                          'تدريب يومي',
                          'إيواء + تدريب',
                          'عناية خاصة',
                          'أخرى',
                        ]
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField(
                value: _duration,
                decoration: const InputDecoration(labelText: 'المدة'),
                items: ['1 شهر', '3 أشهر', '6 أشهر', '12 شهر', 'سنوي']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _duration = v!);
                  _recalculateEnd();
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'المبلغ'),
                validator: (v) =>
                    double.tryParse(v ?? '') == null ? 'مبلغ غير صحيح' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _start,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'تاريخ البداية'),
                onTap: () => _pickDate(_start, true),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _end,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'تاريخ النهاية'),
                onTap: () => _pickDate(_end, false),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField(
                value: _method,
                decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                items: ['نقدي', 'تحويل بنكي', 'بطاقة ائتمان', 'شيك']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _method = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      ElevatedButton(
        onPressed: _saving ? null : _save,
        child: const Text('تجديد'),
      ),
    ],
  );
  void _recalculateEnd() {
    final start = DateTime.tryParse(_start.text) ?? DateTime.now();
    final months = switch (_duration) {
      '3 أشهر' => 3,
      '6 أشهر' => 6,
      '12 شهر' => 12,
      'سنوي' => 12,
      _ => 1,
    };
    _end.text = DateTime(
      start.year,
      start.month + months,
      start.day,
    ).toIso8601String().substring(0, 10);
  }

  Future<void> _pickDate(TextEditingController controller, bool recalc) async {
    final value = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value != null) {
      controller.text = value.toIso8601String().substring(0, 10);
      if (recalc) _recalculateEnd();
    }
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    await DatabaseService.instance
        .renewSubscription(widget.subscriber['id'] as int, {
          'name': widget.subscriber['name'],
          'subscription_type': _type,
          'duration': _duration,
          'amount': _amount.text,
          'start_date': _start.text,
          'end_date': _end.text,
          'payment_method': _method,
          'notes': _notes.text,
        });
    if (!mounted) return;
    await context.read<AppProvider>().dataChanged();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('تم تجديد الاشتراك وأرشفة الفترة السابقة')),
    );
  }
}

class _InvoiceSheet {
  static Future<void> show(BuildContext context, int paymentId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => _InvoiceSheetBody(paymentId: paymentId),
    );
  }
}

class _InvoiceSheetBody extends StatefulWidget {
  const _InvoiceSheetBody({required this.paymentId});
  final int paymentId;
  @override
  State<_InvoiceSheetBody> createState() => _InvoiceSheetBodyState();
}

class _InvoiceSheetBodyState extends State<_InvoiceSheetBody> {
  int _revision = 0;
  Future<List<Map<String, Object?>>> _load() => DatabaseService.instance.rows(
    'payment_invoices',
    where: 'payment_id=?',
    whereArgs: [widget.paymentId],
    orderBy: 'created_at',
  );
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: 520,
        child: Column(
          children: [
            ListTile(
              title: const Text(
                'فواتير الدفعة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              trailing: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _generate,
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('إنشاء فاتورة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('إرفاق ملف'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                key: ValueKey(_revision),
                future: _load(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done)
                    return const Center(child: CircularProgressIndicator());
                  final rows = snapshot.data ?? const [];
                  if (rows.isEmpty)
                    return const Center(child: Text('لا توجد فواتير مرفقة'));
                  return ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final row = rows[i];
                      return ListTile(
                        leading: const Icon(Icons.description),
                        title: Text(
                          '${row['invoice_path']}'.split(RegExp(r'[/\\]')).last,
                        ),
                        onTap: () => FileService.instance.shareFile(
                          '${row['invoice_path']}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _replace(row),
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'استبدال الملف',
                            ),
                            IconButton(
                              onPressed: () => _delete(row['id'] as int),
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red.shade700,
                              tooltip: 'حذف الملف',
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _generate() async {
    final database = DatabaseService.instance;
    final payment = await database.row('payments', widget.paymentId);
    if (payment == null) return;
    final subscriberId = (payment['subscriber_id'] as num?)?.toInt();
    final horseId = (payment['horse_id'] as num?)?.toInt();
    final subscriber = subscriberId == null
        ? null
        : await database.row('subscribers', subscriberId);
    final horse = horseId == null
        ? null
        : await database.row('horses', horseId);
    final invoiceData = <String, Object?>{
      'invoice_number': 'PAY-${widget.paymentId.toString().padLeft(6, '0')}',
      'subscriber_name': subscriber?['name'] ?? '—',
      'member_code': subscriber?['member_code'] ?? '—',
      'horse_name': horse?['name'] ?? '—',
      'amount': payment['amount'],
      'payment_date': payment['payment_date'],
      'payment_method': payment['payment_method'] ?? '—',
      'notes': payment['notes'] ?? '',
    };
    final bytes = await ReportService.instance.buildPdf(
      ReportData(
        title: 'فاتورة دفعة',
        columns: const [
          MapEntry('invoice_number', 'رقم الفاتورة'),
          MapEntry('subscriber_name', 'المشترك'),
          MapEntry('member_code', 'رقم العضوية'),
          MapEntry('horse_name', 'الخيل'),
          MapEntry('amount', 'المبلغ'),
          MapEntry('payment_date', 'التاريخ'),
          MapEntry('payment_method', 'طريقة الدفع'),
          MapEntry('notes', 'ملاحظات'),
        ],
        rows: [invoiceData],
        summary: const ['فاتورة قبض مرتبطة بالسجل المالي للنادي'],
      ),
    );
    final directory = Directory(
      p.join(database.appDirectory.path, 'payment_invoices'),
    );
    await directory.create(recursive: true);
    final path = p.join(
      directory.path,
      'invoice_${widget.paymentId}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await File(path).writeAsBytes(bytes, flush: true);
    await database.saveRecord('payment_invoices', {
      'payment_id': widget.paymentId,
      'invoice_path': path,
    });
    if (!mounted) return;
    setState(() => _revision++);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إنشاء الفاتورة بهوية النادي وحفظها.')),
    );
  }

  Future<void> _add() async {
    final path = await FileService.instance.pickDocument(
      folder: 'payment_invoices',
    );
    if (path == null) return;
    await DatabaseService.instance.saveRecord('payment_invoices', {
      'payment_id': widget.paymentId,
      'invoice_path': path,
    });
    setState(() => _revision++);
  }

  Future<void> _delete(int id) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('حذف الفاتورة'),
        content: const Text('هل تريد حذف ملف الفاتورة المرفق؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await DatabaseService.instance.deleteRecord('payment_invoices', id);
    setState(() => _revision++);
  }

  Future<void> _replace(Map<String, Object?> row) async {
    final path = await FileService.instance.pickDocument(
      folder: 'payment_invoices',
    );
    if (path == null) return;
    await DatabaseService.instance.saveRecord('payment_invoices', {
      'payment_id': widget.paymentId,
      'invoice_path': path,
    }, id: row['id'] as int);
    if (mounted) setState(() => _revision++);
  }
}
