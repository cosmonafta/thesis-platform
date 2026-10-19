
import 'package:flutter/material.dart';

import '../models/conversation_scenario.dart';

class ConversationScenarioView extends StatelessWidget {
  final ConversationScenario scenario;
  final bool isCaller;

  const ConversationScenarioView({
    super.key,
    required this.scenario,
    required this.isCaller,
  });

  @override
  Widget build(BuildContext context) {
    final ConversationRole role =
        isCaller ? scenario.caller : scenario.receiver;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          scenario.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your role: ${role.roleName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You are: ${role.participantName}',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your task',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(role.task),
              ],
            ),
          ),
        ),

        _section(
          'Conditions',
          role.conditions,
        ),

        _section(
          'Information to find',
          role.informationToFind,
        ),

        _section(
          'Information to provide',
          role.informationToProvide,
        ),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Discussion question',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(role.discussionQuestion),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(String title, List<String> items) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
