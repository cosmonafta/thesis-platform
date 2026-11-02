import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/experiment_config.dart';
import '../screens/evaluation_screen.dart';

/// Writes one row per locally completed SCT evaluation.
class CsvReportService {
  static const columns = <String>[
    'experiment_id',
    'experiment_name',
    'participant_role',
    'age',
    'gender',
    'native_language',
    'german_proficiency',
    'hearing_difficulties',
    'previous_test_experience',
    'headphone_type',
    'sct_number',
    'scenario_id',
    'recording_filename',
    'packet_loss_percent',
    'delay_ms',
    'echo_enabled',
    'echo_delay_ms',
    'echo_gain',
    'overall_quality',
    'noise',
    'continuity',
    'coloration',
    'loudness',
    'own_voice_influence',
    'own_voice_impairment',
    'interaction',
  ];

  Future<String> generateReport({
    required ExperimentConfig experiment,
    required Map<int, EvaluationResult> results,
    required String participantRole,
    Map<String, String> participantInfo = const {},
  }) async {
    if (results.isEmpty) {
      throw StateError('No evaluation results available.');
    }

    final rows = <List<Object?>>[columns];
    final indexes = results.keys.toList()..sort();

    for (final index in indexes) {
      if (index < 0 || index >= experiment.tests.length) continue;
      final test = experiment.tests[index];
      final condition = test.condition;
      final rating = results[index]!;
      final recordingFilename =
          '${experiment.id}_SCT_${(index + 1).toString().padLeft(2, '0')}_$participantRole.mp3';

      rows.add(<Object?>[
        experiment.id,
        experiment.name,
        participantRole,
        participantInfo['age'] ?? '',
        participantInfo['gender'] ?? '',
        participantInfo['native_language'] ?? '',
        participantInfo['german_proficiency'] ?? '',
        participantInfo['hearing_difficulties'] ?? '',
        participantInfo['previous_test_experience'] ?? '',
        participantInfo['headphone_type'] ?? '',
        index + 1,
        test.scenarioId,
        recordingFilename,
        condition.packetLossPercent,
        condition.delayMs,
        condition.echoEnabled,
        condition.echoEnabled ? condition.echoDelayMs : '',
        condition.echoEnabled ? condition.echoGain : '',
        rating.overallQuality.round(),
        rating.noise.round(),
        rating.continuity.round(),
        rating.coloration.round(),
        rating.loudness.round(),
        rating.ownVoiceInfluence.round(),
        rating.ownVoiceImpairment.round(),
        rating.interaction.round(),
      ]);
    }

    final csv = rows.map((row) => row.map(_escape).join(',')).join('\r\n');
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory('${root.path}${Platform.pathSeparator}reports');
    await folder.create(recursive: true);
    final safeId = experiment.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final path = '${folder.path}${Platform.pathSeparator}${safeId}_Results_$participantRole.csv';
    final temp = File('$path.tmp');
    await temp.writeAsString('\uFEFF$csv\r\n', flush: true);
    // Replace only after the new complete CSV has been flushed.
    // On Android/Linux rename replaces the previous checkpoint atomically.
    await temp.rename(path);
    return path;
  }

  String _escape(Object? value) {
    final text = value?.toString() ?? '';
    // Prevent spreadsheet programs from interpreting untrusted text as formulas.
    final safe = value is num || value is bool
        ? text
        : (RegExp(r'^[=+@\-\t\r]').hasMatch(text) ? "'$text" : text);
    if (safe.contains(',') || safe.contains('"') || safe.contains('\n') || safe.contains('\r')) {
      return '"${safe.replaceAll('"', '""')}"';
    }
    return safe;
  }
}
