
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

  // Both audio sources are stored continuously.
  // No Dart arrival timestamps are used.
  final List<Uint8List> _localChunks = [];
  final List<Uint8List> _remoteChunks = [];

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

    final safeRole = participantRole.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );

    final filename =
        '${safeExperimentId}_SCT_'
        '${testNumber.toString().padLeft(2, '0')}_'
        '$safeRole.wav';

    _filePath =
        '${recordingsDirectory.path}'
        '${Platform.pathSeparator}$filename';

    _localChunks.clear();
    _remoteChunks.clear();

    _recording = true;

    debugPrint('Recording started: $_filePath');
  }

  // LOCAL AUDIO
  // Append microphone samples in their original order.
  void addLocalAudio(Uint8List pcm) {
    if (!_recording || pcm.isEmpty) return;

    _localChunks.add(Uint8List.fromList(pcm));
  }

  // REMOTE AUDIO
  // Append received samples in their received order.
  // No timestamp-based reconstruction.
  void addRemoteAudio(Uint8List pcm) {
    if (!_recording || pcm.isEmpty) return;

    _remoteChunks.add(Uint8List.fromList(pcm));
  }

  Future<String?> stopRecording() async {
    if (!_recording) return null;

    _recording = false;

    final path = _filePath;
    if (path == null) return null;

    // Calculate actual sample counts.
    final localFrames = _countFrames(_localChunks);
    final remoteFrames = _countFrames(_remoteChunks);

    // Use the longer stream as the WAV duration.
    // The shorter channel is padded with silence.
    final totalFrames = max(
      1,
      max(localFrames, remoteFrames),
    );

    debugPrint('========== RECORDING STATS ==========');
    debugPrint('Local frames: $localFrames');
    debugPrint('Remote frames: $remoteFrames');
    debugPrint('Total WAV frames: $totalFrames');

    debugPrint(
      'Local duration: '
      '${(localFrames / sampleRate).toStringAsFixed(2)} s',
    );

    debugPrint(
      'Remote duration: '
      '${(remoteFrames / sampleRate).toStringAsFixed(2)} s',
    );

    debugPrint('=====================================');

    final left = Int16List(totalFrames);
    final right = Int16List(totalFrames);

    // BOTH channels use the same continuous assembly method.
    _appendChunks(_localChunks, left);
    _appendChunks(_remoteChunks, right);

    // 44-byte WAV header + stereo PCM data.
    final output = Uint8List(
      44 + totalFrames * bytesPerFrame,
    );

    final header = ByteData.sublistView(output);

    // RIFF header.
    _writeAscii(output, 0, 'RIFF');

    header.setUint32(
      4,
      output.length - 8,
      Endian.little,
    );

    _writeAscii(output, 8, 'WAVE');

    // Format chunk.
    _writeAscii(output, 12, 'fmt ');

    header.setUint32(
      16,
      16,
      Endian.little,
    );

    // PCM format.
    header.setUint16(
      20,
      1,
      Endian.little,
    );

    // Stereo.
    header.setUint16(
      22,
      channelCount,
      Endian.little,
    );

    header.setUint32(
      24,
      sampleRate,
      Endian.little,
    );

    // Byte rate.
    header.setUint32(
      28,
      sampleRate * bytesPerFrame,
      Endian.little,
    );

    // Block alignment.
    header.setUint16(
      32,
      bytesPerFrame,
      Endian.little,
    );

    // Bits per sample.
    header.setUint16(
      34,
      16,
      Endian.little,
    );

    // Data chunk.
    _writeAscii(output, 36, 'data');

    header.setUint32(
      40,
      totalFrames * bytesPerFrame,
      Endian.little,
    );

    // Interleave left and right samples.
    //
    // LEFT  = local microphone
    // RIGHT = remote participant
    for (var i = 0; i < totalFrames; i++) {
      final offset = 44 + i * bytesPerFrame;

      header.setInt16(
        offset,
        left[i],
        Endian.little,
      );

      header.setInt16(
        offset + 2,
        right[i],
        Endian.little,
      );
    }

    // Save completed WAV.
    final file = File(path);

    await file.writeAsBytes(
      output,
      flush: true,
    );

    _localChunks.clear();
    _remoteChunks.clear();

    debugPrint('Stereo WAV saved successfully: $path');

    return path;
  }

  // Count complete PCM16 frames.
  int _countFrames(List<Uint8List> chunks) {
    var frames = 0;

    for (final chunk in chunks) {
      frames += chunk.length ~/ bytesPerSample;
    }

    return frames;
  }

  // Append PCM chunks continuously to a destination channel.
  //
  // This method is used for BOTH local and remote audio.
  void _appendChunks(
    List<Uint8List> chunks,
    Int16List destination,
  ) {
    var position = 0;

    for (final chunk in chunks) {
      final samples = ByteData.sublistView(chunk);

      final sampleCount =
          chunk.length ~/ bytesPerSample;

      for (var i = 0; i < sampleCount; i++) {
        if (position >= destination.length) {
          return;
        }

        destination[position] = samples.getInt16(
          i * bytesPerSample,
          Endian.little,
        );

        position++;
      }
    }
  }

  void _writeAscii(
    Uint8List output,
    int offset,
    String value,
  ) {
    for (var i = 0; i < value.length; i++) {
      output[offset + i] = value.codeUnitAt(i);
    }
  }
}
