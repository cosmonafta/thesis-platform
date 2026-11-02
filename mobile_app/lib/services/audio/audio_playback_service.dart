import 'dart:typed_data';
import 'package:flutter/services.dart';

class AudioPlaybackService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.mobile_app/audio_playback',
  );

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _channel.invokeMethod('initialize');
    _initialized = true;
    print('Audio playback initialized');
  }

  Future<void> playAudio(Uint8List audioData) async {
    if (!_initialized) return;
    await _channel.invokeMethod('playAudio', audioData);
  }

  Future<void> playEcho(Uint8List audioData) async {
    if (!_initialized) return;
    await _channel.invokeMethod('playEcho', audioData);
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    await _channel.invokeMethod('stop');
    _initialized = false;
  }
}
