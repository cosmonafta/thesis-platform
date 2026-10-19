
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PdfStorageService {
  static const MethodChannel _channel =
      MethodChannel('sct/recording_storage');

  Future<String> publishPdf(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw FileSystemException(
        'PDF report does not exist',
        filePath,
      );
    }

    final displayName = file.uri.pathSegments.last;

    final publishedUri =
        await _channel.invokeMethod<String>(
      'publishPdf',
      {
        'sourcePath': filePath,
        'displayName': displayName,
      },
    );

    if (publishedUri == null) {
      throw StateError(
        'Android did not return a PDF URI',
      );
    }

    debugPrint('PDF published: $publishedUri');
    return publishedUri;
  }
}
