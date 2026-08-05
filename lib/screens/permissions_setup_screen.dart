import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/app_provider.dart';
import '../services/notification_service.dart';

class PermissionsSetupScreen extends StatefulWidget {
  const PermissionsSetupScreen({super.key});

  @override
  State<PermissionsSetupScreen> createState() => _PermissionsSetupScreenState();
}

class _PermissionsSetupScreenState extends State<PermissionsSetupScreen> {
  bool _working = false;
  bool? _cameraGranted;
  bool? _notificationsGranted;

  @override
  void initState() {
    super.initState();
    _readStatus();
  }

  Future<void> _readStatus() async {
    final camera = await Permission.camera.isGranted;
    final notifications = await NotificationService.instance
        .notificationsEnabled();
    if (!mounted) return;
    setState(() {
      _cameraGranted = camera;
      _notificationsGranted = notifications;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F5EE),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/icons/app_icon.png', width: 92),
                    const SizedBox(height: 14),
                    const Text(
                      'تجهيز سايس الخيل',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: AppConstants.navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'اسمح بالخصائص الأساسية مرة واحدة لتعمل الكاميرا والتنبيهات خارج التطبيق من البداية.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    _PermissionTile(
                      icon: Icons.camera_alt_outlined,
                      title: 'الكاميرا',
                      subtitle:
                          'تصوير الخيل والعلاج والغرفة والتحذية والتمارين',
                      granted: _cameraGranted,
                    ),
                    _PermissionTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'الإشعارات',
                      subtitle:
                          'صوت jrs وظهور اسم الخيل أو المشترك خارج التطبيق',
                      granted: _notificationsGranted,
                    ),
                    const _PermissionTile(
                      icon: Icons.fullscreen,
                      title: 'تنبيهات ملء الشاشة',
                      subtitle:
                          'قد يفتح أندرويد صفحة إعداد للسماح بها مرة واحدة',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _working ? null : _requestAll,
                        icon: _working
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.verified_user_outlined),
                        label: Text(
                          _working ? 'جارٍ طلب الأذونات…' : 'السماح والمتابعة',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _working ? null : _continue,
                      child: const Text('الدخول الآن وإكمال الأذونات لاحقًا'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _requestAll() async {
    setState(() => _working = true);
    final camera = await Permission.camera.request();
    final notifications = await NotificationService.instance
        .requestPermission();
    if (!mounted) return;
    setState(() {
      _cameraGranted = camera.isGranted;
      _notificationsGranted = notifications;
      _working = false;
    });
    if (!camera.isGranted || !notifications) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'بعض الأذونات لم تُفعّل. يمكنك تعديلها من إعدادات الجهاز.',
          ),
          action: SnackBarAction(
            label: 'الإعدادات',
            onPressed: openAppSettings,
          ),
        ),
      );
    }
    await _continue();
  }

  Future<void> _continue() async {
    await context.read<AppProvider>().completePermissionsSetup();
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.granted,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool? granted;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(child: Icon(icon)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
    subtitle: Text(subtitle),
    trailing: granted == null
        ? const Icon(Icons.info_outline)
        : Icon(
            granted! ? Icons.check_circle : Icons.cancel_outlined,
            color: granted! ? Colors.green : Colors.orange,
          ),
  );
}
