import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/entity_config.dart';
import '../providers/app_provider.dart';
import '../services/alert_actions.dart';
import '../widgets/entity_editor.dart';
import 'alerts_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final phone = MediaQuery.sizeOf(context).width < 600;
    final stats = app.stats;
    final cards = <(String, Object?, IconData, Color)>[
      (
        'إجمالي الخيول',
        stats['total_horses'],
        Icons.pets,
        const Color(0xFF2A6592),
      ),
      (
        'بصحة جيدة',
        stats['healthy_horses'],
        Icons.favorite,
        const Color(0xFF21845A),
      ),
      (
        'تحتاج متابعة',
        stats['sick_horses'],
        Icons.health_and_safety,
        const Color(0xFFC65B52),
      ),
      (
        'مواعيد قادمة',
        stats['upcoming_appointments'],
        Icons.event_available,
        const Color(0xFF6B5FB5),
      ),
      (
        'مواعيد متأخرة',
        stats['overdue_appointments'],
        Icons.event_busy,
        const Color(0xFFB14D3E),
      ),
      (
        'اشتراكات نشطة',
        stats['active'],
        Icons.verified,
        const Color(0xFF21845A),
      ),
      (
        'قريبة الانتهاء',
        stats['expiring'],
        Icons.hourglass_bottom,
        const Color(0xFFD39028),
      ),
      (
        'دفعات إيواء متأخرة',
        stats['overdue_boarding'],
        Icons.home_work,
        const Color(0xFF9E4E5B),
      ),
      (
        'إجمالي المشتركين',
        stats['total'],
        Icons.groups,
        const Color(0xFF2A6592),
      ),
      (
        'مشتركون مميزون',
        stats['vip_subscribers'],
        Icons.workspace_premium,
        const Color(0xFFC18B2C),
      ),
    ];
    return RefreshIndicator(
      onRefresh: app.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: phone
                ? const EdgeInsets.fromLTRB(8, 8, 8, 4)
                : const EdgeInsets.fromLTRB(12, 12, 12, 6),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.all(phone ? 14 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(phone ? 20 : 24),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: .45),
                  ),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icons/app_icon.png',
                      width: phone ? 58 : 78,
                      height: phone ? 58 : 78,
                    ),
                    SizedBox(width: phone ? 11 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مرحبًا بك في سايس الخيل',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontSize: phone ? 19 : null,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'إدارة متكاملة وآمنة لبيانات الخيول والإسطبل',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontSize: phone ? 12.5 : null),
                            maxLines: phone ? 2 : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: phone
                ? const EdgeInsets.fromLTRB(8, 4, 8, 6)
                : const EdgeInsets.fromLTRB(12, 6, 12, 8),
            sliver: SliverToBoxAdapter(
              child: Card(
                margin: phone ? EdgeInsets.zero : null,
                child: Padding(
                  padding: EdgeInsets.all(phone ? 10 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إضافة سريعة',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 9),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final buttonWidth = phone
                              ? (constraints.maxWidth - 8) / 2
                              : null;
                          final buttons = [
                            _QuickAdd(
                              label: 'خيل',
                              icon: Icons.pets,
                              compact: phone,
                              onTap: () =>
                                  _add(context, app, EntityConfigs.horse),
                            ),
                            _QuickAdd(
                              label: 'مشترك',
                              icon: Icons.person_add,
                              compact: phone,
                              onTap: () =>
                                  _add(context, app, EntityConfigs.subscriber),
                            ),
                            _QuickAdd(
                              label: 'موعد',
                              icon: Icons.event_available,
                              compact: phone,
                              onTap: () =>
                                  _add(context, app, EntityConfigs.appointment),
                            ),
                            _QuickAdd(
                              label: 'حجز يومي',
                              icon: Icons.calendar_month,
                              compact: phone,
                              onTap: () =>
                                  _add(context, app, EntityConfigs.booking),
                            ),
                          ];
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: buttonWidth == null
                                ? buttons
                                : buttons
                                      .map(
                                        (button) => SizedBox(
                                          width: buttonWidth,
                                          child: button,
                                        ),
                                      )
                                      .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.all(phone ? 4 : 8),
            sliver: SliverGrid.builder(
              itemCount: cards.length,
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: phone ? 200 : 260,
                mainAxisExtent: phone ? 112 : 142,
                crossAxisSpacing: phone ? 2 : 4,
                mainAxisSpacing: phone ? 2 : 4,
              ),
              itemBuilder: (_, index) =>
                  _StatCard(data: cards[index], compact: phone),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'التنبيهات',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AlertsScreen()),
                    ),
                    icon: const Icon(Icons.notifications_active),
                    label: Text('عرض الكل (${app.alerts.length})'),
                  ),
                ],
              ),
            ),
          ),
          if (app.alerts.isEmpty)
            const SliverToBoxAdapter(child: _NoAlerts())
          else
            SliverList.builder(
              itemCount: app.alerts.length,
              itemBuilder: (_, index) => _AlertTile(alert: app.alerts[index]),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  static Future<void> _add(
    BuildContext context,
    AppProvider app,
    EntityConfig config,
  ) async {
    final changed = await EntityEditorDialog.show(context, config: config);
    if (changed) await app.dataChanged();
  }
}

