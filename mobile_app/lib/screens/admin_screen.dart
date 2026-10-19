import 'dart:math';

import 'package:flutter/material.dart';

import '../models/experiment_config.dart';
import 'experiment_pairing_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final nameController = TextEditingController(
    text: 'Speech Quality Experiment',
  );

  final List<TextEditingController> lossControllers = [
    TextEditingController(text: '0'),
    TextEditingController(text: '20'),
  ];

  final List<TextEditingController> delayControllers = [
    TextEditingController(text: '0'),
    TextEditingController(text: '100'),
  ];

  bool includeNoEcho = true;
  bool includeEcho = true;

  @override
  void dispose() {
    nameController.dispose();
    for (final controller in lossControllers) {
      controller.dispose();
    }
    for (final controller in delayControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void addField(List<TextEditingController> controllers) {
    setState(() => controllers.add(TextEditingController()));
  }

  void removeField(List<TextEditingController> controllers, int index) {
    if (controllers.length <= 1) return;
    setState(() => controllers.removeAt(index).dispose());
  }

  List<double>? readNumbers(
    List<TextEditingController> controllers,
    double min,
    double max,
  ) {
    final values = <double>[];
    for (final controller in controllers) {
      final value = double.tryParse(
        controller.text.trim().replaceAll(',', '.'),
      );
      if (value == null || value < min || value > max) return null;
      values.add(value);
    }
    if (values.toSet().length != values.length) return null;
    return values;
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void generateExperiment() {
    final losses = readNumbers(lossControllers, 0, 100);
    final delays = readNumbers(delayControllers, 0, 60000);

    if (losses == null) {
      showError('Enter unique packet-loss values between 0 and 100%.');
      return;
    }
    if (delays == null) {
      showError('Enter unique delays between 0 and 60000 ms.');
      return;
    }

    final echoOptions = <bool>[
      if (includeNoEcho) false,
      if (includeEcho) true,
    ];
    if (echoOptions.isEmpty) {
      showError('Select at least one echo condition.');
      return;
    }
    if (nameController.text.trim().isEmpty) {
      showError('Enter an experiment name.');
      return;
    }

    final total = losses.length * delays.length * echoOptions.length;
    if (total > 500) {
      showError('Please limit the experiment to 500 tests.');
      return;
    }

    final random = Random();
    final conditions = <DegradationCondition>[];

    for (final loss in losses) {
      for (final delay in delays) {
        for (final echo in echoOptions) {
          conditions.add(
            DegradationCondition(
              packetLossPercent: loss,
              delayMs: delay.round(),
              echoEnabled: echo,
            ),
          );
        }
      }
    }
    conditions.shuffle(random);

    final scenarioPool = <int>[];
    final tests = <ExperimentTest>[];
    for (var i = 0; i < conditions.length; i++) {
      if (scenarioPool.isEmpty) {
        scenarioPool.addAll(List.generate(18, (index) => index + 1));
        scenarioPool.shuffle(random);
      }
      tests.add(
        ExperimentTest(
          testNumber: i + 1,
          scenarioId: scenarioPool.removeLast(),
          condition: conditions[i],
        ),
      );
    }

    final experiment = ExperimentConfig(
      id: 'EXP${DateTime.now().millisecondsSinceEpoch}',
      name: nameController.text.trim(),
      tests: tests,
    );

    // Navigate immediately: no generated list appears below the form.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ExperimentReviewScreen(experiment: experiment),
      ),
    );
  }

  Widget numberFields({
    required String title,
    required List<TextEditingController> controllers,
    required String suffix,
    required IconData icon,
  }) {
    return _SectionCard(
      title: title,
      icon: icon,
      child: Column(
        children: [
          for (var i = 0; i < controllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controllers[i],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Value ${i + 1}',
                        suffixText: suffix,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Remove value',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: controllers.length > 1
                        ? () => removeField(controllers, i)
                        : null,
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => addField(controllers),
              icon: const Icon(Icons.add),
              label: const Text('Add value'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final echoCount = (includeNoEcho ? 1 : 0) + (includeEcho ? 1 : 0);
    final testCount =
        lossControllers.length * delayControllers.length * echoCount;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Experiment')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.science_outlined,
                          color: theme.colorScheme.onPrimaryContainer,
                          size: 30,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Design your experiment',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Choose the degradation conditions. You can review '
                          'the randomized SCTs before hosting.',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionCard(
                    title: 'Experiment details',
                    icon: Icons.edit_note,
                    child: TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Experiment name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  numberFields(
                    title: 'Packet loss',
                    controllers: lossControllers,
                    suffix: '%',
                    icon: Icons.wifi_off_outlined,
                  ),
                  const SizedBox(height: 14),
                  numberFields(
                    title: 'Additional delay',
                    controllers: delayControllers,
                    suffix: 'ms',
                    icon: Icons.timer_outlined,
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Echo',
                    icon: Icons.graphic_eq,
                    child: Column(
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('No echo'),
                          value: includeNoEcho,
                          onChanged: (value) => setState(
                            () => includeNoEcho = value ?? false,
                          ),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Echo enabled'),
                          value: includeEcho,
                          onChanged: (value) => setState(
                            () => includeEcho = value ?? false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          const Icon(Icons.format_list_numbered, size: 30),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total test conditions'),
                                Text(
                                  '$testCount SCTs',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (testCount > 18)
                                  const Text('Some scenarios will repeat.'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            _BottomAction(
              child: FilledButton.icon(
                onPressed: generateExperiment,
                icon: const Icon(Icons.auto_awesome),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Text('Generate & Review'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExperimentReviewScreen extends StatelessWidget {
  final ExperimentConfig experiment;

  const _ExperimentReviewScreen({required this.experiment});

  void confirmAndHost(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExperimentPairingScreen(experiment: experiment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tests = experiment.tests;

    return Scaffold(
      appBar: AppBar(title: const Text('Review Experiment')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.fact_check_outlined,
                          size: 32,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ready to host?',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Review the generated SCT order below. Confirm '
                          'when you are ready to open the pairing room.',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            experiment.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            experiment.id,
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(Icons.checklist, size: 20),
                              const SizedBox(width: 8),
                              Text('${tests.length} randomized SCTs'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Generated test sequence',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Conditions are randomized. Each scenario is used '
                    'once per pool of 18 before being reused.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  for (final test in tests)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              child: Text('${test.testNumber}'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Scenario ${test.scenarioId}',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _ConditionChip(
                                        icon: Icons.wifi_off_outlined,
                                        label:
                                            '${test.condition.packetLossPercent}% loss',
                                      ),
                                      _ConditionChip(
                                        icon: Icons.timer_outlined,
                                        label: '${test.condition.delayMs} ms',
                                      ),
                                      _ConditionChip(
                                        icon: Icons.graphic_eq,
                                        label: test.condition.echoEnabled
                                            ? 'Echo on'
                                            : 'Echo off',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            _BottomAction(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 15),
                        child: Text('Back to Edit'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => confirmAndHost(context),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 15),
                        child: Text('Confirm & Host'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ConditionChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final Widget child;

  const _BottomAction({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: child,
    );
  }
}
