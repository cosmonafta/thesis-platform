import 'dart:async';

import 'dart:math';

import 'package:flutter/material.dart';

import '../models/discovered_experiment.dart';

import '../models/experiment_config.dart';

import '../services/experiment_network_service.dart';

import '../services/audio/experiment_audio_service.dart';

import 'evaluation_screen.dart';

import '../data/conversation_scenarios.dart';

import '../models/conversation_scenario.dart';

import '../services/csv_report_service.dart';

import '../services/csv_storage_service.dart';

class ExperimentPairingScreen extends StatefulWidget {
  final ExperimentConfig? experiment;

  const ExperimentPairingScreen({super.key, this.experiment});

  @override
  State<ExperimentPairingScreen> createState() =>
      _ExperimentPairingScreenState();
}

class _ExperimentPairingScreenState extends State<ExperimentPairingScreen> {
  final network = ExperimentNetworkService();

  late final TextEditingController nameController;

  late final StreamSubscription<Map<String, dynamic>> messageSubscription;

  final CsvReportService csvReportService = CsvReportService();

  final CsvStorageService csvStorageService = CsvStorageService();

  bool savingCsv = false;

  bool savingCheckpoint = false;
  String? checkpointError;
  String? checkpointPath;
  Future<void> _checkpointQueue = Future<void>.value();

  String? savedCsvLocation;

  String? csvError;

  Timer? refreshTimer;

  Timer? syncTimer;

  final ExperimentAudioService audio = ExperimentAudioService();

  bool audioStarting = false;

  bool localAudioReady = false;

  bool remoteAudioReady = false;

  bool audioStartCommandSent = false;

  bool audioStartAcknowledged = false;

  String? audioError;

  List<DiscoveredExperiment> experiments = [];

  ExperimentConfig? activeExperiment;

  bool busy = false;

  bool hosting = false;

  bool searching = false;

  bool joined = false;

  bool localReady = false;

  bool remoteReady = false;

  bool configAcknowledged = false;

  bool startRequested = false;

  bool conversationStarted = false;

  int currentTestIndex = 0;

  String phase =
      'pairing'; // pairing, questionnaire, introduction, conversation, evaluation, complete

  bool localEvaluationDone = false;

  bool remoteEvaluationDone = false;

  bool stopAcknowledged = false;

  bool nextStartPending = false;

  int? pendingNextIndex;

  final Map<int, EvaluationResult> localResults = {};

  // Assigned by the host once per SCT and shared in start_test packets.
  final Map<int, bool> hostCallerByTest = {};

  final Random roleRandom = Random();

  final TextEditingController ageController = TextEditingController();

  final GlobalKey<FormState> questionnaireFormKey = GlobalKey<FormState>();

  String? selectedGender;

  String? selectedNativeLanguage;

  String? selectedGermanLevel;

  String? selectedHearing;

  String? selectedPreviousExperience;

  String? selectedHeadphoneType;

  bool localQuestionnaireDone = false;

  bool remoteQuestionnaireDone = false;

  // Both participants must acknowledge the introduction before SCT 1.
  bool localIntroductionReady = false;
  bool remoteIntroductionReady = false;

  final Map<String, String> participantInfo = {};

  String status = 'Choose an option to begin.';

  bool get isAdmin => widget.experiment != null;

