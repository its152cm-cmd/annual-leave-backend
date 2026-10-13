// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

class VoiceClip {
  final Uint8List bytes;
  final String mime;
  const VoiceClip(this.bytes, this.mime);
}

/// Records the microphone in the browser (MediaRecorder).
class VoiceRecorder {
  html.MediaStream? _stream;
  html.MediaRecorder? _recorder;
  final List<html.Blob> _chunks = [];

  Future<void> start() async {
    final devices = html.window.navigator.mediaDevices;
    if (devices == null) {
      throw Exception('Your browser cannot use the microphone. Please type instead.');
    }
    try {
      _stream = await devices.getUserMedia({'audio': true});
    } catch (_) {
      throw Exception('Microphone permission was blocked. Allow it in the browser address bar, or type instead.');
    }
    _chunks.clear();
    final rec = html.MediaRecorder(_stream!);
    rec.addEventListener('dataavailable', (event) {
      final data = (event as html.BlobEvent).data;
      if (data != null && data.size > 0) _chunks.add(data);
    });
    _recorder = rec;
    rec.start();
  }

  Future<VoiceClip?> stop() async {
    final rec = _recorder;
    if (rec == null) return null;
    final done = Completer<void>();
    rec.addEventListener('stop', (_) {
      if (!done.isCompleted) done.complete();
    });
    if (rec.state != 'inactive') rec.stop();
    await done.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    final String mime = (rec.mimeType ?? '').isNotEmpty ? rec.mimeType! : 'audio/webm';
    _release();
    if (_chunks.isEmpty) return null;
    final blob = html.Blob(_chunks, mime);
    final reader = html.FileReader();
    final read = Completer<Uint8List>();
    reader.onLoadEnd.listen((_) {
      final r = reader.result;
      if (r is ByteBuffer) {
        read.complete(r.asUint8List());
      } else if (r is Uint8List) {
        read.complete(r);
      } else {
        read.complete(Uint8List(0));
      }
    });
    reader.readAsArrayBuffer(blob);
    final bytes = await read.future;
    _chunks.clear();
    if (bytes.isEmpty) return null;
    return VoiceClip(bytes, mime);
  }

  void cancel() {
    try {
      if (_recorder != null && _recorder!.state != 'inactive') _recorder!.stop();
    } catch (_) {}
    _release();
    _chunks.clear();
  }

  void _release() {
    try {
      _stream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}
    _stream = null;
    _recorder = null;
  }
}
