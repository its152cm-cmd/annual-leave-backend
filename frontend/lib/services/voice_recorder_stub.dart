import 'dart:typed_data';

class VoiceClip {
  final Uint8List bytes;
  final String mime;
  const VoiceClip(this.bytes, this.mime);
}

/// Used where the microphone is not available (tests, non-web builds).
class VoiceRecorder {
  Future<void> start() async {
    throw Exception('Voice recording is only available in the browser. Please type instead.');
  }

  Future<VoiceClip?> stop() async => null;
  void cancel() {}
}
