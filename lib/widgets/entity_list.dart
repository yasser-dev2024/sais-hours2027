import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/entity_config.dart';
import '../database/database_service.dart';
import '../providers/app_provider.dart';
import '../services/alert_actions.dart';
import 'entity_editor.dart';

class EntityList extends StatefulWidget {
  const EntityList({
    super.key,
    required this.config,
    this.forcedValues = const {},
    this.where,
    this.whereArgs,
    this.compact = false,
    this.showHeader = true,
    this.onOpen,
  });

  final EntityConfig config;
  final Map<String, Object?> forcedValues;
  final String? where;
  final List<Object?>? whereArgs;
  final bool compact;
  final bool showHeader;
  final void Function(Map<String, Object?> record)? onOpen;

  @override
  State<EntityList> createState() => _EntityListState();
}

class _EntityListState extends State<EntityList> {
  String _search = '';

  Future<List<Map<String, Object?>>> _load() => DatabaseService.instance.rows(
    widget.config.table,
    where: widget.where,
    whereArgs: widget.whereArgs,
    orderBy: widget.config.orderBy,
  );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final revision = app.revision;
    final phone = MediaQuery.sizeOf(context).width < 600;
    return Column(
      children: [
        if (widget.showHeader)
          Padding(
            padding: phone
                ? const EdgeInsets.fromLTRB(8, 8, 8, 4)
                : const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) =>
                        setState(() => _search = value.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'بحث...',
                    ),
                  ),
                ),
                SizedBox(width: phone ? 6 : 8),
                ElevatedButton.icon(
                  onPressed: _add,
                  style: phone
                      ? ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          textStyle: const TextStyle(
                            fontFamily: 'NotoSansArabic',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                  icon: Icon(Icons.add, size: phone ? 20 : null),
                  label: Text(
                    'إضافة ${widget.config.singular}',
                    maxLines: phone ? 1 : null,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            key: ValueKey(
              '${widget.config.table}:$revision:${widget.whereArgs}',
            ),
            future: _load(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return _ErrorState(
                  message: '${snapshot.error}',
                  onRetry: () => setState(() {}),
                );
              final all = snapshot.data ?? const [];
              final rows = _search.isEmpty
                  ? all
                  : all
                        .where(
                          (row) => row.values.any(
                            (value) => '$value'.toLowerCase().contains(_search),
                          ),
                        )
                        .toList();
              if (rows.isEmpty)
                return _EmptyState(title: 'لا توجد بيانات', onAdd: _add);
              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 760 &&
                      !widget.compact &&
                      !const {
                        'horses',
                        'subscribers',
                      }.contains(widget.config.table)) {
                    return _buildTable(rows);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96, top: 6),
                    itemCount: rows.length,
                    itemBuilder: (_, index) {
                      final matching = _matchingAlerts(app.alerts, rows[index]);
                      return TweenAnimationBuilder<double>(
                        key: ValueKey(
                          '${widget.config.table}:${rows[index]['id']}',
                        ),
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(
                          milliseconds: 260 + (index.clamp(0, 6) * 55),
                        ),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) => Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 18 * (1 - value)),
                            child: child,
                          ),
                        ),
                        child: _RecordCard(
                          config: widget.config,
                          record: rows[index],
                          alerts: matching,
                          compactPhone: phone,
                          onOpen: () => widget.onOpen?.call(rows[index]),
                          onEdit: () => _edit(rows[index]),
                          onDelete: () => _delete(rows[index]),
                          onPaid: rows[index].containsKey('is_paid')
                              ? (value) => _markPaid(rows[index], value)
                              : null,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<Map<String, Object?>> rows) {
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingRowColor: WidgetStateProperty.all(
            Theme.of(context).colorScheme.primary.withValues(alpha: .08),
          ),
          columns: [
            ...widget.config.displayFields.map(
              (key) => DataColumn(label: Text(_label(key))),
            ),
            const DataColumn(label: Text('إجراءات')),
          ],
          rows: rows
              .map(
                (row) => DataRow(
                  onSelectChanged: widget.onOpen == null
                      ? null
                      : (_) => widget.onOpen!(row),
                  cells: [
                    ...widget.config.displayFields.map(
                      (key) => DataCell(
                        SizedBox(
                          width: 125,
                          child: Text(
                            _display(key, row[key]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _edit(row),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'تعديل',
                          ),
                          IconButton(
                            onPressed: () => _delete(row),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'حذف',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _add() async {
    final changed = await EntityEditorDialog.show(
      context,
      config: widget.config,
      forcedValues: widget.forcedValues,
    );
    if (changed && mounted) await context.read<AppProvider>().dataChanged();
  }

  Future<void> _edit(Map<String, Object?> record) async {
    if (!await AlertActions.confirmExpiredRecord(
      context,
      widget.config,
      record,
    )) {
      return;
    }
    if (!mounted) return;
    final changed = await EntityEditorDialog.show(
      context,
      config: widget.config,
      record: record,
      forcedValues: widget.forcedValues,
    );
    if (changed && mounted) await context.read<AppProvider>().dataChanged();
  }

  Future<void> _delete(Map<String, Object?> record) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('تأكيد الحذف'),
        content: Text(
          'هل تريد حذف ${widget.config.singular}؟ لا يمكن التراجع عن العملية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await DatabaseService.instance.deleteRecord(
        widget.config.table,
        record['id'] as int,
      );
      if (mounted) await context.read<AppProvider>().dataChanged();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر الحذف: $error')));
    }
  }

  Future<void> _markPaid(Map<String, Object?> record, bool value) async {
    await DatabaseService.instance.markPaid(
      widget.config.table,
      record['id'] as int,
      value,
    );
    if (mounted) await context.read<AppProvider>().dataChanged();
  }

  String _label(String key) =>
      widget.config.fields
          .where((field) => field.key == key)
          .map((field) => field.label)
          .firstOrNull ??
      key;

  static String _display(String key, Object? value) {
    if (value == null || '$value'.isEmpty) return '—';
    if (key == 'is_paid') return value == 1 ? 'مسدد' : 'غير مسدد';
    if (key == 'is_vip') return value == 1 ? 'مميز' : 'عادي';
    if (const {
      'affects_budget',
      'charge_to_subscriber',
      'debt_settled',
      'is_subscriber_debt',
    }.contains(key)) {
      return value == 1 ? 'نعم' : 'لا';
    }
    if (value == 'income') return 'وارد';
    if (value == 'expense') return 'مصروف';
    if (value == 'owner') return 'صاحب الخيل';
    if (value == 'stable') return 'الإسطبل';
    if (value is double) return value.toStringAsFixed(2);
    return '$value';
  }

  List<Map<String, Object?>> _matchingAlerts(
    List<Map<String, Object?>> alerts,
    Map<String, Object?> record,
  ) {
    if (!const {'horses', 'subscribers'}.contains(widget.config.table)) {
      return const [];
    }
    final id = record['id'];
    final linkedId = widget.config.table == 'horses'
        ? record['subscriber_id']
        : record['horse_id'];
    return alerts.where((alert) {
      final isSubscription = alert['kind'] == 'subscription';
      if (widget.config.table == 'horses') {
        return isSubscription
            ? linkedId != null && alert['related_id'] == linkedId
            : alert['related_id'] == id;
      }
      return isSubscription
          ? alert['related_id'] == id
          : linkedId != null && alert['related_id'] == linkedId;
    }).toList();
  }
}

class _RecordCard extends StatefulWidget {
  const _RecordCard({
    required this.config,
    required this.record,
    required this.alerts,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.compactPhone,
    this.onPaid,
  });
  final EntityConfig config;
  final Map<String, Object?> record;
  final List<Map<String, Object?>> alerts;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool compactPhone;
  final ValueChanged<bool>? onPaid;

  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _RecordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alerts.length != widget.alerts.length) _syncPulse();
  }

  void _syncPulse() {
    if (widget.alerts.isNotEmpty) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final record = widget.record;
    final titleKey = config.displayFields.first;
    final imagePath = '${record['image_path'] ?? ''}';
    final hasRecordImage = imagePath.isNotEmpty && File(imagePath).existsSync();
    final urgentAlert = widget.alerts.any(AlertPresentation.urgent);
    final alertColor = urgentAlert ? Colors.red : Colors.orange;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Card(
        margin: widget.compactPhone
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
            : null,
        color: widget.alerts.isNotEmpty
            ? Color.lerp(Colors.white, alertColor.shade50, _pulse.value * .5)
            : null,
        elevation: widget.alerts.isNotEmpty ? 3 + (_pulse.value * 7) : null,
        shadowColor: widget.alerts.isNotEmpty
            ? alertColor.withValues(alpha: .28 + (_pulse.value * .38))
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.compactPhone ? 16 : 18),
          side: widget.alerts.isNotEmpty
              ? BorderSide(
                  color: alertColor.withValues(
                    alpha: .45 + (_pulse.value * .55),
                  ),
                  width: 1.2 + (_pulse.value * 1.8),
                )
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: widget.onOpen,
          onLongPress: widget.onEdit,
          borderRadius: BorderRadius.circular(widget.compactPhone ? 16 : 18),
          child: Padding(
            padding: EdgeInsets.all(widget.compactPhone ? 10 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (config.table == 'horses')
                      _HorseThumbnail(
                        path: imagePath,
                        compact: widget.compactPhone,
                      )
                    else if (hasRecordImage)
                      _RecordImageThumbnail(
                        path: imagePath,
                        compact: widget.compactPhone,
                      )
                    else
                      CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: .22),
                        child: Icon(
                          config.icon,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    SizedBox(width: widget.compactPhone ? 9 : 12),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              _EntityListState._display(
                                titleKey,
                                record[titleKey],
                              ),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontSize: widget.compactPhone ? 14 : null,
                                    fontWeight: FontWeight.w800,
                                  ),
                              maxLines: widget.compactPhone ? 1 : null,
                              overflow: widget.compactPhone
                                  ? TextOverflow.ellipsis
                                  : null,
                            ),
                          ),
                          if (config.table == 'subscribers' &&
                              record['is_vip'] == 1) ...[
                            SizedBox(width: widget.compactPhone ? 4 : 6),
                            Icon(
                              Icons.workspace_premium,
                              color: Color(0xFFC18B2C),
                              size: widget.compactPhone ? 18 : 22,
                            ),
                          ],
                          if (widget.alerts.isNotEmpty) ...[
                            SizedBox(width: widget.compactPhone ? 4 : 7),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: widget.compactPhone ? 6 : 8,
                                vertical: widget.compactPhone ? 3 : 4,
                              ),
                              decoration: BoxDecoration(
                                color: alertColor.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_active,
                                    size: widget.compactPhone ? 14 : 16,
                                    color: alertColor.shade800,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${widget.alerts.length}',
                                    style: TextStyle(
                                      fontSize: widget.compactPhone ? 11 : null,
                                      color: alertColor.shade900,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      style: widget.compactPhone
                          ? IconButton.styleFrom(
                              minimumSize: const Size(40, 40),
                              maximumSize: const Size(40, 40),
                              padding: EdgeInsets.zero,
                              iconSize: 21,
                            )
                          : null,
                      onPressed: widget.onEdit,
                      tooltip: 'تعديل',
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    SizedBox(width: widget.compactPhone ? 2 : 4),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        backgroundColor: Colors.red.shade50,
                        minimumSize: widget.compactPhone
                            ? const Size(40, 40)
                            : null,
                        maximumSize: widget.compactPhone
                            ? const Size(40, 40)
                            : null,
                        padding: widget.compactPhone ? EdgeInsets.zero : null,
                        iconSize: widget.compactPhone ? 21 : null,
                      ),
                      onPressed: widget.onDelete,
                      tooltip: 'حذف',
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                SizedBox(height: widget.compactPhone ? 8 : 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final fields = _compactFields(config, record);
                    final fieldWidth = widget.compactPhone
                        ? (constraints.maxWidth - 6) / 2
                        : null;
                    return Wrap(
                      spacing: widget.compactPhone ? 6 : 7,
                      runSpacing: widget.compactPhone ? 5 : 6,
                      children: fields.map((key) {
                        final pill = _FactPill(
                          label: _labelFor(config, key),
                          value: _EntityListState._display(key, record[key]),
                          compact: widget.compactPhone,
                        );
                        return fieldWidth == null
                            ? pill
                            : SizedBox(width: fieldWidth, child: pill);
                      }).toList(),
                    );
                  },
                ),
                if (widget.alerts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...widget.alerts.map(
                    (alert) => _LinkedAlertBanner(
                      alert: alert,
                      compact: widget.compactPhone,
                      onTap: () =>
                          AlertActions.openLinkedSection(context, alert),
                    ),
                  ),
                ],
                if (widget.onPaid != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FilterChip(
                      selected: record['is_paid'] == 1,
                      label: Text(
                        record['is_paid'] == 1 ? 'مسدد' : 'تعليم كمسدد',
                      ),
                      onSelected: widget.onPaid,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _labelFor(EntityConfig config, String key) =>
      config.fields
          .where((field) => field.key == key)
          .map((field) => field.label)
          .firstOrNull ??
      key;

  static List<String> _compactFields(
    EntityConfig config,
    Map<String, Object?> record,
  ) {
    final keys = config.table == 'subscribers'
        ? const [
            'member_code',
            'phone',
            'subscription_type',
            'amount',
            'end_date',
            'status',
          ]
        : config.displayFields.skip(1);
    return keys.where((key) {
      final value = record[key];
      return value != null && '$value'.trim().isNotEmpty;
    }).toList();
  }
}

class _FactPill extends StatelessWidget {
  const _FactPill({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    constraints: compact
        ? const BoxConstraints()
        : const BoxConstraints(minWidth: 128, maxWidth: 245),
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 7 : 10,
      vertical: compact ? 5 : 7,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .13),
      ),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Color(0xFF20232A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: compact ? 11 : 12),
    ),
  );
}

class _LinkedAlertBanner extends StatelessWidget {
  const _LinkedAlertBanner({
    required this.alert,
    required this.onTap,
    this.compact = false,
  });

  final Map<String, Object?> alert;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final urgent = AlertPresentation.urgent(alert);
    final color = urgent ? Colors.red : Colors.orange;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 5 : 7),
      child: Material(
        color: color.shade50,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(compact ? 12 : 14),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 8 : 10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 34 : 42,
                  height: compact ? 34 : 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(compact ? 10 : 12),
                  ),
                  child: Icon(
                    AlertPresentation.icon(alert),
                    color: color.shade800,
                    size: compact ? 20 : null,
                  ),
                ),
                SizedBox(width: compact ? 7 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نوع التنبيه: ${AlertPresentation.kind(alert)}',
                        style: TextStyle(
                          color: color.shade900,
                          fontSize: compact ? 12.5 : null,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: compact ? 1 : 2),
                      Text(
                        'السبب: ${AlertPresentation.reason(alert)}',
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 11.5 : null,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: compact ? 2 : 3),
                      Text(
                        '${alert['event_date'] ?? ''} • ${alert['status'] ?? ''} • اضغط لفتح ${AlertPresentation.targetLabel(alert)}',
                        maxLines: compact ? 2 : null,
                        overflow: compact ? TextOverflow.ellipsis : null,
                        style: TextStyle(
                          fontSize: compact ? 10.5 : 12,
                          color: color.shade800,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_circle_left_outlined,
                  color: color.shade800,
                  size: compact ? 20 : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordImageThumbnail extends StatelessWidget {
  const _RecordImageThumbnail({required this.path, this.compact = false});

  final String path;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    width: compact ? 56 : 64,
    height: compact ? 56 : 64,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFC18B2C), width: 1.5),
    ),
    clipBehavior: Clip.antiAlias,
    child: Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
    ),
  );
}

class _HorseThumbnail extends StatelessWidget {
  const _HorseThumbnail({required this.path, this.compact = false});

  final String path;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final file = path.isEmpty ? null : File(path);
    final image = file != null && file.existsSync()
        ? Image.file(file, fit: BoxFit.cover)
        : Image.asset('assets/images/horse_placeholder.jpg', fit: BoxFit.cover);
    return Container(
      width: compact ? 62 : 76,
      height: compact ? 62 : 76,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F0E4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC18B2C), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0D2A4A),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.onAdd});
  final String title;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .35),
        ),
        const SizedBox(height: 12),
        Text(title),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('إضافة سجل'),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    ),
  );
}
