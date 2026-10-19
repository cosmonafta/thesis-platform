import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'package:path_provider/path_provider.dart';

class AudioRecordingService {
  static const int sampleRate = 48000;
  static const int channelCount = 2;
  static const int bytesPerSample = 2;
  static const int bytesPerFrame = channelCount * bytesPerSample;

  // Keep pending audio in memory until the SCT finishes.
  // We use one common timeline for both audio sources.
  final Stopwatch _clock = Stopwatch();

  final List<_AudioChunk> _localChunks = [];
  final List<_AudioChunk> _remoteChunks = [];

  bool _recording = false;
  String? _filePath;

  bool get isRecording => _recording;
  String? get filePath => _filePath;

  Future<void> startRecording({
    required String experimentId,
    required int testNumber,
    required String participantRole,
  }) async {
    if (_recording) {
      throw StateError('Recording already in progress');
    }

    final directory = await getApplicationDocumentsDirectory();

    final recordingsDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}recordings',
    );

    await recordingsDirectory.create(recursive: true);

    final safeExperimentId = experimentId.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );

    final safeRole = participantRole.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    final filename =
        '${safeExperimentId}_SCT_${testNumber.toString().padLeft(2, '0')}_$safeRole.wav';

    _filePath = '${recordingsDirectory.path}${Platform.pathSeparator}$filename';

    _localChunks.clear();
    _remoteChunks.clear();

    _clock
      ..reset()
      ..start();

    _recording = true;

    debugPrint('Recording started: $_filePath');
  }

  void addLocalAudio(Uint8List pcm) {
    if (!_recording || pcm.isEmpty) return;

    _localChunks.add(
      _AudioChunk(
        timeMicroseconds: _clock.elapsedMicroseconds,
        pcm: Uint8List.fromList(pcm),
      ),
    );
  }

  void addRemoteAudio(Uint8List pcm) {
    if (!_recording || pcm.isEmpty) return;

    _remoteChunks.add(
      _AudioChunk(
        timeMicroseconds: _clock.elapsedMicroseconds,
        pcm: Uint8List.fromList(pcm),
      ),
    );
  }

  Future<String?> stopRecording() async {
    if (!_recording) return null;

    _recording = false;
    _clock.stop();

    final path = _filePath;
    if (path == null) return null;

    final durationMicroseconds = _clock.elapsedMicroseconds;

    // Convert elapsed time into stereo sample frames.
    final totalFrames = max(
      1,
      (durationMicroseconds * sampleRate / 1000000).ceil(),
    );

    final left = Int16List(totalFrames);
    final right = Int16List(totalFrames);

    _mixChunksIntoChannel(_localChunks, left);
    _mixChunksIntoChannel(_remoteChunks, right);

    final output = Uint8List(44 + totalFrames * bytesPerFrame);
    final header = ByteData.sublistView(output);

    // WAV header.
    _writeAscii(output, 0, 'RIFF');
    header.setUint32(4, output.length - 8, Endian.little);

    _writeAscii(output, 8, 'WAVE');
    _writeAscii(output, 12, 'fmt ');

    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channelCount, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);

    header.setUint32(28, sampleRate * bytesPerFrame, Endian.little);

    header.setUint16(32, bytesPerFrame, Endian.little);

    header.setUint16(34, 16, Endian.little);

    _writeAscii(output, 36, 'data');

    header.setUint32(40, totalFrames * bytesPerFrame, Endian.little);

    // Interleave left and right PCM samples.
    for (var i = 0; i < totalFrames; i++) {
      final offset = 44 + i * bytesPerFrame;

      header.setInt16(offset, left[i], Endian.little);

      header.setInt16(offset + 2, right[i], Endian.little);
    }

    final file = File(path);
    await file.writeAsBytes(output, flush: true);

    _localChunks.clear();
    _remoteChunks.clear();

    debugPrint('Recording saved: $path');

    return path;
  }

  void _mixChunksIntoChannel(List<_AudioChunk> chunks, Int16List destination) {
    for (final chunk in chunks) {
      final samples = ByteData.sublistView(chunk.pcm);

      final sampleCount = chunk.pcm.length ~/ bytesPerSample;

      // The timestamp marks when the chunk reached Dart.
      // Approximate its start by subtracting its audio duration.
      final chunkDurationMicroseconds = sampleCount * 1000000 / sampleRate;

      final startMicroseconds =
          chunk.timeMicroseconds - chunkDurationMicroseconds;

      final startFrame = max(
        0,
        (startMicroseconds * sampleRate / 1000000).round(),
      );

      for (var i = 0; i < sampleCount; i++) {
        final position = startFrame + i;

        if (position >= destination.length) break;

        final sample = samples.getInt16(i * bytesPerSample, Endian.little);

        final mixed = destination[position] + sample;

        destination[position] = mixed.clamp(-32768, 32767).toInt();
      }
    }
  }

  void _writeAscii(Uint8List output, int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      output[offset + i] = value.codeUnitAt(i);
    }
  }
}

class _AudioChunk {
  final int timeMicroseconds;
  final Uint8List pcm;

  _AudioChunk({required this.timeMicroseconds, required this.pcm});
}
