
import 'package:flutter/material.dart';

import '../widgets/rating_scale.dart';

class EvaluationResult {
  final int overallQuality;
  final double noise;
  final double continuity;
  final double coloration;
  final double loudness;
  final double ownVoiceInfluence;
  final double ownVoiceImpairment;
  final double interaction;

  const EvaluationResult({
    required this.overallQuality,
    required this.noise,
    required this.continuity,
    required this.coloration,
    required this.loudness,
    required this.ownVoiceInfluence,
    required this.ownVoiceImpairment,
    required this.interaction,
  });

  Map<String, dynamic> toMap() => {
        'overallQuality': overallQuality,
        'noise': noise,
        'continuity': continuity,
        'coloration': coloration,
        'loudness': loudness,
        'ownVoiceInfluence': ownVoiceInfluence,
        'ownVoiceImpairment': ownVoiceImpairment,
        'interaction': interaction,
      };
}

class EvaluationScreen extends StatefulWidget {
  final int? testNumber;
  final int? totalTests;
  final ValueChanged<EvaluationResult>? onSubmitted;

  const EvaluationScreen({
    super.key,
    this.testNumber,
    this.totalTests,
    this.onSubmitted,
  });

  @override
  State<EvaluationScreen> createState() =>
      _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  int? overallQuality;

  double? noise;
  double? continuity;
  double? coloration;
  double? loudness;
  double? ownVoiceInfluence;
  double? ownVoiceImpairment;
  double? interaction;

  bool submitted = false;

  bool get allRated =>
      overallQuality != null &&
      noise != null &&
      continuity != null &&
      coloration != null &&
      loudness != null &&
      ownVoiceInfluence != null &&
      ownVoiceImpairment != null &&
      interaction != null;

  void submitEvaluation() {
    if (submitted) return;

    if (!allRated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please answer all evaluation questions.',
          ),
        ),
      );
      return;
    }

    final result = EvaluationResult(
      overallQuality: overallQuality!,
      noise: noise!,
      continuity: continuity!,
      coloration: coloration!,
      loudness: loudness!,
      ownVoiceInfluence: ownVoiceInfluence!,
      ownVoiceImpairment: ownVoiceImpairment!,
      interaction: interaction!,
    );

    setState(() => submitted = true);

    if (widget.onSubmitted != null) {
      widget.onSubmitted!(result);
    } else {
      debugPrint('Evaluation preview: ${result.toMap()}');
    }
  }

  Widget overallOption(int value, String label) {
    return RadioListTile<int>(
      title: Text(label),
      value: value,
      groupValue: overallQuality,
      contentPadding: EdgeInsets.zero,
      onChanged: submitted
          ? null
          : (selected) {
              setState(() => overallQuality = selected);
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (submitted) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'Evaluation submitted',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Please wait for the next instruction.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          widget.testNumber == null
              ? 'Rate the Conversation'
              : 'Evaluation — SCT ${widget.testNumber}'
                  ' / ${widget.totalTests ?? "?"}',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Please rate the conversation based on '
          'your personal impression.',
        ),

        const SizedBox(height: 32),

        const Text(
          'Overall Quality',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'How would you rate the overall quality '
          'of the conversation?',
        ),

        const SizedBox(height: 16),

        overallOption(5, 'Excellent'),
        overallOption(4, 'Good'),
        overallOption(3, 'Fair'),
        overallOption(2, 'Poor'),
        overallOption(1, 'Bad'),

        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 24),

        const Text(
          'Conversation Characteristics',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Please rate each characteristic independently.',
        ),

        const SizedBox(height: 24),

        RatingScale(
          title: '1. Noisiness',
          description:
              'How noisy was the speech you heard?',
          leftLabel: 'not noisy',
          rightLabel: 'noisy',
          value: noise,
          onChanged: (v) => setState(() => noise = v),
        ),

        RatingScale(
          title: '2. Discontinuity',
          description:
              'How continuous or interrupted was the speech?',
          leftLabel: 'continuous',
          rightLabel: 'discontinuous',
          value: continuity,
          onChanged: (v) =>
              setState(() => continuity = v),
        ),

        RatingScale(
          title: '3. Coloration',
          description:
              'Did the speech sound direct and natural, '
              'or thin and nasal?',
          leftLabel: 'uncolored',
          rightLabel: 'colored',
          value: coloration,
          onChanged: (v) =>
              setState(() => coloration = v),
        ),

        RatingScale(
          title: '4. Loudness',
          description:
              'How appropriate was the perceived loudness?',
          leftLabel: 'optimal loudness',
          rightLabel: 'sub-optimal loudness',
          value: loudness,
          onChanged: (v) =>
              setState(() => loudness = v),
        ),

        RatingScale(
          title: "5. Impact of one's own voice",
          description:
              'Did hearing your own voice negatively affect '
              'your ability to speak?',
          leftLabel: 'no impact on speaking',
          rightLabel: 'high impact on speaking',
          value: ownVoiceInfluence,
          onChanged: (v) =>
              setState(() => ownVoiceInfluence = v),
        ),

        RatingScale(
          title: "6. Degradation of one's own voice",
          description:
              'How degraded did your own voice sound?',
          leftLabel: 'own voice not degraded',
          rightLabel: 'own voice degraded',
          value: ownVoiceImpairment,
          onChanged: (v) =>
              setState(() => ownVoiceImpairment = v),
        ),

        RatingScale(
          title: '7. Interaction',
          description:
              'How easy or difficult was it to interact '
              'with your conversation partner?',
          leftLabel: 'easy to interact',
          rightLabel: 'hard to interact',
          value: interaction,
          onChanged: (v) =>
              setState(() => interaction = v),
        ),

        const SizedBox(height: 16),

        ElevatedButton.icon(
          onPressed: submitEvaluation,
          icon: const Icon(Icons.check_circle_outline),
          label: const Padding(
            padding: EdgeInsets.all(14),
            child: Text('Submit Evaluation'),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}
