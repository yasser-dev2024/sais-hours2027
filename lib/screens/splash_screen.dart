import 'package:flutter/material.dart';

import '../core/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.navy,
      body: SafeArea(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: .72, end: 1),
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutBack,
            builder: (_, scale, child) => Opacity(
              opacity: scale.clamp(0, 1),
              child: Transform.scale(scale: scale, child: child),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, child) => Container(
                    width: 180,
                    height: 180,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(42),
                      border: Border.all(
                        color: AppConstants.gold.withValues(
                          alpha: .55 + (_controller.value * .45),
                        ),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppConstants.gold.withValues(
                            alpha: .18 + (_controller.value * .24),
                          ),
                          blurRadius: 24 + (_controller.value * 18),
                          spreadRadius: 1 + (_controller.value * 4),
                        ),
                        const BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(34),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'إدارة الخيل والإسطبل بثقة',
                  style: TextStyle(color: AppConstants.gold, fontSize: 16),
                ),
                const SizedBox(height: 30),
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    color: AppConstants.gold,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'جارٍ تجهيز سجلاتك بأمان…',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
