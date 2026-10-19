import 'dart:io';

import 'package:flutter/services.dart';

class CsvStorageService {
  static const MethodChannel _channel = MethodChannel('sct/recording_storage');

  Future<String> publishCsv(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('CSV file not found', filePath);
    }
    final uri = await _channel.invokeMethod<String>('publishCsv', {
      'sourcePath': filePath,
      'displayName': file.uri.pathSegments.last,
    });
    if (uri == null || uri.isEmpty) {
      throw StateError('Android did not return a CSV storage location.');
    }
    return uri;
  }
}
