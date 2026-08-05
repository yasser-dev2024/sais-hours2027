import 'package:flutter/material.dart';

import '../core/entity_config.dart';
import '../widgets/entity_list.dart';

class EntityPage extends StatelessWidget {
  const EntityPage({
    super.key,
    required this.config,
    this.forcedValues = const {},
    this.where,
    this.whereArgs,
  });
  final EntityConfig config;
  final Map<String, Object?> forcedValues;
  final String? where;
  final List<Object?>? whereArgs;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(config.title)),
    body: SafeArea(
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutBack,
            builder: (context, value, child) => Opacity(
              opacity: value.clamp(0, 1),
              child: Transform.scale(scale: .9 + (.1 * value), child: child),
            ),
            child: Container(
              height: 82,
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .82),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .2),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(config.icon, color: Colors.white, size: 31),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'اضغط للفتح • اضغط مطولًا للتعديل',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .78),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Image.asset(
                    'assets/images/splash_logo.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: EntityList(
              config: config,
              forcedValues: forcedValues,
              where: where,
              whereArgs: whereArgs,
            ),
          ),
        ],
      ),
    ),
  );
}