  Future<void> startExperimentAudio() async {
    if (!mounted || audioStarting || audio.isRunning) {
      return;
    }

    final experiment = activeExperiment;

    final peerIp = network.connectedHost;

    if (experiment == null || experiment.tests.isEmpty || peerIp == null) {
      setState(() {
        audioError = 'Missing experiment or participant connection.';
      });

      return;
    }

    setState(() {
      audioStarting = true;

      audioError = null;
    });

    try {
      final currentTest = experiment.tests[currentTestIndex];

      await audio.startConversation(
        peerIp: peerIp,

        condition: currentTest.condition,

        experimentId: experiment.id,

        testNumber: currentTestIndex + 1,

        participantRole: hosting ? 'A' : 'B',
      );

      if (!mounted) return;

      setState(() {
        status = 'Audio conversation is active.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        audioError = 'Could not start audio: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          audioStarting = false;
        });
      }
    }
  }

  void resetAudioReadiness() {
    localAudioReady = false;

    remoteAudioReady = false;

    audioStartCommandSent = false;

    audioStartAcknowledged = false;
  }

  void requestAudioStart() {
    final experiment = activeExperiment;

    if (experiment == null ||
        phase != 'conversation' ||
        localAudioReady ||
        audioStarting ||
        audio.isRunning) {
      return;
    }

    setState(() {
      localAudioReady = true;

      audioError = null;

      status = 'Waiting for the other participant...';
    });

    network.send({
      'type': 'audio_ready',

      'experimentId': experiment.id,

      'testIndex': currentTestIndex,
    });

    tryCoordinateAudioStart();
  }

  void tryCoordinateAudioStart() {
    final experiment = activeExperiment;

    if (!hosting ||
        experiment == null ||
        phase != 'conversation' ||
        !localAudioReady ||
        !remoteAudioReady ||
        audioStartCommandSent) {
      return;
    }

    setState(() {
      audioStartCommandSent = true;

      status = 'Both participants ready. Starting audio...';
    });

    network.send({
      'type': 'audio_start',

      'experimentId': experiment.id,

      'testIndex': currentTestIndex,
    });
  }

  // Serialize all writes so a previous checkpoint cannot overwrite a newer one.
  Future<void> saveCheckpoint() {
    final experiment = activeExperiment;
    if (experiment == null || localResults.isEmpty) return Future.value();
    final snapshot = Map<int, EvaluationResult>.from(localResults);
    final info = Map<String, String>.from(participantInfo);
    final role = hosting ? 'A' : 'B';
    final next = _checkpointQueue.catchError((Object _) {}).then((_) async {
      if (mounted) setState(() => savingCheckpoint = true);
      try {
        final path = await csvReportService.generateReport(
          experiment: experiment,
          results: snapshot,
          participantRole: role,
          participantInfo: info,
        );
        if (mounted) {
          setState(() {
            checkpointPath = path;
            checkpointError = null;
          });
        }
      } catch (error) {
        if (mounted) setState(() => checkpointError = '$error');
        rethrow;
      } finally {
        if (mounted) setState(() => savingCheckpoint = false);
      }
    });
    _checkpointQueue = next;
    return next;
  }

  // Publishing is Android-local; it does not require the other phone or Wi-Fi.
  Future<void> saveCsvReport() async {
    final experiment = activeExperiment;
    if (savingCsv || experiment == null || localResults.isEmpty) return;
    setState(() {
      savingCsv = true;
      csvError = null;
    });
    try {
      await _checkpointQueue;
      // Always write the newest snapshot before exporting.
      await saveCheckpoint();
      final path = checkpointPath;
      if (path == null) throw StateError('No local CSV checkpoint available.');
      final published = await csvStorageService.publishCsv(path);
      if (!mounted) return;
      setState(() {
        savedCsvLocation = published;
        status = 'CSV results saved to the phone.';
      });
    } catch (error) {
      if (mounted) setState(() => csvError = 'Could not export CSV: $error');
    } finally {
      if (mounted) setState(() => savingCsv = false);
    }
  }

  void completeNormally() {
    if (phase == 'complete') return;
    setState(() {
      phase = 'complete';
      status = 'Experiment complete. Exporting results...';
    });
    saveCsvReport();
  }

  @override
  void initState() {
    super.initState();

    activeExperiment = widget.experiment;

    nameController = TextEditingController(
      text: widget.experiment?.name ?? 'Speech Quality Experiment',
    );

    messageSubscription = network.messages.listen(handleMessage);

    // Retransmit important state over UDP.
    syncTimer = Timer.periodic(
      const Duration(seconds: 1),

      (_) => synchronize(),
    );
  }

  void handleMessage(Map<String, dynamic> message) {
    if (!mounted) return;

    final type = message['type'];

    final experiment = activeExperiment;

    if (type == 'participant_joined' && hosting) {
      setState(() {
        joined = true;

        status = 'Participant connected!';
      });

      synchronize();

      return;
    }

    if (type == 'experiment_config' && !hosting) {
      try {
        final received = experimentFromMap(
          Map<String, dynamic>.from(message['experiment'] as Map),
        );

        if (experiment != null && experiment.id != received.id) return;

        setState(() {
          activeExperiment = received;

          joined = true;

          status = 'Experiment configuration received.';
        });

        network.send({'type': 'config_ack', 'experimentId': received.id});
      } catch (e) {
        setState(() => status = 'Invalid experiment configuration: $e');
      }

      return;
    }

    if (type == 'config_ack' && hosting) {
      if (message['experimentId'] == experiment?.id) {
        setState(() {
          configAcknowledged = true;

          status = 'Experiment synchronized.';
        });
      }

      return;
    }

    if (experiment == null || message['experimentId'] != experiment.id) {
      return;
    }

    // Both phones enter the pre-test questionnaire before SCT 1.
    if (type == 'questionnaire_start' && !hosting) {
      if (phase == 'pairing') {
        setState(() {
          phase = 'questionnaire';

          status = 'Please complete the participant questionnaire.';
        });
      }

      if (phase == 'questionnaire') {
        network.send({
          'type': 'questionnaire_ack',

          'experimentId': experiment.id,
        });
      }

      return;
    }

    if (type == 'questionnaire_done' && hosting) {
      if ((phase == 'questionnaire' || phase == 'introduction') &&
          !remoteQuestionnaireDone) {
        setState(() => remoteQuestionnaireDone = true);
      }

      synchronize();

      return;
    }

    if (type == 'introduction_ready') {
      // Only the host coordinates the transition to SCT 1.
      if (hosting && phase == 'introduction' && !remoteIntroductionReady) {
        setState(() => remoteIntroductionReady = true);
      }
      synchronize();
      return;
    }

    if (type == 'ready') {
      setState(() => remoteReady = message['ready'] == true);

      return;
    }

    if (type == 'audio_ready' &&
        phase == 'conversation' &&
        message['testIndex'] == currentTestIndex) {
      if (!remoteAudioReady) {
        setState(() => remoteAudioReady = true);
      }

      tryCoordinateAudioStart();

      return;
    }

    if (type == 'audio_start' &&
        !hosting &&
        phase == 'conversation' &&
        message['testIndex'] == currentTestIndex) {
      if (!localAudioReady) return;

      // Acknowledge duplicate commands too, in case an ACK was lost.
      network.send({
        'type': 'audio_start_ack',

        'experimentId': experiment.id,

        'testIndex': currentTestIndex,
      });

      if (!audio.isRunning && !audioStarting) {
        startExperimentAudio();
      }

      return;
    }

    if (type == 'audio_start_ack' &&
        hosting &&
        phase == 'conversation' &&
        message['testIndex'] == currentTestIndex) {
      if (!audioStartCommandSent) return;

      if (!audioStartAcknowledged) {
        setState(() => audioStartAcknowledged = true);
      }

      if (!audio.isRunning && !audioStarting) {
        startExperimentAudio();
      }

      return;
    }

    if (type == 'start_test' && !hosting) {
      final index = message['testIndex'];

      if (index is! int || index < 0 || index >= experiment.tests.length) {
        return;
      }

      // The host is the authority for the role assignment.
      final assignedHostCaller = message['hostIsCaller'];

      if (assignedHostCaller is! bool) return;

      // Duplicate command: acknowledge without resetting the active screen.
      if (phase == 'conversation' && currentTestIndex == index) {
        sendStartAck(index);

        return;
      }

      final initialStart =
          phase == 'introduction' && localIntroductionReady && index == 0;

      final nextStart =
          phase == 'evaluation' &&
          localEvaluationDone &&
          index == currentTestIndex + 1;

      if (!initialStart && !nextStart) return;

      setState(() {
        hostCallerByTest[index] = assignedHostCaller;

        currentTestIndex = index;

        resetAudioReadiness();

        phase = 'conversation';

        conversationStarted = true;

        localEvaluationDone = false;

        remoteEvaluationDone = false;

        audioError = null;

        status = 'SCT ${index + 1} started.';
      });

      sendStartAck(index);

      return;
    }

    if (type == 'start_ack' && hosting) {
      final index = message['testIndex'];

      if (index == 0 &&
          startRequested &&
          phase == 'introduction' &&
          localIntroductionReady &&
          remoteIntroductionReady) {
        setState(() {
          resetAudioReadiness();

          phase = 'conversation';

          conversationStarted = true;

          status = 'Both phones started SCT 1.';
        });
      } else if (nextStartPending && index == pendingNextIndex) {
        setState(() {
          currentTestIndex = index as int;

          resetAudioReadiness();

          phase = 'conversation';

          nextStartPending = false;

          pendingNextIndex = null;

          localEvaluationDone = false;

          remoteEvaluationDone = false;

          stopAcknowledged = false;

          audioError = null;

          status = 'Both phones started SCT ${index + 1}.';
        });
      }

      return;
    }

    if (type == 'finish_test' && !hosting) {
      final index = message['testIndex'];

      if (index != currentTestIndex) return;

      if (phase == 'conversation') {
        enterEvaluation();
      }

      if (phase == 'evaluation') {
        network.send({
          'type': 'finish_ack',

          'experimentId': experiment.id,

          'testIndex': index,
        });
      }

      return;
    }

    if (type == 'finish_ack' &&
        hosting &&
        message['testIndex'] == currentTestIndex) {
      setState(() => stopAcknowledged = true);

      return;
    }

    if (type == 'evaluation_done' && message['testIndex'] == currentTestIndex) {
      setState(() => remoteEvaluationDone = true);

      return;
    }

    if (type == 'experiment_complete' &&
        !hosting &&
        phase == 'evaluation' &&
        localEvaluationDone) {
      completeNormally();

      network.send({'type': 'complete_ack', 'experimentId': experiment.id});

      return;
    }

    if (type == 'complete_ack' && hosting) {
      setState(() => completionAcknowledged = true);
    }
  }

  bool completionAcknowledged = false;

  bool assignHostCaller(int index) =>
      hostCallerByTest.putIfAbsent(index, () => roleRandom.nextBool());

  void sendStartAck(int index) {
    network.send({
      'type': 'start_ack',

      'experimentId': activeExperiment!.id,

      'testIndex': index,
    });
  }

  void synchronize() {
    if (!mounted || !joined || !network.isConnected) return;

    final experiment = activeExperiment;

    if (hosting && experiment != null && !configAcknowledged) {
      network.send({
        'type': 'experiment_config',

        'experiment': experimentToMap(experiment),
      });
    }

    if (experiment == null) return;

    if (phase == 'conversation' && localAudioReady) {
      network.send({
        'type': 'audio_ready',

        'experimentId': experiment.id,

        'testIndex': currentTestIndex,
      });
    }

    if (hosting &&
        phase == 'conversation' &&
        audioStartCommandSent &&
        !audioStartAcknowledged) {
      network.send({
        'type': 'audio_start',

        'experimentId': experiment.id,

        'testIndex': currentTestIndex,
      });
    }

    if (localReady && phase == 'pairing') {
      network.send({
        'type': 'ready',

        'experimentId': experiment.id,

        'ready': true,
      });
    }

    if (hosting && startRequested && phase == 'questionnaire') {
      network.send({
        'type': 'questionnaire_start',

        'experimentId': experiment.id,
      });
    }

    if (!hosting &&
        (phase == 'questionnaire' || phase == 'introduction') &&
        localQuestionnaireDone) {
      network.send({
        'type': 'questionnaire_done',

        'experimentId': experiment.id,
      });
    }

    if (hosting &&
        startRequested &&
        phase == 'introduction' &&
        localIntroductionReady &&
        remoteIntroductionReady) {
      network.send({
        'type': 'start_test',

        'experimentId': experiment.id,

        'testIndex': 0,

        'hostIsCaller': assignHostCaller(0),
      });
    }

    if (!hosting && phase == 'introduction' && localIntroductionReady) {
      network.send({
        'type': 'introduction_ready',
        'experimentId': experiment.id,
      });
    }

    if (hosting && phase == 'evaluation' && !stopAcknowledged) {
      network.send({
        'type': 'finish_test',

        'experimentId': experiment.id,

        'testIndex': currentTestIndex,
      });
    }

    if (localEvaluationDone && phase == 'evaluation') {
      network.send({
        'type': 'evaluation_done',

        'experimentId': experiment.id,

        'testIndex': currentTestIndex,
      });
    }

    if (hosting && nextStartPending && pendingNextIndex != null) {
      network.send({
        'type': 'start_test',

        'experimentId': experiment.id,

        'testIndex': pendingNextIndex,

        'hostIsCaller': assignHostCaller(pendingNextIndex!),
      });
    }

    if (hosting && phase == 'complete' && !completionAcknowledged) {
      network.send({
        'type': 'experiment_complete',

        'experimentId': experiment.id,
      });
    }
  }

  Future<void> confirmFinishConversation() async {
    if (!mounted || phase != 'conversation' || !audio.isRunning) return;

    final confirmed = await showDialog<bool>(
      context: context,

      builder:
          (dialogContext) => AlertDialog(
            title: const Text('End conversation?'),

            content: const Text(
              'Are you sure you want to finish this conversation? '
              'Both participants will move to the evaluation.',
            ),

            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),

                child: const Text('Cancel'),
              ),

              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),

                child: const Text('End conversation'),
              ),
            ],
          ),
    );

    if (!mounted || confirmed != true || phase != 'conversation') return;

    await enterEvaluation();
  }

  void returnToHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> enterEvaluation() async {
    if (phase != 'conversation') return;

    setState(() {
      phase = 'evaluation';

      status = 'Conversation finished. Please evaluate it.';
    });

    try {
      await audio.stopConversation();
    } catch (e) {
      if (mounted) setState(() => status = 'Audio stop error: $e');
    }

    synchronize();
  }

  void submitEvaluation(EvaluationResult result) {
    if (phase != 'evaluation' || localEvaluationDone) return;

    setState(() {
      localResults[currentTestIndex] = result;

      localEvaluationDone = true;

      status = 'Evaluation submitted. Waiting for partner.';
    });

    saveCheckpoint().catchError((Object error) {
      debugPrint('Checkpoint save failed: $error');
    });
    synchronize();
  }

  void advanceExperiment() {
    final experiment = activeExperiment;

    if (!hosting ||
        phase != 'evaluation' ||
        experiment == null ||
        !localEvaluationDone ||
        !remoteEvaluationDone ||
        !stopAcknowledged ||
        nextStartPending)
      return;

    if (currentTestIndex + 1 == experiment.tests.length) {
      completeNormally();
    } else {
      setState(() {
        pendingNextIndex = currentTestIndex + 1;

        nextStartPending = true;

        status = 'Starting next SCT on both phones...';
      });
    }

    synchronize();
  }

  void setReady() {
    if (activeExperiment == null) return;

    setState(() {
      localReady = true;

      status = 'You are ready.';
    });

    synchronize();
  }

  void startExperiment() {
    final experiment = activeExperiment;

    if (!hosting ||
        !localReady ||
        !remoteReady ||
        !configAcknowledged ||
        experiment == null ||
        experiment.tests.isEmpty) {
      return;
    }

    setState(() {
      startRequested = true;

      assignHostCaller(0);

      phase = 'questionnaire';

      status = 'Please complete the participant questionnaire.';
    });

    synchronize();
  }

  void submitQuestionnaire() {
    if (phase != 'questionnaire' || localQuestionnaireDone) return;

    if (!(questionnaireFormKey.currentState?.validate() ?? false)) return;

    participantInfo
      ..clear()
      ..addAll({
        'age': ageController.text.trim(),

        'gender': selectedGender ?? '',

        'native_language': selectedNativeLanguage ?? '',

        'german_proficiency': selectedGermanLevel ?? '',

        'hearing_difficulties': selectedHearing ?? '',

        'previous_test_experience': selectedPreviousExperience ?? '',

        'headphone_type': selectedHeadphoneType ?? '',
      });

    setState(() {
      localQuestionnaireDone = true;

      phase = 'introduction';
      status = 'Read the instructions, then confirm when you are ready.';
    });

    synchronize();
  }

  void confirmIntroductionReady() {
    if (phase != 'introduction' || localIntroductionReady) return;
    setState(() {
      localIntroductionReady = true;
      status = 'Waiting for the other participant to finish reading...';
    });
    synchronize();
  }

  Widget buildIntroduction() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.menu_book_outlined, size: 56),
        const SizedBox(height: 12),
        const Text(
          'Welcome to the Experiment!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text('Thank you for participating!'),
        const SizedBox(height: 12),
        const Text(
          'In this experiment, you will have a conversation with '
          'another participant under different conditions and rate your experience.',
        ),
        const SizedBox(height: 22),
        const Text(
          'What to Expect',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text('1. Conversation: Take part in a short conversation.'),
        const SizedBox(height: 8),
        const Text(
          '2. Speaking & Listening: Complete a speaking and listening task.',
        ),
        const SizedBox(height: 8),
        const Text('3. Rating: Evaluate your experience after each phase.'),
        const SizedBox(height: 12),
        const Text('You will receive instructions before starting.'),
        const SizedBox(height: 22),
        const Text(
          'How to Rate',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text('You will use rating scales to describe your experience.'),
        const SizedBox(height: 10),
        const Text(
          '• Some scales label every rating option.\n'
          '• Others label only the two endpoints.',
        ),
        const SizedBox(height: 12),
        const Text('Choose the rating that best matches your experience.'),
        const SizedBox(height: 18),
        const Text(
          'Please read the instructions carefully. '
          'If you have any questions, ask the experiment supervisor.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 26),
        if (!localIntroductionReady)
          FilledButton.icon(
            onPressed: confirmIntroductionReady,
            icon: const Icon(Icons.check_circle_outline),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('I have read the instructions — I am ready'),
            ),
          )
        else ...[
          const Icon(Icons.check_circle, color: Colors.green, size: 40),
          const SizedBox(height: 12),
          Text(
            remoteIntroductionReady
                ? 'Both participants are ready. Starting the first scenario...'
                : 'You are ready. Waiting for the other participant...',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  Widget buildQuestionnaire() {
    if (localQuestionnaireDone) {
      return Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 60),

          const SizedBox(height: 16),

          const Text(
            'Questionnaire completed',

            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Text(
            remoteQuestionnaireDone
                ? 'Both questionnaires are complete. The test will begin shortly.'
                : 'Please wait for the other participant.',

            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          const CircularProgressIndicator(),
        ],
      );
    }

    Widget selection(
      String title,
      String? value,
      List<String> options,

      ValueChanged<String?> onChanged, {
      bool mustSelect = true,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),

        child: DropdownButtonFormField<String>(
          value: value,

          isExpanded: true,

          decoration: InputDecoration(
            labelText: title,

            border: const OutlineInputBorder(),
          ),

          items:
              options
                  .map(
                    (option) => DropdownMenuItem(
                      value: option,

                      child: Text(option, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),

          onChanged: onChanged,

          validator:
              mustSelect
                  ? (selected) =>
                      selected == null ? 'Please select an answer.' : null
                  : null,
        ),
      );
    }

    return Form(
      key: questionnaireFormKey,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          const Icon(Icons.assignment_ind_outlined, size: 55),

          const SizedBox(height: 12),

          const Text(
            'Pre-experiment questionnaire',

            textAlign: TextAlign.center,

            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          const Text(
            'Please answer the following questions. '
            'Your answers will be saved together with your ratings '
            'in the CSV file.',
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 22),

          TextFormField(
            controller: ageController,

            keyboardType: TextInputType.number,

            decoration: const InputDecoration(
              labelText: 'Age (in years)',

              border: OutlineInputBorder(),
            ),

            validator: (value) {
              final age = int.tryParse(value?.trim() ?? '');

              if (age == null || age < 1 || age > 120) {
                return 'Please enter a valid age.';
              }

              return null;
            },
          ),

          const SizedBox(height: 18),

          selection(
            'Gender',
            selectedGender,

            ['Female', 'Male', 'Non-binary / diverse', 'Prefer not to say'],

            (value) => setState(() => selectedGender = value),
          ),

          selection(
            'Native language',
            selectedNativeLanguage,

            ['German', 'English', 'Other', 'Prefer not to say'],

            (value) => setState(() => selectedNativeLanguage = value),
          ),

          selection(
            'English language proficiency',
            selectedGermanLevel,

            [
              'Native language',
              'C2',
              'C1',
              'B2',
              'B1',
              'A2',
              'A1',
              'Prefer not to say',
            ],

            (value) => setState(() => selectedGermanLevel = value),
          ),

          selection(
            'Do you have any hearing difficulties?',
            selectedHearing,

            ['No', 'Yes', 'Prefer not to say'],

            (value) => setState(() => selectedHearing = value),
          ),

          selection(
            'Have you participated in a speech quality test before?',

            selectedPreviousExperience,
            ['No', 'Yes'],

            (value) => setState(() => selectedPreviousExperience = value),
          ),

          selection(
            'What type of headphones are you using?',

            selectedHeadphoneType,

            [
              'Wireless headset',
              'Wireless earbuds',
              'Wired headset',
              'Wired earbuds',
              'No headphones (phone speaker)',
            ],

            (value) => setState(() => selectedHeadphoneType = value),
          ),

          const SizedBox(height: 10),

          FilledButton.icon(
            onPressed: submitQuestionnaire,

            icon: const Icon(Icons.check),

            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),

              child: Text('Submit questionnaire'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> host() async {
    if (busy || hosting || searching) return;

    setState(() {
      busy = true;

      status = 'Creating experiment...';
    });

    try {
      await network.startHosting(
        nameController.text.trim().isEmpty
            ? 'Speech Quality Experiment'
            : nameController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        hosting = true;

        status = 'Waiting for participant...';
      });

      refreshTimer?.cancel();

      refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || joined) return;

        if (network.isConnected) {
          setState(() {
            joined = true;

            status = 'Participant connected!';
          });

          synchronize();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => status = 'Hosting failed: $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> search() async {
    if (busy || hosting || searching) return;

    setState(() {
      busy = true;

      status = 'Searching for experiments...';
    });

    try {
      await network.startDiscovery();

      if (!mounted) return;

      setState(() => searching = true);

      await refreshExperiments();

      refreshTimer?.cancel();

      refreshTimer = Timer.periodic(
        const Duration(seconds: 2),

        (_) => refreshExperiments(),
      );
    } catch (e) {
      if (mounted) {
        setState(() => status = 'Discovery failed: $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refreshExperiments() async {
    try {
      final found = await network.getExperiments();

      if (!mounted || !searching || joined) return;

      setState(() => experiments = found);
    } catch (e) {
      if (mounted) {
        setState(() => status = 'Refresh failed: $e');
      }
    }
  }

  Future<void> join(DiscoveredExperiment experiment) async {
    if (busy) return;

    refreshTimer?.cancel();

    setState(() {
      busy = true;

      status = 'Connecting to ${experiment.name}...';
    });

    try {
      final accepted = await network.join(experiment);

      if (!mounted) return;

      if (accepted) {
        setState(() {
          joined = true;

          searching = false;

          status = 'Connected. Receiving experiment...';
        });

        await network.stopDiscovery();

        // Request the configuration immediately.
        network.send({'type': 'request_config'});
      } else {
        setState(() {
          status = 'Host did not respond. Try again.';
        });

        resumeSearch();
      }
    } catch (e) {
      if (mounted) {
        setState(() => status = 'Join failed: $e');

        resumeSearch();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void resumeSearch() {
    if (!mounted || !searching) return;

    refreshTimer?.cancel();

    refreshTimer = Timer.periodic(
      const Duration(seconds: 2),

      (_) => refreshExperiments(),
    );
  }

  @override
  void dispose() {
    refreshTimer?.cancel();

    syncTimer?.cancel();

    messageSubscription.cancel();

    nameController.dispose();

    ageController.dispose();

    network.dispose();

    audio.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final experiment = activeExperiment;

    return PopScope(
      canPop: phase == 'complete',

      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,

          title: Text(
            phase == 'evaluation'
                ? 'SCT Evaluation'
                : phase == 'complete'
                ? 'Experiment Complete'
                : phase == 'questionnaire'
                ? 'Participant questionnaire'
                : phase == 'introduction'
                ? 'Experiment instructions'
                : phase == 'conversation'
                ? 'SCT Conversation'
                : joined
                ? 'Waiting Room'
                : 'Experiment Pairing',
          ),
        ),

        body: SafeArea(
          child:
              phase == 'evaluation' && experiment != null
                  ? buildEvaluation(experiment)
                  : ListView(
                    padding: const EdgeInsets.all(20),

                    children: [
                      if (phase == 'complete')
                        buildComplete()
                      else if (phase == 'questionnaire')
                        buildQuestionnaire()
                      else if (phase == 'introduction')
                        buildIntroduction()
                      else if (phase == 'conversation' && experiment != null)
                        buildConversation(experiment)
                      else if (joined)
                        buildWaitingRoom()
                      else
                        buildPairing(),

                      const SizedBox(height: 20),

                      if (busy)
                        const Center(child: CircularProgressIndicator()),

                      const SizedBox(height: 12),

                      Text(
                        status,

                        textAlign: TextAlign.center,

                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _statusTile({
    required IconData icon,

    required String title,

    required String subtitle,

    required bool completed,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: scheme.outlineVariant),
      ),

      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
                completed
                    ? Colors.green.withValues(alpha: 0.12)
                    : scheme.primary.withValues(alpha: 0.10),

            child: Icon(
              completed ? Icons.check_circle : icon,

              color: completed ? Colors.green : scheme.primary,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 3),

                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPairing() {
    final scheme = Theme.of(context).colorScheme;

    final experiment = activeExperiment;

    final isHostScreen = isAdmin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        Container(
          padding: const EdgeInsets.all(22),

          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.65),

            borderRadius: BorderRadius.circular(24),
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Icon(
                isHostScreen ? Icons.hub_outlined : Icons.wifi_find,

                size: 42,

                color: scheme.onPrimaryContainer,
              ),

              const SizedBox(height: 14),

              Text(
                isHostScreen ? 'Host your experiment' : 'Join an experiment',

                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,

                  color: scheme.onPrimaryContainer,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                isHostScreen
                    ? 'Invite the second participant to connect before beginning the speech quality tests.'
                    : 'Find the experiment hosted by your partner and connect to begin the speech quality tests.',

                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        if (isHostScreen) ...[
          Card(
            elevation: 0,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),

              side: BorderSide(color: scheme.outlineVariant),
            ),

            child: Padding(
              padding: const EdgeInsets.all(20),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    'EXPERIMENT DETAILS',

                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.primary,

                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    experiment?.name ?? 'Speech Quality Experiment',

                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Icon(
                        Icons.format_list_numbered,

                        color: scheme.primary,

                        size: 20,
                      ),

                      const SizedBox(width: 8),

                      Text(
                        '${experiment?.tests.length ?? 0} conversation tests',
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,

                    child: FilledButton.icon(
                      onPressed: busy || hosting ? null : host,

                      icon: Icon(
                        hosting ? Icons.check_circle : Icons.wifi_tethering,
                      ),

                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),

                        child: Text(
                          hosting
                              ? 'Hosting active'
                              : 'Create & Host Experiment',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (hosting) ...[
            const SizedBox(height: 20),

            _statusTile(
              icon: Icons.hourglass_top,

              title: 'Waiting for participant',

              subtitle:
                  'Ask your partner to open Find Experiments on the same Wi-Fi network.',

              completed: false,
            ),

            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),

                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ] else ...[
          _statusTile(
            icon: Icons.wifi,

            title: 'Same Wi-Fi network',

            subtitle: 'Both phones need to be connected to the same Wi-Fi.',

            completed: false,
          ),

          if (!searching) ...[
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,

              child: FilledButton.icon(
                onPressed: busy ? null : search,

                icon: const Icon(Icons.search),

                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),

                  child: Text('Find Experiments'),
                ),
              ),
            ),
          ],

          if (searching) ...[
            const SizedBox(height: 18),

            Text(
              'Available experiments',

              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            if (experiments.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),

                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),

                  border: Border.all(color: scheme.outlineVariant),
                ),

                child: const Column(
                  children: [
                    CircularProgressIndicator(),

                    SizedBox(height: 16),

                    Text(
                      'Searching for nearby experiments...',

                      textAlign: TextAlign.center,

                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    SizedBox(height: 6),

                    Text(
                      'Experiments will appear here automatically.',

                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            for (final item in experiments)
              Card(
                elevation: 0,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),

                  side: BorderSide(color: scheme.outlineVariant),
                ),

                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,

                    vertical: 10,
                  ),

                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,

                    child: Icon(
                      Icons.science_outlined,

                      color: scheme.onPrimaryContainer,
                    ),
                  ),

                  title: Text(
                    item.name,

                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  subtitle: const Text('Available on your Wi-Fi network'),

                  trailing: Icon(
                    Icons.arrow_forward_ios,

                    size: 18,

                    color: scheme.primary,
                  ),

                  onTap: busy ? null : () => join(item),
                ),
              ),
          ],
        ],
      ],
    );
  }

  Widget buildWaitingRoom() {
    final experiment = activeExperiment;

    final scheme = Theme.of(context).colorScheme;

    final bothReady = localReady && remoteReady;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        Container(
          padding: const EdgeInsets.all(24),

          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.65),

            borderRadius: BorderRadius.circular(24),
          ),

          child: Column(
            children: [
              Icon(
                Icons.groups_2_outlined,

                size: 58,

                color: scheme.onPrimaryContainer,
              ),

              const SizedBox(height: 12),

              Text(
                'Waiting Room',

                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,

                  color: scheme.onPrimaryContainer,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                bothReady
                    ? 'Both participants are ready.'
                    : 'Confirm that both participants are ready to begin.',

                textAlign: TextAlign.center,

                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Card(
          elevation: 0,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),

            side: BorderSide(color: scheme.outlineVariant),
          ),

          child: Padding(
            padding: const EdgeInsets.all(18),

            child: Column(
              children: [
                Text(
                  experiment?.name ?? 'Receiving experiment...',

                  textAlign: TextAlign.center,

                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Text(
                  experiment == null
                      ? 'Waiting for configuration'
                      : '${experiment.tests.length} conversation tests',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        _statusTile(
          icon: Icons.wifi,

          title: 'Connection',

          subtitle: 'Connected to the other phone',

          completed: true,
        ),

        _statusTile(
          icon: Icons.person_outline,

          title: 'You',

          subtitle: localReady ? 'Ready to begin' : 'Not ready yet',

          completed: localReady,
        ),

        _statusTile(
          icon: Icons.person_outline,

          title: hosting ? 'Participant' : 'Host',

          subtitle: remoteReady ? 'Ready to begin' : 'Waiting for confirmation',

          completed: remoteReady,
        ),

        const SizedBox(height: 14),

        if (!localReady)
          SizedBox(
            width: double.infinity,

            child: FilledButton.icon(
              onPressed:
                  experiment == null || (hosting && !configAcknowledged)
                      ? null
                      : setReady,

              icon: const Icon(Icons.check_circle_outline),

              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),

                child: Text("I'm Ready"),
              ),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),

            child: Text(
              'You are ready!',

              textAlign: TextAlign.center,

              style: TextStyle(
                color: Colors.green,

                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        const SizedBox(height: 12),

        if (hosting)
          SizedBox(
            width: double.infinity,

            child: FilledButton.icon(
              onPressed:
                  localReady &&
                          remoteReady &&
                          configAcknowledged &&
                          !startRequested
                      ? startExperiment
                      : null,

              icon: const Icon(Icons.play_arrow),

              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),

                child: Text(
                  startRequested
                      ? 'Starting experiment...'
                      : 'Start Experiment',
                ),
              ),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.all(12),

            child: Text(
              'Once both participants are ready, the host will start the experiment.',

              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget buildConversation(ExperimentConfig experiment) {
    final test = experiment.tests[currentTestIndex];

    final ConversationScenario scenario = conversationScenarios.firstWhere(
      (item) => item.id == test.scenarioId,
    );

    final bool hostIsCaller = hostCallerByTest[currentTestIndex] ?? true;

    final bool iAmCaller = hosting ? hostIsCaller : !hostIsCaller;

    final ConversationRole role =
        iAmCaller ? scenario.caller : scenario.receiver;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        const Icon(Icons.record_voice_over, size: 56, color: Colors.blue),

        const SizedBox(height: 12),

        Text(
          'Conversation Test ${currentTestIndex + 1} of ${experiment.tests.length}',

          textAlign: TextAlign.center,

          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        Text(
          scenario.title,

          textAlign: TextAlign.center,

          style: const TextStyle(fontSize: 20),
        ),

        const SizedBox(height: 16),

        Card(
          color: Theme.of(context).colorScheme.primaryContainer,

          child: Padding(
            padding: const EdgeInsets.all(16),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Icon(Icons.info_outline),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    audio.isRunning
                        ? hosting
                            ? 'The conversation is now active. Follow your scenario and speak with your partner. When you are finished, scroll down and tap "Finish Conversation" to move both phones to the evaluation.'
                            : 'The conversation is now active. Follow your scenario and speak with your partner. The host will end the conversation when it is time to move on.'
                        : audioStarting || localAudioReady
                        ? 'Please wait. The conversation will start once both participants are ready.'
                        : 'Please read your scenario carefully, then scroll to the bottom and tap "Start Audio" when you are ready. The conversation will begin once both participants are ready.',
                  ),
                ),
              ],
            ),
          ),
        ),

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

                Text('You are: ${role.participantName}'),

                const SizedBox(height: 16),

                const Text(
                  'Your task',

                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 6),

                Text(role.task),
              ],
            ),
          ),
        ),

        buildRoleSection('Conditions', role.conditions),

        buildRoleSection('Information to find', role.informationToFind),

        buildRoleSection('Information to provide', role.informationToProvide),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'Discussion question',

                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Text(role.discussionQuestion),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        if (audio.isRunning)
          Text(
            hosting
                ? 'Microphone and audio streaming active'
                : 'Conversation in progress. The host will end the conversation when it is time to move on.',

            textAlign: TextAlign.center,

            style: const TextStyle(
              color: Colors.green,

              fontWeight: FontWeight.bold,
            ),
          )
        else if (audioStarting)
          const Column(
            children: [
              CircularProgressIndicator(),

              SizedBox(height: 12),

              Text('Starting audio and recording...'),
            ],
          )
        else if (localAudioReady)
          Column(
            children: [
              const CircularProgressIndicator(),

              const SizedBox(height: 12),

              Text(
                remoteAudioReady
                    ? 'Both participants ready. Synchronizing audio...'
                    : 'Waiting for the other participant...',

                textAlign: TextAlign.center,
              ),
            ],
          )
        else
          ElevatedButton.icon(
            onPressed: requestAudioStart,

            icon: const Icon(Icons.mic),

            label: const Text('Start Audio'),
          ),

        if (audioError != null) ...[
          const SizedBox(height: 12),

          Text(
            audioError!,

            textAlign: TextAlign.center,

            style: const TextStyle(color: Colors.red),
          ),
        ],

        if (hosting && audio.isRunning) ...[
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: confirmFinishConversation,

            icon: const Icon(Icons.stop_circle_outlined),

            label: const Text('Finish Conversation'),
          ),
        ],
      ],
    );
  }

  Widget buildRoleSection(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              title,

              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),

                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [const Text('•  '), Expanded(child: Text(item))],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildEvaluation(ExperimentConfig experiment) {
    if (!localEvaluationDone) {
      return EvaluationScreen(
        key: ValueKey('evaluation-$currentTestIndex'),

        testNumber: currentTestIndex + 1,

        totalTests: experiment.tests.length,

        onSubmitted: submitEvaluation,
      );
    }

    final theme = Theme.of(context);

    final bothDone = remoteEvaluationDone;

    final canAdvance = hosting && bothDone && stopAcknowledged;

    final isLastTest = currentTestIndex + 1 == experiment.tests.length;

    final progress = (currentTestIndex + 1) / experiment.tests.length;

    return LayoutBuilder(
      builder:
          (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),

            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),

              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,

                    crossAxisAlignment: CrossAxisAlignment.stretch,

                    children: [
                      Text(
                        'SCT ${currentTestIndex + 1} of ${experiment.tests.length}',

                        textAlign: TextAlign.center,

                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,

                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 12),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),

                        child: LinearProgressIndicator(
                          value: progress,

                          minHeight: 7,

                          backgroundColor: theme.colorScheme.primaryContainer,
                        ),
                      ),

                      const SizedBox(height: 30),

                      Card(
                        elevation: 0,

                        color: theme.colorScheme.surfaceContainerLow,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),

                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),

                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,

                            vertical: 32,
                          ),

                          child: Column(
                            children: [
                              Container(
                                width: 92,

                                height: 92,

                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,

                                  shape: BoxShape.circle,
                                ),

                                child: Icon(
                                  Icons.check_circle_rounded,

                                  size: 54,

                                  color: theme.colorScheme.primary,
                                ),
                              ),

                              const SizedBox(height: 22),

                              Text(
                                'Evaluation submitted!',

                                textAlign: TextAlign.center,

                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 12),

                              Text(
                                bothDone
                                    ? 'Both participants have completed their evaluations.'
                                    : 'Your answers have been saved. Please wait while the other participant finishes.',

                                textAlign: TextAlign.center,

                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,

                                  height: 1.5,
                                ),
                              ),

                              const SizedBox(height: 28),

                              Container(
                                padding: const EdgeInsets.all(16),

                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,

                                  borderRadius: BorderRadius.circular(16),
                                ),

                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,

                                          color: theme.colorScheme.primary,

                                          size: 22,
                                        ),

                                        const SizedBox(width: 12),

                                        const Expanded(
                                          child: Text('Your evaluation'),
                                        ),

                                        const Text('Complete'),
                                      ],
                                    ),

                                    const SizedBox(height: 16),

                                    Row(
                                      children: [
                                        if (bothDone)
                                          Icon(
                                            Icons.check_circle,

                                            color: theme.colorScheme.primary,

                                            size: 22,
                                          )
                                        else
                                          const SizedBox(
                                            width: 22,

                                            height: 22,

                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                            ),
                                          ),

                                        const SizedBox(width: 12),

                                        const Expanded(
                                          child: Text('Other participant'),
                                        ),

                                        Text(
                                          bothDone ? 'Complete' : 'In progress',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              if (canAdvance)
                                SizedBox(
                                  width: double.infinity,

                                  child: FilledButton.icon(
                                    onPressed:
                                        nextStartPending
                                            ? null
                                            : advanceExperiment,

                                    icon: Icon(
                                      isLastTest
                                          ? Icons.flag_rounded
                                          : Icons.arrow_forward_rounded,
                                    ),

                                    label: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),

                                      child: Text(
                                        nextStartPending
                                            ? 'Starting next SCT...'
                                            : isLastTest
                                            ? 'Complete Experiment'
                                            : 'Continue to Next SCT',
                                      ),
                                    ),
                                  ),
                                )
                              else if (bothDone && hosting)
                                const Text(
                                  'Synchronizing with the other phone...',

                                  textAlign: TextAlign.center,
                                )
                              else if (bothDone)
                                const Text(
                                  'Waiting for the host to continue...',

                                  textAlign: TextAlign.center,
                                )
                              else
                                Text(
                                  'The next step will become available when both evaluations are complete.',

                                  textAlign: TextAlign.center,

                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                          ),
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

  Widget buildComplete() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,

    children: [
      const Icon(Icons.verified, color: Colors.green, size: 72),

      const SizedBox(height: 16),

      const Text(
        'Experiment Complete',

        textAlign: TextAlign.center,

        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
      ),

      const SizedBox(height: 12),

      Text(
        '${localResults.length} local evaluations collected.',

        textAlign: TextAlign.center,
      ),

      const SizedBox(height: 24),

      if (savingCsv)
        const Center(child: CircularProgressIndicator())
      else if (savedCsvLocation == null)
        FilledButton.icon(
          onPressed: saveCsvReport,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry automatic CSV export'),
        )
      else
        const Text('CSV exported automatically.', textAlign: TextAlign.center),

      if (checkpointPath != null)
        const Text('A private local checkpoint is also stored on this phone.',
            textAlign: TextAlign.center),

      if (savedCsvLocation != null) ...[
        const SizedBox(height: 16),

        const Icon(Icons.check_circle, color: Colors.green, size: 32),

        const Text(
          'CSV saved to Documents / SCT_Results',

          textAlign: TextAlign.center,
        ),
      ],

      const SizedBox(height: 24),

      OutlinedButton.icon(
        onPressed: savedCsvLocation != null ? returnToHome : null,

        icon: const Icon(Icons.home_outlined),

        label: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),

          child: Text('Return to Home'),
        ),
      ),

      if (csvError != null) ...[
        const SizedBox(height: 16),

        Text(
          csvError!,

          textAlign: TextAlign.center,

          style: const TextStyle(color: Colors.red),
        ),
      ],
    ],
  );
}
