import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NativeUploader {
  static const _channel = MethodChannel('com.soulchoice/uploader');

  static Future<void> uploadBytes({
    required String url,
    required String accessToken,
    required String apiKey,
    required Uint8List bytes,
    String contentType = 'image/png',
  }) async {
    // Tarayıcı demosunda (01.08) native kanal yok — MissingPluginException
    // selfie/fotoğraf adımını tıkıyordu. Web'de Supabase storage istemcisi
    // aynı işi yapar (URL'den bucket + nesne yolu ayrıştırılır).
    if (kIsWeb) {
      const marker = '/storage/v1/object/';
      final rest = url.substring(url.indexOf(marker) + marker.length);
      final slash = rest.indexOf('/');
      await Supabase.instance.client.storage
          .from(rest.substring(0, slash))
          .uploadBinary(
            rest.substring(slash + 1),
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      return;
    }
    await _channel.invokeMethod<int>('uploadBytes', {
      'url': url,
      'accessToken': accessToken,
      'apiKey': apiKey,
      'bytes': bytes,
      'contentType': contentType,
    });
  }
}
