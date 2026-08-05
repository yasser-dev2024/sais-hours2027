import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/app_provider.dart';
import '../screens/home_shell.dart';
import '../screens/full_screen_alert.dart';
import '../screens/permissions_setup_screen.dart';
import '../screens/splash_screen.dart';
import '../services/notification_service.dart';
import 'app_theme.dart';

class HorseClubApp extends StatelessWidget {
  const HorseClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(primary: app.primaryColor, accent: app.accentColor),
      home: ValueListenableBuilder<NotificationLaunchData?>(
        valueListenable: NotificationService.instance.launchedAlert,
        builder: (_, launched, __) => Directionality(
          textDirection: TextDirection.rtl,
          child: launched != null && !app.loading && app.error == null
              ? FullScreenAlert(data: launched)
              : _RootContent(app: app),
        ),
      ),
    );
  }
}

class _RootContent extends StatelessWidget {
  const _RootContent({required this.app});
  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    if (app.loading) return const SplashScreen();
    if (app.error != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppConstants.danger,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تعذر تشغيل سايس الخيل',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(app.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: app.initialize,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (!app.permissionsSetupSeen) return const PermissionsSetupScreen();
    return const HomeShell();
  }
}
