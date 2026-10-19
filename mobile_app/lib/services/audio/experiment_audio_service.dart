
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../models/experiment_config.dart';
import 'audio_capture_service.dart';
import 'audio_transport_service.dart';
import 'audio_playback_service.dart';
import 'audio_impairment_service.dart';
import 'audio_recording_service.dart';
import 'recording_storage_service.dart';
import 'mp3_conversion_service.dart';

class ExperimentAudioService {
  final AudioCaptureService capture = AudioCaptureService();
  final AudioTransportService transport = AudioTransportService();
  final AudioPlaybackService playback = AudioPlaybackService();
  final AudioImpairmentService impairment = AudioImpairmentService();
  final AudioRecordingService recorder = AudioRecordingService();

  final RecordingStorageService recordingStorage =
      RecordingStorageService();

  final Mp3ConversionService mp3Converter = Mp3ConversionService();

  bool _initialized = false;
  bool _running = false;

  bool get isRunning => _running;

  String? get lastRecordingPath => recorder.filePath;

  Future<void> initialize() async {
    if (_initialized) return;

    await transport.start(port: 5000);

    try {
      await playback.initialize();
    } catch (_) {
      transport.stop();
      rethrow;
    }

    transport.onAudioReceived = (Uint8List data) {
      if (!_running) return;

      recorder.addRemoteAudio(data);
      playback.playAudio(data);
    };

    _initialized = true;
  }

  Future<void> startConversation({
    required String peerIp,
    required DegradationCondition condition,
    required String experimentId,
    required int testNumber,
    required String participantRole,
  }) async {
    if (_running) {
      throw StateError('Audio conversation already running');
    }

    await initialize();

    impairment.configure(condition);
    transport.resetAudioStatistics();

    await recorder.startRecording(
      experimentId: experimentId,
      testNumber: testNumber,
      participantRole: participantRole,
    );

    capture.onAudioData = (Uint8List audioData) {
      if (!_running) return;

      recorder.addLocalAudio(audioData);

      impairment.process(audioData, (Uint8List processedAudio) {
        if (!_running) return;

        transport.sendAudio(
          processedAudio,
          peerIp,
          5000,
        );
      });
    };

    _running = true;

    try {
      await capture.start();
    } catch (_) {
      _running = false;
      capture.onAudioData = null;
      impairment.stop();
      await recorder.stopRecording();
      rethrow;
    }
  }

  Future<void> stopConversation() async {
    if (!_running) return;

    debugPrint('STOP 1: stopConversation called');

    _running = false;
    capture.onAudioData = null;
    impairment.stop();

    debugPrint('STOP 2: stopping microphone');

    try {
      await capture.stop().timeout(
        const Duration(seconds: 3),
      );
      debugPrint('STOP 3: microphone stopped');
    } catch (error) {
      debugPrint('STOP ERROR: microphone stop failed: $error');
    }

    debugPrint('STOP 4: finalizing WAV');

    try {
      final recordingPath = await recorder.stopRecording();

      debugPrint('STOP 5: WAV finalized: $recordingPath');

      if (recordingPath != null) {
        try {
          final mp3Path =
              await mp3Converter.convertWavToMp3(recordingPath);

          debugPrint('STOP 6: MP3 created: $mp3Path');

          final publishedUri =
              await recordingStorage.publishRecording(mp3Path);

          debugPrint('STOP 7: MP3 published: $publishedUri');
        } catch (error) {
          debugPrint('STOP ERROR: MP3 conversion failed: $error');

          // Keep the original WAV accessible if MP3 conversion fails.
          try {
            final fallbackUri =
                await recordingStorage.publishRecording(recordingPath);

            debugPrint('Fallback WAV published: $fallbackUri');
          } catch (publishError) {
            debugPrint(
              'Fallback WAV publishing failed: $publishError',
            );
          }
        }
      }
    } catch (error) {
      debugPrint('STOP ERROR: recording save failed: $error');
    }

    transport.printAudioStatistics();

    debugPrint('STOP 8: stopConversation completed');
  }

  Future<void> dispose() async {
    await stopConversation();

    impairment.dispose();
    await capture.dispose();
    await playback.dispose();
    transport.dispose();

    _initialized = false;
  }
}
