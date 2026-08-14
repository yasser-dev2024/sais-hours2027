import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/splash_screen.dart';
import 'license_models.dart';
import 'license_service.dart';
import 'screens/activation_screen.dart';
import 'screens/agreement_screen.dart';

class LicenseGate extends StatefulWidget {
  const LicenseGate({
    required this.child,
    this.service,
    this.onAccessGranted,
    super.key,
  });

  final Widget child;
  final LicenseService? service;
  final Future<void> Function()? onAccessGranted;

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> with WidgetsBindingObserver {
  late final LicenseService _service;
  LicenseSnapshot? _snapshot;
  Timer? _clockCheckTimer;
  Timer? _expirationTimer;
  bool _refreshing = false;
  bool _applicationInitialized = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? LicenseService();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockCheckTimer?.cancel();
    _expirationTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _initialize() async {
    final snapshot = await _service.initialize();
    await _applySnapshot(snapshot);
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final snapshot = await _service.refresh();
      await _applySnapshot(snapshot);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _acceptAgreement() async {
    final snapshot = await _service.acceptAgreement();
    await _applySnapshot(snapshot);
  }

  Future<ActivationAttempt> _activate(String code) async {
    final attempt = await _service.activate(code);
    if (attempt.success) {
      await _applySnapshot(_service.snapshot!);
    }
    return attempt;
  }

  Future<void> _applySnapshot(LicenseSnapshot snapshot) async {
    if (snapshot.canUseApplication && !_applicationInitialized) {
      await widget.onAccessGranted?.call();
      if (!mounted) return;
      _applicationInitialized = true;
    }
    _configureTimers(snapshot);
    if (mounted) setState(() => _snapshot = snapshot);
  }

  void _configureTimers(LicenseSnapshot snapshot) {
    _expirationTimer?.cancel();
    if (snapshot.access == LicenseAccess.trial) {
      _clockCheckTimer ??= Timer.periodic(
        const Duration(minutes: 5),
        (_) => _refresh(),
      );
      _expirationTimer = Timer(
        snapshot.trialRemaining + const Duration(milliseconds: 100),
        _refresh,
      );
    } else {
      _clockCheckTimer?.cancel();
      _clockCheckTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (snapshot == null) return const SplashScreen();
    if (snapshot.access == LicenseAccess.storageUnavailable) {
      return ActivationScreen(
        installationId: snapshot.installationId,
        initialMessage: snapshot.detail,
        onActivate: _activate,
      );
    }
    if (!snapshot.agreementAccepted) {
      return AgreementScreen(onAccepted: _acceptAgreement);
    }
    if (snapshot.canUseApplication) return widget.child;
    return ActivationScreen(
      installationId: snapshot.installationId,
      initialMessage: snapshot.detail,
      onActivate: _activate,
    );
  }
}
