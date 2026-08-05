import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/app_provider.dart';
import 'alerts_screen.dart';
import 'daily_bookings_screen.dart';
import 'dashboard_screen.dart';
import 'finances_screen.dart';
import 'financial_ledger_screen.dart';
import 'horses_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'subscribers_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _selected = 0;

  static const _destinations = <_Destination>[
    _Destination('الرئيسية', Icons.dashboard_outlined, Icons.dashboard),
    _Destination('الخيول', Icons.pets_outlined, Icons.pets),
    _Destination(
      'المالية',
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
    ),
    _Destination('المشتركون', Icons.people_outline, Icons.people),
    _Destination(
      'الحجوزات اليومية',
      Icons.event_note_outlined,
      Icons.event_note,
    ),
    _Destination(
      'السجل المالي',
      Icons.receipt_long_outlined,
      Icons.receipt_long,
    ),
    _Destination('التقارير', Icons.assessment_outlined, Icons.assessment),
    _Destination('الإعدادات', Icons.settings_outlined, Icons.settings),
  ];

  static const _pages = <Widget>[
    DashboardScreen(),
    HorsesScreen(),
    FinancesScreen(),
    SubscribersScreen(),
    DailyBookingsScreen(),
    FinancialLedgerScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppProvider>().onAppResumed();
    }
  }

  void _select(int index) {
    setState(() => _selected = index);
    if (Scaffold.maybeOf(context)?.isDrawerOpen == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final phone = width < 600;
    final content = IndexedStack(index: _selected, children: _pages);
    return Scaffold(
      appBar: AppBar(
        title: Text(_destinations[_selected].label),
        actions: [
          _AlertBellButton(
            count: context.watch<AppProvider>().alerts.length,
            compact: phone,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlertsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: context.read<AppProvider>().refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: wide
          ? null
          : NavigationDrawer(
              selectedIndex: _selected,
              onDestinationSelected: (index) {
                Navigator.pop(context);
                setState(() => _selected = index);
              },
              children: [
                const _DrawerHeader(),
                ..._destinations.map(
                  (destination) => NavigationDrawerDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
                ),
              ],
            ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  extended: MediaQuery.sizeOf(context).width >= 1180,
                  selectedIndex: _selected,
                  onDestinationSelected: _select,
                  leading: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      width: 64,
                      height: 64,
                    ),
                  ),
                  destinations: _destinations
                      .map(
                        (destination) => NavigationRailDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selectedIcon),
                          label: Text(destination.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : content,
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/icons/app_icon.png',
              width: 70,
              height: 70,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppConstants.appName,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                Text('إدارة الخيل والإسطبل'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _AlertBellButton extends StatefulWidget {
  const _AlertBellButton({
    required this.count,
    required this.onPressed,
    this.compact = false,
  });

  final int count;
  final VoidCallback onPressed;
  final bool compact;

  @override
  State<_AlertBellButton> createState() => _AlertBellButtonState();
}

class _AlertBellButtonState extends State<_AlertBellButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotation;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _rotation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0), weight: 46),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.035), weight: 7),
      TweenSequenceItem(tween: Tween(begin: -0.035, end: 0.035), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.035, end: -0.025), weight: 10),
      TweenSequenceItem(tween: Tween(begin: -0.025, end: 0.025), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.025, end: 0.0), weight: 7),
      TweenSequenceItem(tween: ConstantTween(0), weight: 10),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _pulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: .20, end: .55), weight: 50),
      TweenSequenceItem(tween: Tween(begin: .55, end: .20), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _AlertBellButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.count > 0) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countLabel = widget.count > 99 ? '99+' : '${widget.count}';
    return Semantics(
      button: true,
      label: widget.count == 0
          ? 'مركز التنبيهات، لا توجد تنبيهات'
          : 'مركز التنبيهات، ${widget.count} تنبيه',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Container(
          width: widget.compact ? 48 : 58,
          height: widget.compact ? 46 : 54,
          margin: const EdgeInsetsDirectional.only(end: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: widget.count > 0
                ? [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: _pulse.value * .48),
                      blurRadius: 9 + (_pulse.value * 8),
                      spreadRadius: _pulse.value * 2.5,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IconButton.filledTonal(
                  tooltip: 'فتح مركز التنبيهات',
                  onPressed: widget.onPressed,
                  icon: RotationTransition(
                    turns: _rotation,
                    child: Icon(
                      widget.count > 0
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                      size: widget.compact ? 24 : 29,
                      color: widget.count > 0
                          ? Colors.red.shade700
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              if (widget.count > 0)
                PositionedDirectional(
                  top: -2,
                  end: -2,
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: widget.compact ? 20 : 23,
                      minHeight: widget.compact ? 20 : 23,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.compact ? 4 : 5,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      countLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ).copyWith(fontSize: widget.compact ? 9 : 10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
