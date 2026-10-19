import 'package:flutter/material.dart';

import '../data/conversation_scenarios.dart';
import 'package:flutter/material.dart';

import '../data/conversation_scenarios.dart';
import '../models/conversation_scenario.dart';
import 'evaluation_screen.dart';
import '../models/conversation_scenario.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() =>
      _ConversationScreenState();
}

class _ConversationScreenState
    extends State<ConversationScreen> {

  // ------------------------------------------------------------
  // TEMPORARY TEST SETTINGS
  // Later these will come from the experiment/session server.
  // ------------------------------------------------------------

  final int scenarioId = 6;

  // Change this to false to see the receiver's screen.
  final bool isCaller = true;

  @override
  Widget build(BuildContext context) {

    final ConversationScenario scenario =
        conversationScenarios.firstWhere(
      (scenario) => scenario.id == scenarioId,
    );

    final ConversationRole role =
        isCaller ? scenario.caller : scenario.receiver;

    return Scaffold(
      appBar: AppBar(
        title: Text('Scenario ${scenario.id}'),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ------------------------------------------------
              // SCENARIO TITLE
              // ------------------------------------------------

              Text(
                scenario.title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                role.roleName,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),

              const SizedBox(height: 32),

              // ------------------------------------------------
              // PARTICIPANT NAME
              // ------------------------------------------------

              _sectionTitle('Your name'),

              Text(
                role.participantName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 32),

              // ------------------------------------------------
              // TASK
              // ------------------------------------------------

              _sectionTitle('Your task'),

              _informationBox(
                child: Text(
                  role.task,
                  style: const TextStyle(
                    fontSize: 17,
                  ),
                ),
              ),

              // ------------------------------------------------
              // CONDITIONS
              // ------------------------------------------------

              if (role.conditions.isNotEmpty) ...[
                const SizedBox(height: 32),

                _sectionTitle('Conditions'),

                ...role.conditions.map(
                  (condition) => _bulletPoint(condition),
                ),
              ],

              // ------------------------------------------------
              // INFORMATION TO FIND
              // ------------------------------------------------

              if (role.informationToFind.isNotEmpty) ...[
                const SizedBox(height: 32),

                _sectionTitle('Information to find'),

                const Text(
                  'Ask your conversation partner for the '
                  'following information:',
                  style: TextStyle(fontSize: 15),
                ),

                const SizedBox(height: 16),

                ...role.informationToFind.map(
                  (information) =>
                      _answerField(information),
                ),
              ],

              // ------------------------------------------------
              // INFORMATION TO PROVIDE
              // ------------------------------------------------

              if (role.informationToProvide.isNotEmpty) ...[
                const SizedBox(height: 32),

                _sectionTitle(
                  isCaller
                      ? 'Information you can provide'
                      : 'Information available to you',
                ),

                _informationBox(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: role.informationToProvide
                        .map(
                          (information) =>
                              _bulletPoint(information),
                        )
                        .toList(),
                  ),
                ),
              ],

              // ------------------------------------------------
              // DISCUSSION QUESTION
              // ------------------------------------------------

              const SizedBox(height: 32),

              _sectionTitle('Discuss together'),

              _informationBox(
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.forum_outlined,
                      size: 28,
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        role.discussionQuestion,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ------------------------------------------------
              // END BUTTON
              // ------------------------------------------------

            SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const EvaluationScreen(),
        ),
      );
    },
    child: const Padding(
      padding: EdgeInsets.all(14),
      child: Text(
        'Finish Conversation',
      ),
    ),
  ),
),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _answerField(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _informationBox({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: child,
    );
  }
}