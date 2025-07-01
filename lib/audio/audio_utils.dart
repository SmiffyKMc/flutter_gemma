import 'dart:typed_data';
import 'dart:io';

/// Audio utility functions for preprocessing audio data for Gemma 3n models
class AudioUtils {
  /// Audio format specifications for Gemma 3n models
  static const int requiredSampleRate = 16000; // 16kHz
  static const int maxDurationSeconds = 30; // 30 seconds maximum
  static const int maxSamples = requiredSampleRate * maxDurationSeconds; // 480,000 samples
  static const int bytesPerSample = 4; // 32-bit float
  static const int maxAudioBytes = maxSamples * bytesPerSample; // ~1.92MB

  /// Validates audio data format and size
  static bool isValidAudioData(Uint8List audioBytes) {
    // Check if audio data is within size limits
    if (audioBytes.length > maxAudioBytes) {
      return false;
    }
    
    // Basic validation - should be multiple of 4 bytes for float32
    if (audioBytes.length % bytesPerSample != 0) {
      return false;
    }
    
    return true;
  }

  /// Estimates the duration of audio data in seconds
  /// Assumes audio is already in the correct format (16kHz, mono, float32)
  static double estimateDuration(Uint8List audioBytes) {
    final numSamples = audioBytes.length ~/ bytesPerSample;
    return numSamples / requiredSampleRate;
  }

  /// Estimates the number of tokens for the given audio data
  /// Gemma 3n USM encoder produces ~6.25 tokens per second
  static int estimateTokenCount(Uint8List audioBytes) {
    final durationSeconds = estimateDuration(audioBytes);
    return (durationSeconds * 6.25).ceil();
  }

  /// Creates a Float32List from raw audio bytes
  /// This is useful for audio processing and validation
  static Float32List bytesToFloat32List(Uint8List audioBytes) {
    final byteData = ByteData.sublistView(audioBytes);
    final samples = Float32List(audioBytes.length ~/ 4);
    
    for (int i = 0; i < samples.length; i++) {
      samples[i] = byteData.getFloat32(i * 4, Endian.little);
    }
    
    return samples;
  }

  /// Converts Float32List to Uint8List for transmission
  static Uint8List float32ListToBytes(Float32List samples) {
    final byteData = ByteData(samples.length * 4);
    
    for (int i = 0; i < samples.length; i++) {
      byteData.setFloat32(i * 4, samples[i], Endian.little);
    }
    
    return byteData.buffer.asUint8List();
  }

  /// Validates and normalizes audio samples to [-1, 1] range
  static Float32List normalizeAudio(Float32List samples) {
    // Find the maximum absolute value
    double maxAbs = 0.0;
    for (final sample in samples) {
      final abs = sample.abs();
      if (abs > maxAbs) {
        maxAbs = abs;
      }
    }
    
    // If already in range, return as-is
    if (maxAbs <= 1.0) {
      return samples;
    }
    
    // Normalize to [-1, 1] range
    final normalized = Float32List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      normalized[i] = samples[i] / maxAbs;
    }
    
    return normalized;
  }

  /// Trims audio to maximum duration if needed
  static Uint8List trimToMaxDuration(Uint8List audioBytes) {
    if (audioBytes.length <= maxAudioBytes) {
      return audioBytes;
    }
    
    // Trim to maximum allowed bytes
    return Uint8List.sublistView(audioBytes, 0, maxAudioBytes);
  }

  /// Checks if the platform supports audio recording
  static bool get platformSupportsAudioRecording {
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Gets the audio format description for Gemma 3n models
  static String get audioFormatDescription {
    return 'Audio format: 16kHz, mono, 32-bit float, max 30 seconds';
  }

  /// Validates audio format and throws descriptive errors
  static void validateAudioFormat(Uint8List audioBytes) {
    if (audioBytes.isEmpty) {
      throw ArgumentError('Audio data cannot be empty');
    }
    
    if (audioBytes.length % bytesPerSample != 0) {
      throw ArgumentError(
        'Invalid audio format: Data must be 32-bit float (${audioBytes.length} bytes is not divisible by $bytesPerSample)'
      );
    }
    
    final duration = estimateDuration(audioBytes);
    if (duration > maxDurationSeconds) {
      throw ArgumentError(
        'Audio too long: ${duration.toStringAsFixed(1)}s exceeds maximum of ${maxDurationSeconds}s'
      );
    }
    
    if (audioBytes.length > maxAudioBytes) {
      throw ArgumentError(
        'Audio data too large: ${audioBytes.length} bytes exceeds maximum of $maxAudioBytes bytes'
      );
    }
  }
}