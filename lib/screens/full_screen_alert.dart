import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/app_provider.dart';
import '../services/alert_actions.dart';
import '../services/alert_sound_service.dart';
import '../services/notification_service.dart';

class FullScreenAlert extends StatefulWidget {
  const FullScreenAlert({super.key, required this.data});

  final NotificationLaunchData data;

  @override
  State<FullScreenAlert> createState() => _FullScreenAlertState();
}

class _FullScreenAlertState extends State<FullScreenAlert>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  Map<String, Object?> get alert => widget.data.alert;

  @override
  void initState() {
    super.initState();
    unawaited(AlertSoundService.instance.play(loop: true));
  }

  @override
  void dispose() {
    unawaited(AlertSoundService.instance.stop());
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subscription = alert['kind'] == 'subscription';
    final subject = subscription
        ? '${alert['title'] ?? 'مشترك'}'
        : '${alert['horse_name'] ?? alert['title'] ?? 'خيل'}';
    final urgent =
        '${alert['status']}'.contains('متأخر') ||
        '${alert['status']}'.contains('منتهي');
    final color = urgent ? Colors.red : Colors.orange;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _dismiss(),
      child: Scaffold(
        backgroundColor: AppConstants.navy,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: IconButton.filledTonal(
                    tooltip: 'إغلاق',
                    onPressed: _dismiss,
                    icon: const Icon(Icons.close),
                  ),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) => Container(
                    width: 136,
                    height: 136,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: .16),
                      border: Border.all(
                        color: color.withValues(
                          alpha: .55 + (_pulse.value * .45),
                        ),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(
                            alpha: .3 + (_pulse.value * .35),
                          ),
                          blurRadius: 28 + (_pulse.value * 32),
                          spreadRadius: 2 + (_pulse.value * 7),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                  child: Icon(
                    subscription
                        ? Icons.person_pin_circle_outlined
                        : Icons.notifications_active,
                    color: Colors.white,
                    size: 68,
                  ),
                ),
                const SizedBox(height: 34),
                const Text(
                  'تنبيه سايس الخيل',
                  style: TextStyle(
                    color: AppConstants.gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  subscription ? 'المشترك: $subject' : 'الخيل: $subject',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'نوع التنبيه: ${AlertPresentation.kind(alert)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'السبب: ${AlertPresentation.reason(alert)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  '${alert['event_date'] ?? ''}  •  ${alert['status'] ?? ''}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color.shade200,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openSection,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(
                      'فتح ${AlertPresentation.targetLabel(alert)} مباشرة',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _edit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('تعديل'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.red.shade900,
                          backgroundColor: Colors.red.shade100,
                        ),
                        onPressed: _delete,
                        icon: const Icon(Icons.visibility_off_outlined),
                        label: const Text('إخفاء التنبيه'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    onPressed: _stop,
                    icon: const Icon(Icons.notifications_off_outlined),
                    label: const Text('إيقاف هذا التنبيه'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSection() async {
    await AlertSoundService.instance.stop();
    if (!mounted) return;
    await AlertActions.openLinkedSection(context, alert);
    if (!mounted) return;
    await NotificationService.instance.cancel(widget.data.notificationId);
    NotificationService.instance.clearLaunchedAlert();
  }

  Future<void> _edit() async {
    await AlertSoundService.instance.stop();
    if (!mounted) return;
    final changed = await AlertActions.edit(context, alert);
    if (changed && mounted) {
      await NotificationService.instance.cancel(widget.data.notificationId);
      NotificationService.instance.clearLaunchedAlert();
    }
  }

  Future<void> _delete() async {
    await AlertSoundService.instance.stop();
    if (!mounted) return;
    final dismissed = await AlertActions.dismiss(context, alert);
    if (dismissed && mounted) {
      await NotificationService.instance.cancel(widget.data.notificationId);
      NotificationService.instance.clearLaunchedAlert();
    }
  }

  Future<void> _stop() async {
    await AlertSoundService.instance.stop();
    if (!mounted) return;
    await context.read<AppProvider>().muteAlert(alert);
    await NotificationService.instance.cancel(widget.data.notificationId);
    NotificationService.instance.clearLaunchedAlert();
  }

  Future<void> _dismiss() async {
    await AlertSoundService.instance.stop();
    await NotificationService.instance.cancel(widget.data.notificationId);
    NotificationService.instance.clearLaunchedAlert();
  }
}