class _QuickAdd extends StatelessWidget {
  const _QuickAdd({
    required this.label,
    required this.icon,
    required this.onTap,
    this.compact = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;
  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    onPressed: onTap,
    style: compact
        ? FilledButton.styleFrom(
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 7),
            textStyle: const TextStyle(
              fontFamily: 'NotoSansArabic',
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          )
        : null,
    icon: Icon(icon, size: compact ? 20 : null),
    label: Text('إضافة $label', maxLines: compact ? 1 : null),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data, this.compact = false});
  final (String, Object?, IconData, Color) data;
  final bool compact;
  @override
  Widget build(BuildContext context) => Card(
    margin: compact ? const EdgeInsets.all(4) : null,
    child: Padding(
      padding: EdgeInsets.all(compact ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: compact ? 18 : null,
            backgroundColor: data.$4.withValues(alpha: .13),
            child: Icon(data.$3, color: data.$4, size: compact ? 20 : null),
          ),
          const Spacer(),
          Text(
            '${data.$2 ?? 0}',
            style: TextStyle(
              fontSize: compact ? 21 : 25,
              fontWeight: FontWeight.w900,
              color: data.$4,
            ),
          ),
          Text(
            data.$1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: compact ? 11.5 : null),
          ),
        ],
      ),
    ),
  );
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});
  final Map<String, Object?> alert;
  @override
  Widget build(BuildContext context) {
    final overdue =
        '${alert['status']}'.contains('متأخر') ||
        '${alert['status']}'.contains('منتهي');
    return Card(
      child: ListTile(
        onTap: () => AlertActions.openLinkedSection(context, alert),
        leading: CircleAvatar(
          backgroundColor: (overdue ? Colors.red : Colors.orange).withValues(
            alpha: .12,
          ),
          child: Icon(
            overdue ? Icons.warning_amber : Icons.notifications_active,
            color: overdue ? Colors.red : Colors.orange.shade800,
          ),
        ),
        title: Text(
          'نوع التنبيه: ${AlertPresentation.kind(alert)}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'السبب: ${AlertPresentation.reason(alert)}\n${AlertPresentation.subject(alert)} • ${alert['event_date'] ?? ''}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${alert['status'] ?? ''}',
              style: TextStyle(
                color: overdue ? Colors.red : Colors.orange.shade900,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Icon(Icons.arrow_circle_left_outlined),
          ],
        ),
      ),
    );
  }
}

class _NoAlerts extends StatelessWidget {
  const _NoAlerts();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700),
          const SizedBox(width: 10),
          const Flexible(
            child: Text('لا توجد تنبيهات حالية — كل شيء على ما يرام'),
          ),
        ],
      ),
    ),
  );
}
