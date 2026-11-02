import 'dart:async';
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

  final RecordingStorageService recordingStorage = RecordingStorageService();
  final Mp3ConversionService mp3Converter = Mp3ConversionService();

  static const double _echoGain = 0.3;
  final List<Timer> _pendingEchoReturnTimers = [];

  bool _initialized = false;
  bool _running = false;
  bool _echoEnabled = false;
  String? _peerIp;
  int _echoReturnDelayMs = 0;
  int _receivedEchoChunks = 0;
  int _returnedEchoChunks = 0;

  bool get isRunning => _running;
  String? get lastRecordingPath => recorder.filePath;

  // PCM16 little-endian, mono. Copy the bytes: received UDP buffers should
  // not be modified, and normal partner speech must remain at full volume.
  Uint8List _attenuateForEcho(Uint8List input) {
    final output = Uint8List(input.length);
    final source = ByteData.sublistView(input);
    final target = ByteData.sublistView(output);
    for (int offset = 0; offset + 1 < input.length; offset += 2) {
      final sample = source.getInt16(offset, Endian.little);
      target.setInt16(
        offset,
        (sample * _echoGain).round().clamp(-32768, 32767).toInt(),
        Endian.little,
      );
    }
    return output;
  }

  void _returnEcho(Uint8List incomingVoice) {
    if (!_running || !_echoEnabled || _peerIp == null) return;

    final echoPcm = _attenuateForEcho(incomingVoice);
    final destination = _peerIp!;

    // The normal outgoing audio already passes through the existing
    // impairment service. This delay models the return leg only.
    if (_echoReturnDelayMs == 0) {
      transport.sendEcho(echoPcm, destination, 5000);
      _returnedEchoChunks++;
      return;
    }

    late final Timer timer;
    timer = Timer(Duration(milliseconds: _echoReturnDelayMs), () {
      _pendingEchoReturnTimers.remove(timer);
      if (!_running || !_echoEnabled || _peerIp != destination) return;
      transport.sendEcho(echoPcm, destination, 5000);
      _returnedEchoChunks++;
    });
    _pendingEchoReturnTimers.add(timer);
  }

  void _cancelPendingEchoReturns() {
    for (final timer in _pendingEchoReturnTimers) {
      timer.cancel();
    }
    _pendingEchoReturnTimers.clear();
  }

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

      // Only NORMAL incoming voice is returned. Echo packets are handled
      // by the separate callback below and are never sent back again.
      _returnEcho(data);
    };

    transport.onEchoReceived = (Uint8List data) {
      if (!_running || !_echoEnabled) return;
      _receivedEchoChunks++;
      // Step 3: mix the returned network echo with incoming partner speech.
      playback.playEcho(data);
      // Record returned echo on LOCAL (left), not REMOTE (right).
      recorder.addEchoAudio(data);
      if (_receivedEchoChunks % 100 == 0) {
        debugPrint('STEP 2: received $_receivedEchoChunks echo packets '
            '(latest PCM payload: ${data.length} bytes)');
      }
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

    _cancelPendingEchoReturns();
    _peerIp = peerIp;
    _echoEnabled = condition.echoEnabled;
    _echoReturnDelayMs = condition.delayMs < 0 ? 0 : condition.delayMs;
    _receivedEchoChunks = 0;
    _returnedEchoChunks = 0;

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
        transport.sendAudio(processedAudio, peerIp, 5000);
      });
    };

    _running = true;

    try {
      await capture.start();
    } catch (_) {
      _running = false;
      capture.onAudioData = null;
      _cancelPendingEchoReturns();
      _echoEnabled = false;
      _peerIp = null;
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
    _cancelPendingEchoReturns();
    _echoEnabled = false;
    _peerIp = null;
    impairment.stop();

    debugPrint('STEP 2 echo totals: returned $_returnedEchoChunks chunks; '
        'received $_receivedEchoChunks echo chunks');
    debugPrint('STOP 2: stopping microphone');

    try {
      await capture.stop().timeout(const Duration(seconds: 3));
      debugPrint('STOP 3: microphone stopped');
    } catch (error) {
      debugPrint('STOP ERROR: microphone stop failed: $error');
    }

    debugPrint('STOP 4: finalizing WAV recordings');

    try {
      final recordingPath = await recorder.stopRecording();
      debugPrint('STOP 5: WAVs finalized: $recordingPath');

      final paths = <String?>[
        recordingPath,
        recorder.localFilePath,
        recorder.remoteFilePath,
      ];
      for (final wavPath in paths) {
        if (wavPath == null) continue;
        try {
          final mp3Path = await mp3Converter.convertWavToMp3(wavPath);
          debugPrint('MP3 created: $mp3Path');
          final publishedUri =
              await recordingStorage.publishRecording(mp3Path);
          debugPrint('MP3 published: $publishedUri');
        } catch (error) {
          debugPrint('MP3 conversion/publication failed for $wavPath: $error');
          try {
            final fallbackUri =
                await recordingStorage.publishRecording(wavPath);
            debugPrint('Fallback WAV published: $fallbackUri');
          } catch (publishError) {
            debugPrint('Fallback WAV publishing failed: $publishError');
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
    _cancelPendingEchoReturns();
    impairment.dispose();
    await capture.dispose();
    await playback.dispose();
    transport.dispose();
    _initialized = false;
  }
}
