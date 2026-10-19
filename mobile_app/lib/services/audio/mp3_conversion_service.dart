
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';

class Mp3ConversionService {
  Future<String> convertWavToMp3(String wavPath) async {
    final wavFile = File(wavPath);

    if (!await wavFile.exists()) {
      throw FileSystemException('WAV recording not found', wavPath);
    }

    final mp3Path = wavPath.replaceFirst(
      RegExp(r'\.wav$', caseSensitive: false),
      '.mp3',
    );

    if (mp3Path == wavPath) {
      throw ArgumentError('Expected a .wav file: $wavPath');
    }

    final mp3File = File(mp3Path);

    // Avoid leaving an old MP3 if conversion is repeated.
    if (await mp3File.exists()) {
      await mp3File.delete();
    }

    debugPrint('MP3 conversion started: $wavPath');

    final session = await FFmpegKit.executeWithArguments([
      '-hide_banner',
      '-loglevel',
      'error',
      '-i',
      wavPath,
      '-codec:a',
      'libmp3lame',
      '-b:a',
      '192k',
      '-ar',
      '48000',
      '-ac',
      '2',
      '-y',
      mp3Path,
    ]);

    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getOutput();
      throw StateError(
        'MP3 conversion failed (code: $returnCode): $logs',
      );
    }

    if (!await mp3File.exists() || await mp3File.length() == 0) {
      throw StateError('MP3 output file is missing or empty');
    }

    debugPrint('MP3 conversion completed: $mp3Path');

    return mp3Path;
  }
}
