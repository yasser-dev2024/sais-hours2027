import 'package:flutter/material.dart';

import '../core/entity_config.dart';
import '../widgets/entity_list.dart';
import 'horse_details_screen.dart';

class HorsesScreen extends StatelessWidget {
  const HorsesScreen({super.key});
  @override
  Widget build(BuildContext context) => EntityList(
    config: EntityConfigs.horse,
    onOpen: (horse) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HorseDetailsScreen(horse: horse)),
    ),
  );
}
