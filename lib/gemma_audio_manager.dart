import 'package:flutter_gemma/pigeon.g.dart';

/// Simple wrapper around the platform audio API.
class GemmaAudioManager {
  final PlatformService _service = PlatformService();

  /// Starts microphone streaming on the native side.
  Future<void> startStream() {
    return _service.startAudioStream();
  }

  /// Stops microphone streaming on the native side.
  Future<void> stopStream() {
    return _service.stopAudioStream();
  }

  /// Sends an audio embedding to the active session.
  Future<void> sendEmbedding(List<double> embedding) {
    return _service.sendAudioEmbedding(
      AudioEmbedding(embedding: embedding),
    );
  }
}
