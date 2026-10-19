import 'package:flutter/material.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  int currentStep = 0;

  final List<TrainingStep> steps = const [
    TrainingStep(
      title: 'Overall Conversation Quality',
      icon: Icons.forum_outlined,
      description:
          'Think about the conversation as a whole. Consider how easy '
          'and comfortable it was to communicate with the other person.',
      question:
          'How would you rate the overall quality of the conversation?',
      lowLabel: 'Bad',
      highLabel: 'Excellent',
    ),
    TrainingStep(
      title: 'Listening Effort',
      icon: Icons.hearing_outlined,
      description:
          'Consider how much effort was required to understand what '
          'the other participant was saying.',
      question:
          'How much effort did you need to understand your partner?',
      lowLabel: 'Very high effort',
      highLabel: 'No effort',
    ),
    TrainingStep(
      title: 'Speech Continuity',
      icon: Icons.graphic_eq,
      description:
          'Think about whether the speech sounded continuous or whether '
          'you noticed interruptions, gaps, or missing parts.',
      question:
          'How would you rate the continuity of the speech?',
      lowLabel: 'Very interrupted',
      highLabel: 'Completely continuous',
    ),
    TrainingStep(
      title: 'Speech Distortion',
      icon: Icons.record_voice_over_outlined,
      description:
          'Think about whether the voice sounded natural or whether '
          'you noticed distortion or other changes in the speech.',
      question:
          'How would you rate the amount of speech distortion?',
      lowLabel: 'Very distorted',
      highLabel: 'Not distorted',
    ),
    TrainingStep(
      title: 'Conversational Difficulty',
      icon: Icons.people_outline,
      description:
          'Think about whether the connection made it difficult '
          'to communicate naturally, take turns, or complete the task.',
      question:
          'How difficult was it to have the conversation?',
      lowLabel: 'Very difficult',
      highLabel: 'Not difficult',
    ),
  ];

  void nextStep() {
    if (currentStep < steps.length - 1) {
      setState(() {
        currentStep++;
      });
    } else {
      debugPrint('Training completed');
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = steps[currentStep];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training'),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------------------------------------
              // Progress
              // ------------------------------------------------

              Text(
                'Training ${currentStep + 1} of ${steps.length}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 10),

              LinearProgressIndicator(
                value: (currentStep + 1) / steps.length,
                minHeight: 6,
                borderRadius: BorderRadius.circular(10),
              ),

              const SizedBox(height: 32),

              // ------------------------------------------------
              // Icon
              // ------------------------------------------------

              Center(
                child: CircleAvatar(
                  radius: 38,
                  child: Icon(
                    step.icon,
                    size: 38,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ------------------------------------------------
              // Title
              // ------------------------------------------------

              Center(
                child: Text(
                  step.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ------------------------------------------------
              // Explanation
              // ------------------------------------------------

              Text(
                step.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // ------------------------------------------------
              // Example rating
              // ------------------------------------------------

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Example rating question',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      step.question,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Numbers

                    const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text('1'),
                        Text('2'),
                        Text('3'),
                        Text('4'),
                        Text('5'),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Rating circles

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        5,
                        (index) {
                          return const Icon(
                            Icons.radio_button_unchecked,
                            size: 28,
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Scale labels

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            step.lowLabel,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),

                        Expanded(
                          child: Text(
                            step.highLabel,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ------------------------------------------------
              // Navigation buttons
              // ------------------------------------------------

              Row(
                children: [
                  if (currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: previousStep,
                        child: const Padding(
                          padding: EdgeInsets.all(14),
                          child: Text('Back'),
                        ),
                      ),
                    ),

                  if (currentStep > 0)
                    const SizedBox(width: 12),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: nextStep,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          currentStep == steps.length - 1
                              ? 'Finish Training'
                              : 'Next',
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// Training step model
// ================================================================

class TrainingStep {
  final String title;
  final IconData icon;
  final String description;
  final String question;
  final String lowLabel;
  final String highLabel;

  const TrainingStep({
    required this.title,
    required this.icon,
    required this.description,
    required this.question,
    required this.lowLabel,
    required this.highLabel,
  });
}