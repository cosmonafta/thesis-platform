
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/experiment_config.dart';
import '../screens/evaluation_screen.dart';
import '../data/conversation_scenarios.dart';

class PdfReportService {
  Future<String> generateReport({
    required ExperimentConfig experiment,
    required Map<int, EvaluationResult> results,
    required String participantRole,
  }) async {
    if (results.isEmpty) {
      throw StateError('No evaluation results available.');
    }

    final document = pw.Document();
    final generatedAt = DateTime.now();

    final sortedIndexes = results.keys.toList()..sort();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Conversational Speech Quality Test',
              style: pw.TextStyle(
                fontSize: 17,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Participant $participantRole - Evaluation Report',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Divider(),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          _heading('Experiment Information'),
          _detail('Experiment name', experiment.name),
          _detail('Experiment ID', experiment.id),
          _detail('Participant', participantRole),
          _detail('Generated at', generatedAt.toIso8601String()),
          _detail('Total SCTs', '${experiment.tests.length}'),
          _detail('Evaluations recorded', '${results.length}'),
          pw.SizedBox(height: 20),
          _heading('Evaluation Results'),
          pw.Text(
            'P.804 continuous scales: 0 represents the left endpoint '
            'and 100 represents the right endpoint. '
            'Higher values indicate greater perceived impairment.',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 14),

          for (final index in sortedIndexes)
            if (index >= 0 && index < experiment.tests.length)
              _testSection(
                experiment: experiment,
                index: index,
                result: results[index]!,
                participantRole: participantRole,
              ),
        ],
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final reportDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}reports',
    );
    await reportDirectory.create(recursive: true);

    final safeId = experiment.id.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );

    final filename = '${safeId}_Results_$participantRole.pdf';
    final path =
        '${reportDirectory.path}${Platform.pathSeparator}$filename';

    final file = File(path);
    await file.writeAsBytes(await document.save(), flush: true);

    debugPrint('PDF report generated: $path');
    return path;
  }

  pw.Widget _testSection({
    required ExperimentConfig experiment,
    required int index,
    required EvaluationResult result,
    required String participantRole,
  }) {
    final test = experiment.tests[index];

    final scenario = conversationScenarios.where(
  (item) => item.id.toString() == test.scenarioId.toString(),
);

final String scenarioTitle = scenario.isEmpty
    ? test.scenarioId.toString()
    : scenario.first.title;

    final condition = test.condition;

    final recordingName =
        '${experiment.id}_SCT_${(index + 1).toString().padLeft(2, '0')}_$participantRole.mp3';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 12),
        _heading('SCT ${index + 1} - $scenarioTitle'),
        _detail('Scenario ID', test.scenarioId.toString()),
        _detail('Recording', recordingName),
        pw.SizedBox(height: 8),

        pw.Text(
          'Applied Degradation',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        _detail(
          'Packet loss',
          '${condition.packetLossPercent}%',
        ),
        _detail('Delay', '${condition.delayMs} ms'),
        _detail(
          'Echo enabled',
          condition.echoEnabled ? 'Yes' : 'No',
        ),
        if (condition.echoEnabled) ...[
          _detail('Echo delay', '${condition.echoDelayMs} ms'),
          _detail('Echo gain', '${condition.echoGain}'),
        ],

        pw.SizedBox(height: 10),
        pw.Text(
          'Participant Evaluation',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),

        pw.Table(
          border: pw.TableBorder.all(
            color: PdfColors.grey300,
            width: 0.5,
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            _tableRow('Overall Quality', '${result.overallQuality} / 5'),
            _tableRow('1. Noisiness', _score(result.noise)),
            _tableRow('2. Discontinuity', _score(result.continuity)),
            _tableRow('3. Coloration', _score(result.coloration)),
            _tableRow('4. Loudness', _score(result.loudness)),
            _tableRow(
              "5. Impact of one's own voice",
              _score(result.ownVoiceInfluence),
            ),
            _tableRow(
              "6. Degradation of one's own voice",
              _score(result.ownVoiceImpairment),
            ),
            _tableRow('7. Interaction', _score(result.interaction)),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Divider(color: PdfColors.grey400),
      ],
    );
  }

  String _score(double value) => '${value.toStringAsFixed(1)} / 100';

  pw.Widget _heading(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );

  pw.Widget _detail(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 120,
              child: pw.Text(
                '$label:',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ],
        ),
      );

  pw.TableRow _tableRow(String label, String value) => pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      );
}
