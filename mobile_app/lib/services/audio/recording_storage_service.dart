
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RecordingStorageService {
  static const MethodChannel _channel =
      MethodChannel('sct/recording_storage');

  Future<String> publishRecording(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw FileSystemException(
        'Recording file does not exist',
        filePath,
      );
    }

    final displayName = file.uri.pathSegments.last;

    final publishedUri = await _channel.invokeMethod<String>(
      'publishRecording',
      {
        'sourcePath': filePath,
        'displayName': displayName,
      },
    );

    if (publishedUri == null) {
      throw StateError('Android did not return a recording URI');
    }

    debugPrint('Recording published: $publishedUri');

    return publishedUri;
  }
}
