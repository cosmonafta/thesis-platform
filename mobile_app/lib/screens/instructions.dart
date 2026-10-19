import 'package:flutter/material.dart';
import 'package:mobile_app/screens/lobby_screen.dart';

class InstructionsScreen extends StatelessWidget {
  const InstructionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instructions'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How the Test Works',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Please read the following instructions carefully '
              'before starting the test.',
              style: TextStyle(
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 32),

            _instructionCard(
              number: '1',
              title: 'Get ready',
              description:
                  'Make sure you are in a quiet environment and '
                  'can comfortably hear and speak using your device.',
              icon: Icons.headphones,
            ),

            const SizedBox(height: 16),

            _instructionCard(
              number: '2',
              title: 'Connect with another participant',
              description:
                  'You will be connected with another participant '
                  'for a short conversation.',
              icon: Icons.people,
            ),

            const SizedBox(height: 16),

            _instructionCard(
              number: '3',
              title: 'Complete the conversation task',
              description:
                  'You will receive a short scenario with information '
                  'that you need to exchange with your conversation '
                  'partner.',
              icon: Icons.chat_bubble_outline,
            ),

            const SizedBox(height: 16),

            _instructionCard(
              number: '4',
              title: 'Evaluate the conversation',
              description:
                  'After the conversation, you will answer a few '
                  'questions about the quality of the communication.',
              icon: Icons.star_outline,
            ),

            const SizedBox(height: 32),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 8),
                      Text(
                        'Important',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 12),

                  Text(
                    'Please communicate naturally. Do not focus '
                    'only on individual sounds or words. Your task '
                    'is to have a normal conversation and complete '
                    'the given scenario with your partner.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            const Text(
              'During the test',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            const _CheckItem(
              text: 'Speak naturally at your normal volume.',
            ),

            const _CheckItem(
              text: 'Pay attention to your conversation partner.',
            ),

            const _CheckItem(
              text: 'Try to complete the given task together.',
            ),

            const _CheckItem(
              text:
                  'Base your ratings on the conversation you just experienced.',
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
               onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) =>
          const LobbyScreen(),
    ),
  );
},
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'I understand',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _instructionCard({
    required String number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            child: Icon(icon),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number. $title',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;

  const _CheckItem({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 22,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}