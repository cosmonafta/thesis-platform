
import 'package:flutter/material.dart';

import 'admin_screen.dart';
import 'experiment_pairing_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversational Quality Test'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 450,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.record_voice_over,
                    size: 72,
                    color: Colors.blue,
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Welcome',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'In this study, you will have a short '
                    'conversation with another participant '
                    'and afterwards evaluate the quality '
                    'of the conversation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),

                  const SizedBox(height: 40),

                  // ADMIN
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const AdminScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text(
                      'Create Experiment (Admin)',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // PARTICIPANT
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const ExperimentPairingScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.wifi),
                    label: const Text(
                      'Join Experiment (Participant)',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  const Divider(),

                  const SizedBox(height: 16),

                  const Text(
                    'Both devices must be connected '
                    'to the same Wi-Fi network.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
