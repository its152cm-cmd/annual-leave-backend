import 'dart:convert';
import 'dart:typed_data';

import '../core/api/api_client.dart';

class VoiceService {
  /// Sends a recording to the backend and returns what the person said.
  Future<String> transcribe(Uint8List bytes, String mime) async {
    final res = await ApiClient().post('/api/preferences/transcribe', {
      'audioBase64': base64Encode(bytes),
      'mimeType': mime,
    });
    return '${(res as Map)['text'] ?? ''}'.trim();
  }
}
