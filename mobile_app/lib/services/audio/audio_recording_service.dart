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

  final List<Uint8List> _localChunks = [];
  final List<Uint8List> _remoteChunks = [];

  // Returned echo is a separate source, mixed into LOCAL at its arrival time.
  // It must not be appended as microphone audio (that would shift the timeline).
  final List<({int startFrame, Uint8List pcm})> _echoChunks = [];
  final Stopwatch _clock = Stopwatch();
  int? _firstLocalChunkUs;


  bool _recording = false;
  String? _filePath;
  String? _localFilePath;
  String? _remoteFilePath;

  bool get isRecording => _recording;
  String? get filePath => _filePath;
  String? get localFilePath => _localFilePath;
  String? get remoteFilePath => _remoteFilePath;

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
    final base = '${safeExperimentId}_SCT_'
        '${testNumber.toString().padLeft(2, '0')}_$safeRole';
    final folder = recordingsDirectory.path;
    final sep = Platform.pathSeparator;

    // Retain the original stereo file name for compatibility.
    _filePath = '$folder$sep$base.wav';
    _localFilePath = '${folder}${sep}${base}_Local.wav';
    _remoteFilePath = '${folder}${sep}${base}_Remote.wav';

    _localChunks.clear();
    _remoteChunks.clear();
    _echoChunks.clear();
    _firstLocalChunkUs = null;
    _clock.reset();
    _clock.start();
    _recording = true;
    debugPrint('Recording started: $_filePath');
  }

  void addLocalAudio(Uint8List pcm) {
    if (!_recording || pcm.isEmpty) return;
    _firstLocalChunkUs ??= _clock.elapsedMicroseconds;
    _localChunks.add(Uint8List.fromList(pcm));
  }

  void addRemoteAudio(Uint8List pcm) {
    if (!_recording || pcm.isEmpty) return;
    _remoteChunks.add(Uint8List.fromList(pcm));
  }

  // Call only for actual RETURNED ECHO, not for normal remote voice.
  // The echo is already attenuated by ExperimentAudioService.
  void addEchoAudio(Uint8List pcm) {
    if (!_recording || pcm.isEmpty) return;
    final origin = _firstLocalChunkUs;
    if (origin == null) return;
    final elapsedUs = _clock.elapsedMicroseconds - origin;
    final frame = max(0, (elapsedUs * sampleRate ~/ 1000000));
    _echoChunks.add((startFrame: frame, pcm: Uint8List.fromList(pcm)));
  }

  Future<String?> stopRecording() async {
    if (!_recording) return null;
    _recording = false;
    _clock.stop();

    final path = _filePath;
    if (path == null) return null;

    final localFrames = _countFrames(_localChunks);
    final remoteFrames = _countFrames(_remoteChunks);
    var echoEndFrame = 0;
    for (final echo in _echoChunks) {
      echoEndFrame = max(echoEndFrame,
          echo.startFrame + echo.pcm.length ~/ bytesPerSample);
    }
    final localMixFrames = max(localFrames, echoEndFrame);
    final totalFrames = max(1, max(localMixFrames, remoteFrames));

    debugPrint('========== RECORDING STATS ==========');
    debugPrint('Local frames: $localFrames');
    debugPrint('Remote frames: $remoteFrames');
    debugPrint('Echo chunks mixed into local: ${_echoChunks.length}');
    debugPrint('Total stereo WAV frames: $totalFrames');
    debugPrint('Local duration: '
        '${(localFrames / sampleRate).toStringAsFixed(2)} s');
    debugPrint('Remote duration: '
        '${(remoteFrames / sampleRate).toStringAsFixed(2)} s');
    debugPrint('=====================================');

    final left = Int16List(totalFrames);
    final right = Int16List(totalFrames);
    _appendChunks(_localChunks, left);
    _mixEchoInto(left);
    _appendChunks(_remoteChunks, right);

    // Preserve original stereo WAV layout and zero-padding behavior.
    final stereoOutput = Uint8List(44 + totalFrames * bytesPerFrame);
    _writeWavHeader(stereoOutput, channels: 2, frames: totalFrames);
    final stereoData = ByteData.sublistView(stereoOutput);
    for (var i = 0; i < totalFrames; i++) {
      final offset = 44 + i * bytesPerFrame;
      stereoData.setInt16(offset, left[i], Endian.little);
      stereoData.setInt16(offset + 2, right[i], Endian.little);
    }

    // Independent mono WAVs contain their own source stream, without
    // padding to the other stream's duration.
    final localPath = _localFilePath;
    final remotePath = _remoteFilePath;
    try {
      await File(path).writeAsBytes(stereoOutput, flush: true);
      if (localPath != null) {
        await _writeMonoSamples(localPath, left, localMixFrames);
      }
      if (remotePath != null) {
        await _writeMonoWav(remotePath, _remoteChunks, remoteFrames);
      }
      debugPrint('Stereo WAV saved: $path');
      debugPrint('Local mono WAV saved: $localPath');
      debugPrint('Remote mono WAV saved: $remotePath');
      return path;
    } finally {
      _localChunks.clear();
      _remoteChunks.clear();
      _echoChunks.clear();
      _firstLocalChunkUs = null;
    }
  }

  void _mixEchoInto(Int16List destination) {
    for (final echo in _echoChunks) {
      final source = ByteData.sublistView(echo.pcm);
      final count = echo.pcm.length ~/ bytesPerSample;
      for (var i = 0; i < count; i++) {
        final position = echo.startFrame + i;
        if (position >= destination.length) break;
        final value = source.getInt16(i * bytesPerSample, Endian.little);
        destination[position] =
            (destination[position] + value).clamp(-32768, 32767).toInt();
      }
    }
  }

  Future<void> _writeMonoSamples(
    String path,
    Int16List samples,
    int frames,
  ) async {
    final output = Uint8List(44 + frames * bytesPerSample);
    _writeWavHeader(output, channels: 1, frames: frames);
    final bytes = ByteData.sublistView(output);
    for (var i = 0; i < frames; i++) {
      bytes.setInt16(44 + i * bytesPerSample, samples[i], Endian.little);
    }
    await File(path).writeAsBytes(output, flush: true);
  }

  Future<void> _writeMonoWav(
    String path,
    List<Uint8List> chunks,
    int frames,
  ) async {
    // A valid 44-byte WAV is produced even for an empty stream.
    final output = Uint8List(44 + frames * bytesPerSample);
    _writeWavHeader(output, channels: 1, frames: frames);
    final samples = ByteData.sublistView(output);
    var position = 44;
    for (final chunk in chunks) {
      final source = ByteData.sublistView(chunk);
      final count = chunk.length ~/ bytesPerSample;
      for (var i = 0; i < count; i++) {
        samples.setInt16(
          position,
          source.getInt16(i * bytesPerSample, Endian.little),
          Endian.little,
        );
        position += bytesPerSample;
      }
    }
    await File(path).writeAsBytes(output, flush: true);
  }

  void _writeWavHeader(
    Uint8List output, {
    required int channels,
    required int frames,
  }) {
    final header = ByteData.sublistView(output);
    final frameBytes = channels * bytesPerSample;
    final dataBytes = frames * frameBytes;
    _writeAscii(output, 0, 'RIFF');
    header.setUint32(4, output.length - 8, Endian.little);
    _writeAscii(output, 8, 'WAVE');
    _writeAscii(output, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * frameBytes, Endian.little);
    header.setUint16(32, frameBytes, Endian.little);
    header.setUint16(34, 16, Endian.little);
    _writeAscii(output, 36, 'data');
    header.setUint32(40, dataBytes, Endian.little);
  }

  int _countFrames(List<Uint8List> chunks) {
    var frames = 0;
    for (final chunk in chunks) {
      frames += chunk.length ~/ bytesPerSample;
    }
    return frames;
  }

  void _appendChunks(List<Uint8List> chunks, Int16List destination) {
    var position = 0;
    for (final chunk in chunks) {
      final samples = ByteData.sublistView(chunk);
      final sampleCount = chunk.length ~/ bytesPerSample;
      for (var i = 0; i < sampleCount; i++) {
        if (position >= destination.length) return;
        destination[position] = samples.getInt16(
          i * bytesPerSample,
          Endian.little,
        );
        position++;
      }
    }
  }

  void _writeAscii(Uint8List output, int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      output[offset + i] = value.codeUnitAt(i);
    }
  }
}
