import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class AudioCaptureService {
  static const MethodChannel _controlChannel = MethodChannel(
    'com.example.mobile_app/audio_capture',
  );

  static const EventChannel _audioStreamChannel = EventChannel(
    'com.example.mobile_app/audio_capture_stream',
  );

  StreamSubscription<dynamic>? _audioSubscription;

  Function(Uint8List)? onAudioData;

  int _chunkCounter = 0;

  Future<void> start() async {
    // Avoid accidentally creating two listeners.
    await _audioSubscription?.cancel();

    _chunkCounter = 0;

    _audioSubscription =
        _audioStreamChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        final audioData = Uint8List.fromList(
          List<int>.from(data),
        );

        _chunkCounter++;

        // Do NOT print every chunk.
        //
        // 100 chunks × 10 ms = approximately
        // 1 second of audio.
        if (_chunkCounter % 100 == 0) {
          print(
            'Microphone chunks captured: $_chunkCounter',
          );
        }

        onAudioData?.call(audioData);
      },
      onError: (Object error) {
        print(
          'Audio capture stream error: $error',
        );
      },
    );

    await _controlChannel.invokeMethod(
      'start',
    );

    print(
      'Native microphone capture started',
    );
  }

  Future<void> stop() async {
    await _controlChannel.invokeMethod(
      'stop',
    );

    await _audioSubscription?.cancel();

    _audioSubscription = null;
    _chunkCounter = 0;

    print(
      'Native microphone capture stopped',
    );
  }

  Future<void> dispose() async {
    await stop();
  }
}