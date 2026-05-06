import 'dart:typed_data';
import 'package:flutter/services.dart';

class NativeUploader {
  static const _channel = MethodChannel('com.soulchoice/uploader');

  static Future<void> uploadBytes({
    required String url,
    required String accessToken,
    required String apiKey,
    required Uint8List bytes,
    String contentType = 'image/png',
  }) async {
    await _channel.invokeMethod<int>('uploadBytes', {
      'url': url,
      'accessToken': accessToken,
      'apiKey': apiKey,
      'bytes': bytes,
      'contentType': contentType,
    });
  }
}
