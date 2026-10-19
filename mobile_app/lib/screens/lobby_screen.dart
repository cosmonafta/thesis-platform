import 'package:flutter/material.dart';
import '../services/audio/audio_capture_service.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';
import '../services/audio/audio_transport_service.dart';
import '../services/audio/audio_playback_service.dart';
import '../models/experiment_config.dart';
import '../services/audio/audio_impairment_service.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() =>
      _LobbyScreenState();
}

class _LobbyScreenState
    extends State<LobbyScreen> {
  final AudioTransportService
      audioTransportService =
      AudioTransportService();

  final AudioCaptureService
      audioCaptureService =
      AudioCaptureService();

  final AudioPlaybackService
      audioPlaybackService =
      AudioPlaybackService();

  final TextEditingController
      targetIpController =
      TextEditingController();
      final AudioImpairmentService impairmentService =
    AudioImpairmentService();

  bool udpStarted = false;
  bool receivingAudio = false;
  bool microphoneStreaming = false;

  // ============================================================
  // START UDP
  // ============================================================

  Future<void> startUdp() async {
    try {
      await audioTransportService.start(
        port: 5000,
      );

      setState(() {
        udpStarted = true;
      });

      print(
        'UDP transport started',
      );
    } catch (e) {
      print(
        'Error starting UDP: $e',
      );
    }
  }

  // ============================================================
  // SEND UDP TEST
  // ============================================================

  void sendUdpTest() {
    final targetIp =
        targetIpController.text.trim();

    if (targetIp.isEmpty) {
      print(
        'Please enter the other phone IP',
      );
      return;
    }

    audioTransportService.sendTest(
      targetIp,
      5000,
    );
  }

  // ============================================================
  // MEASURE UDP LATENCY
  // ============================================================

  void measureUdpLatency() {
    final targetIp =
        targetIpController.text.trim();

    if (targetIp.isEmpty) {
      print(
        'Please enter the other phone IP',
      );
      return;
    }

    if (!udpStarted) {
      print(
        'Start UDP first',
      );
      return;
    }

    audioTransportService.sendPing(
      targetIp,
      5000,
    );
  }

  // ============================================================
  // RECEIVE + PLAY AUDIO
  // ============================================================

  Future<void>
      startReceivingAudio() async {
    try {
      await audioPlaybackService
          .initialize();

      audioTransportService
          .onAudioReceived =
          (audioData) {
        audioPlaybackService
            .playAudio(audioData);
      };

      setState(() {
        receivingAudio = true;
      });

      print(
        'Ready to receive and play audio',
      );
    } catch (e) {
      print(
        'Error starting audio playback: $e',
      );
    }
  }

  // ============================================================
  // SEND MICROPHONE OVER UDP
  // ============================================================

 
Future<void> sendMicrophoneOverUdp() async {
  final targetIp = targetIpController.text.trim();

  if (targetIp.isEmpty) {
    print('Please enter the other phone IP');
    return;
  }

  if (!udpStarted) {
    print('Start UDP first');
    return;
  }

  if (microphoneStreaming) {
    print('Microphone is already streaming');
    return;
  }

  try {
    // ==========================================
    // 1. CONFIGURE AUDIO DEGRADATIONS
    // ==========================================

    

    // ==========================================
    // 2. CAPTURE AND PROCESS MICROPHONE AUDIO
    // ==========================================

    audioCaptureService.onAudioData = (audioData) {
      impairmentService.process(
        audioData,
        (processedAudio) {
          // Send processed audio to the other phone
          audioTransportService.sendAudio(
            processedAudio,
            targetIp,
            5000,
          );
        },
      );
    };

    // ==========================================
    // 3. START MICROPHONE CAPTURE
    // ==========================================

    await audioCaptureService.start();

    if (!mounted) return;

    setState(() {
      microphoneStreaming = true;
    });

    print('Microphone streaming started');
    print('Packet loss: 20%');
    print('Additional delay: 100 ms');
    print('Echo: ON');
    print('Echo delay: 200 ms');
    print('Echo gain: 0.3');
  } catch (e) {
    impairmentService.stop();
    print('Error starting microphone: $e');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error starting microphone: $e'),
      ),
    );
  }
}


  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    targetIpController.dispose();
    impairmentService.dispose();

    audioCaptureService.dispose();
    audioPlaybackService.dispose();
    audioTransportService.dispose();
    impairmentService.stop();

    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Audio Test'),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              // ==================================================
              // TITLE
              // ==================================================

              const Text(
                'Custom UDP Audio Test',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              const Text(
                'Enter the IP address of '
                'the other phone.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              // ==================================================
              // IP ADDRESS
              // ==================================================

              TextField(
                controller:
                    targetIpController,
                keyboardType:
                    TextInputType
                        .number,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Other phone IP',
                  hintText:
                      'e.g. 192.168.1.20',
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              // ==================================================
              // UDP STATUS
              // ==================================================

              Container(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                decoration:
                    BoxDecoration(
                  color: udpStarted
                      ? Colors.green
                          .withValues(
                          alpha: 0.10,
                        )
                      : Colors.grey
                          .withValues(
                          alpha: 0.10,
                        ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      udpStarted
                          ? Icons
                              .check_circle_outline
                          : Icons
                              .radio_button_unchecked,
                      color: udpStarted
                          ? Colors.green
                          : Colors.grey,
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    Text(
                      udpStarted
                          ? 'UDP running on port 5000'
                          : 'UDP not started',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              // ==================================================
              // START UDP
              // ==================================================

              ElevatedButton(
                onPressed:
                    udpStarted
                        ? null
                        : startUdp,
                child: const Padding(
                  padding:
                      EdgeInsets.all(14),
                  child: Text(
                    'Start UDP',
                  ),
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              // ==================================================
              // UDP TEST
              // ==================================================

              OutlinedButton(
                onPressed:
                    sendUdpTest,
                child: const Padding(
                  padding:
                      EdgeInsets.all(14),
                  child: Text(
                    'Send UDP Test',
                  ),
                ),
              ),

              const SizedBox(
                height: 32,
              ),

              const Divider(),

              const SizedBox(
                height: 24,
              ),

              // ==================================================
              // LATENCY SECTION
              // ==================================================

              const Text(
                'Latency Measurement',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              const Text(
                'This sends a small UDP '
                'packet to the other phone. '
                'The other phone immediately '
                'sends it back.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              ElevatedButton.icon(
                onPressed:
                    udpStarted
                        ? measureUdpLatency
                        : null,
                icon: const Icon(
                  Icons.speed,
                ),
                label: const Padding(
                  padding:
                      EdgeInsets.all(14),
                  child: Text(
                    'Measure UDP Latency',
                  ),
                ),
              ),

              const SizedBox(
                height: 32,
              ),

              const Divider(),

              const SizedBox(
                height: 24,
              ),

              // ==================================================
              // AUDIO SECTION
              // ==================================================

              const Text(
                'Audio',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              ElevatedButton(
                onPressed:
                    receivingAudio
                        ? null
                        : startReceivingAudio,
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    14,
                  ),
                  child: Text(
                    receivingAudio
                        ? 'Receiving Audio'
                        : 'Receive Audio',
                  ),
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              ElevatedButton(
                onPressed:
                    microphoneStreaming
                        ? null
                        : sendMicrophoneOverUdp,
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    14,
                  ),
                  child: Text(
                    microphoneStreaming
                        ? 'Microphone Streaming'
                        : 'Send Microphone over UDP',
                  ),
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              // ==================================================
              // CURRENT STATUS
              // ==================================================

              const Divider(),

              const SizedBox(
                height: 16,
              ),

              const Text(
                'Current status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              _statusRow(
                'UDP',
                udpStarted,
              ),

              _statusRow(
                'Audio playback',
                receivingAudio,
              ),

              _statusRow(
                'Microphone',
                microphoneStreaming,
              ),

              const SizedBox(
                height: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STATUS ROW
  // ============================================================

  Widget _statusRow(
    String title,
    bool active,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Icon(
            active
                ? Icons.check_circle
                : Icons.circle_outlined,
            size: 18,
            color: active
                ? Colors.green
                : Colors.grey,
          ),

          const SizedBox(
            width: 10,
          ),

          Text(
            '$title: '
            '${active ? 'Active' : 'Inactive'}',
          ),
        ],
      ),
    );
  }
}