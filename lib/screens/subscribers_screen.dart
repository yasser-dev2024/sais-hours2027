import 'package:flutter/material.dart';

import '../core/entity_config.dart';
import '../widgets/entity_list.dart';
import 'subscriber_details_screen.dart';

class SubscribersScreen extends StatelessWidget {
  const SubscribersScreen({super.key});
  @override
  Widget build(BuildContext context) => EntityList(
    config: EntityConfigs.subscriber,
    onOpen: (subscriber) => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriberDetailsScreen(subscriber: subscriber),
      ),
    ),
  );
}
