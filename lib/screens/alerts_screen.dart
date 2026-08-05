import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/entity_config.dart';
import '../providers/app_provider.dart';
import '../services/alert_actions.dart';
import '../services/alert_sound_service.dart';
import 'entity_page.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _filter = 'all';
  String? _soundMessage;
  bool _testingSound = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final phone = MediaQuery.sizeOf(context).width < 600;
    final urgent = app.alerts.where(_isUrgent).length;
    final source = _filter == 'muted' ? app.mutedAlerts : app.alerts;
    final visible = source.where((alert) {
      return switch (_filter) {
        'urgent' => _isUrgent(alert),
        'appointments' => alert['kind'] == 'appointment',
        'boarding' => alert['kind'] == 'boarding',
        'subscriptions' => alert['kind'] == 'subscription',
        'muted' => true,
        _ => true,
      };
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز التنبيهات'),
        actions: [
          IconButton(
            tooltip: 'كل المواعيد',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const EntityPage(config: EntityConfigs.appointment),
              ),
            ),
            icon: const Icon(Icons.event_note),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: app.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: app.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: phone
              ? const EdgeInsets.fromLTRB(6, 8, 6, 80)
              : const EdgeInsets.fromLTRB(12, 12, 12, 80),
          children: [
            Row(
              children: [
                Expanded(
                  child: _AlertSummary(
                    label: 'كل التنبيهات',
                    value: app.alerts.length,
                    icon: Icons.notifications_active,
                    color: const Color(0xFF2A6592),
                    compact: phone,
                  ),
                ),
                Expanded(
                  child: _AlertSummary(
                    label: 'عاجلة ومتأخرة',
                    value: urgent,
                    icon: Icons.warning_amber,
                    color: Colors.red.shade700,
                    compact: phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (phone)
              _MobileNotificationControls(
                message:
                    _soundMessage ??
                    'الإشعارات وصوت jrs يعملان افتراضيًا بعد إذن Android الأول.',
                testingSound: _testingSound,
                onTestSound: _testSound,
                onStopSound: _stopSound,
              )
            else
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notifications_active, size: 32),
                      title: const Text(
                        'إشعارات الجهاز وصوت jrs.mp3 الافتراضي',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        _soundMessage ??
                            'لا يوجد زر تفعيل؛ يعمل الإنذار تلقائيًا بعد إذن Android الأول.',
                      ),
                      trailing: const Chip(
                        avatar: Icon(Icons.check_circle_outline, size: 18),
                        label: Text('افتراضي'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _testingSound ? null : _testSound,
                              icon: Icon(
                                _testingSound
                                    ? Icons.graphic_eq
                                    : Icons.volume_up_rounded,
                              ),
                              label: Text(
                                _testingSound
                                    ? 'يعمل صوت jrs الآن...'
                                    : 'اختبار صوت jrs.mp3',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: _stopSound,
                            tooltip: 'إيقاف اختبار الصوت',
                            icon: const Icon(Icons.stop_circle_outlined),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            if (phone)
              _MobileAlertFilters(
                selected: _filter,
                onSelected: (value) => setState(() => _filter = value),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'all',
                      label: Text('الكل'),
                      icon: Icon(Icons.inbox),
                    ),
                    ButtonSegment(
                      value: 'urgent',
                      label: Text('العاجلة'),
                      icon: Icon(Icons.priority_high),
                    ),
                    ButtonSegment(
                      value: 'appointments',
                      label: Text('المواعيد'),
                      icon: Icon(Icons.event),
                    ),
                    ButtonSegment(
                      value: 'subscriptions',
                      label: Text('الاشتراكات'),
                      icon: Icon(Icons.people),
                    ),
                    ButtonSegment(
                      value: 'boarding',
                      label: Text('الإيواء'),
                      icon: Icon(Icons.home_work_outlined),
                    ),
                    ButtonSegment(
                      value: 'muted',
                      label: Text('الموقفة'),
                      icon: Icon(Icons.notifications_off_outlined),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (value) =>
                      setState(() => _filter = value.first),
                ),
              ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Icon(Icons.task_alt, size: 54, color: Colors.green),
                      SizedBox(height: 10),
                      Text(
                        'لا توجد تنبيهات في هذا التصنيف',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...visible.asMap().entries.map(
                (entry) => TweenAnimationBuilder<double>(
                  key: ValueKey('${entry.value['kind']}:${entry.value['id']}'),
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(
                    milliseconds: 280 + entry.key.clamp(0, 6) * 45,
                  ),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: _AlertCard(
                    alert: entry.value,
                    muted: _filter == 'muted',
                    compact: phone,
                    onOpen: () => _open(entry.value),
                    onEdit: () => _edit(entry.value),
                    onDelete: () => AlertActions.dismiss(context, entry.value),
                    onToggleMuted: () => _filter == 'muted'
                        ? app.unmuteAlert(entry.value)
                        : app.muteAlert(entry.value),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _testSound() async {
    setState(() {
      _testingSound = true;
      _soundMessage = 'جارٍ تشغيل ملف jrs.mp3 عبر مكبر صوت الإنذار...';
    });
    final played = await AlertSoundService.instance.play();
    if (!mounted) return;
    setState(() {
      _soundMessage = played
          ? 'تم تشغيل jrs.mp3. استخدم زر الإيقاف عند الحاجة.'
          : 'تعذر تشغيل الصوت؛ تأكد من مستوى صوت المنبه في الجهاز.';
      _testingSound = false;
    });
  }

  Future<void> _stopSound() async {
    await AlertSoundService.instance.stop();
    if (!mounted) return;
    setState(() {
      _testingSound = false;
      _soundMessage = 'تم إيقاف اختبار الصوت.';
    });
  }

  Future<void> _open(Map<String, Object?> alert) =>
      AlertActions.openLinkedSection(context, alert);

  Future<void> _edit(Map<String, Object?> alert) =>
      AlertActions.edit(context, alert);

  static bool _isUrgent(Map<String, Object?> alert) {
    final status = '${alert['status']}';
    return status.contains('متأخر') || status.contains('منتهي');
  }
}

class _MobileNotificationControls extends StatelessWidget {
  const _MobileNotificationControls({
    required this.message,
    required this.testingSound,
    required this.onTestSound,
    required this.onStopSound,
  });

  final String message;
  final bool testingSound;
  final VoidCallback onTestSound;
  final VoidCallback onStopSound;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.notifications_active,
                  size: 22,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إشعارات الجهاز • jrs.mp3',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    textStyle: const TextStyle(
                      fontFamily: 'NotoSansArabic',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: testingSound ? null : onTestSound,
                  icon: Icon(
                    testingSound ? Icons.graphic_eq : Icons.volume_up_rounded,
                    size: 19,
                  ),
                  label: Text(
                    testingSound ? 'الصوت يعمل...' : 'اختبار الصوت',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  maximumSize: const Size(40, 40),
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                ),
                onPressed: onStopSound,
                tooltip: 'إيقاف اختبار الصوت',
                icon: const Icon(Icons.stop_circle_outlined),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MobileAlertFilters extends StatelessWidget {
  const _MobileAlertFilters({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  static const _filters = <(String, String, IconData)>[
    ('all', 'الكل', Icons.inbox),
    ('urgent', 'العاجلة', Icons.priority_high),
    ('appointments', 'المواعيد', Icons.event),
    ('subscriptions', 'الاشتراكات', Icons.people),
    ('boarding', 'الإيواء', Icons.home_work_outlined),
    ('muted', 'الموقفة', Icons.notifications_off_outlined),
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: _filters
          .map(
            (filter) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: ChoiceChip(
                selected: selected == filter.$1,
                showCheckmark: false,
                avatar: Icon(filter.$3, size: 16),
                label: Text(filter.$2, style: const TextStyle(fontSize: 11.5)),
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -2,
                ),
                onSelected: (_) => onSelected(filter.$1),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class _AlertSummary extends StatelessWidget {
  const _AlertSummary({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.compact = false,
  });
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) => Card(
    margin: compact
        ? const EdgeInsets.symmetric(horizontal: 4, vertical: 4)
        : null,
    child: Padding(
      padding: EdgeInsets.all(compact ? 9 : 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: compact ? 17 : null,
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(icon, color: color, size: compact ? 19 : null),
          ),
          SizedBox(width: compact ? 7 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: compact ? 19 : 24,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: compact ? 11 : null),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.muted,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleMuted,
    this.compact = false,
  });
  final Map<String, Object?> alert;
  final bool muted;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleMuted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final urgent = _AlertsScreenState._isUrgent(alert);
    final icon = AlertPresentation.icon(alert);
    final kind = AlertPresentation.kind(alert);
    if (compact) {
      final color = urgent ? Colors.red : Colors.orange;
      final iconStyle = IconButton.styleFrom(
        minimumSize: const Size(38, 38),
        maximumSize: const Size(38, 38),
        padding: EdgeInsets.zero,
        iconSize: 20,
      );
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 9, 9, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: color.withValues(alpha: .12),
                      child: Icon(
                        icon,
                        size: 20,
                        color: urgent
                            ? Colors.red.shade700
                            : Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'نوع التنبيه: $kind',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'السبب: ${AlertPresentation.reason(alert)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${AlertPresentation.subject(alert)} • ${alert['event_date'] ?? ''} • ${alert['status'] ?? ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color.shade800,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_circle_left_outlined,
                      size: 20,
                      color: color.shade800,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              color: color.withValues(alpha: .055),
              padding: const EdgeInsets.fromLTRB(7, 5, 7, 6),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(
                          fontFamily: 'NotoSansArabic',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: onOpen,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(
                        'فتح ${AlertPresentation.targetLabel(alert)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  IconButton(
                    style: iconStyle,
                    onPressed: onEdit,
                    tooltip: 'تعديل السجل',
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    style: iconStyle,
                    onPressed: onDelete,
                    tooltip: 'إخفاء التنبيه مع إبقاء السجل',
                    color: Colors.red.shade700,
                    icon: const Icon(Icons.visibility_off_outlined),
                  ),
                  IconButton(
                    style: iconStyle,
                    onPressed: onToggleMuted,
                    tooltip: muted ? 'إعادة تفعيل التنبيه' : 'إيقاف التنبيه',
                    icon: Icon(
                      muted
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            onTap: onOpen,
            leading: CircleAvatar(
              backgroundColor: (urgent ? Colors.red : Colors.orange).withValues(
                alpha: .12,
              ),
              child: Icon(
                icon,
                color: urgent ? Colors.red.shade700 : Colors.orange.shade800,
              ),
            ),
            title: Text(
              'نوع التنبيه: $kind',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              'السبب: ${AlertPresentation.reason(alert)}\n${AlertPresentation.subject(alert)} • ${alert['event_date'] ?? ''} • ${alert['status'] ?? ''}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.arrow_circle_left_outlined),
          ),
          Container(
            color: (urgent ? Colors.red : Colors.orange).withValues(
              alpha: .055,
            ),
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new),
                    label: Text('فتح ${AlertPresentation.targetLabel(alert)}'),
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'تعديل السجل',
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'إخفاء التنبيه مع إبقاء السجل',
                  color: Colors.red.shade700,
                  icon: const Icon(Icons.visibility_off_outlined),
                ),
                IconButton(
                  onPressed: onToggleMuted,
                  tooltip: muted ? 'إعادة تفعيل التنبيه' : 'إيقاف التنبيه',
                  icon: Icon(
                    muted
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
