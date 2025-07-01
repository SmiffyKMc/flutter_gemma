import 'dart:typed_data';
import 'package:flutter_gemma/core/model.dart';

class Message {
  const Message({
    required this.text,
    this.isUser = false,
    this.imageBytes,
    this.audioBytes,
  });

  final String text;
  final bool isUser;
  final Uint8List? imageBytes;
  final Uint8List? audioBytes;

  bool get hasImage => imageBytes != null;
  bool get hasAudio => audioBytes != null;
  bool get isMultimodal => hasImage || hasAudio;

  Message copyWith({
    String? text,
    bool? isUser,
    Uint8List? imageBytes,
    Uint8List? audioBytes,
  }) {
    return Message(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      imageBytes: imageBytes ?? this.imageBytes,
      audioBytes: audioBytes ?? this.audioBytes,
    );
  }

  factory Message.text({
    required String text,
    bool isUser = false,
  }) {
    return Message(
      text: text,
      isUser: isUser,
    );
  }

  factory Message.withImage({
    required String text,
    required Uint8List imageBytes,
    bool isUser = false,
  }) {
    return Message(
      text: text,
      imageBytes: imageBytes,
      isUser: isUser,
    );
  }

  factory Message.imageOnly({
    required Uint8List imageBytes,
    bool isUser = false,
    String text = '',
  }) {
    return Message(
      text: text,
      imageBytes: imageBytes,
      isUser: isUser,
    );
  }

  /// Creates a message with audio and optional text
  factory Message.withAudio({
    required String text,
    required Uint8List audioBytes,
    bool isUser = false,
  }) {
    return Message(
      text: text,
      audioBytes: audioBytes,
      isUser: isUser,
    );
  }

  /// Creates a message with only audio (no text)
  factory Message.audioOnly({
    required Uint8List audioBytes,
    bool isUser = false,
    String text = '',
  }) {
    return Message(
      text: text,
      audioBytes: audioBytes,
      isUser: isUser,
    );
  }

  /// Creates a message with both image and audio
  factory Message.withImageAndAudio({
    required String text,
    required Uint8List imageBytes,
    required Uint8List audioBytes,
    bool isUser = false,
  }) {
    return Message(
      text: text,
      imageBytes: imageBytes,
      audioBytes: audioBytes,
      isUser: isUser,
    );
  }

  String transformToChatPrompt({required ModelType type}) {
    return text;
  }

  @override
  String toString() {
    return 'Message(text: $text, isUser: $isUser, hasImage: $hasImage, hasAudio: $hasAudio)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message &&
        other.text == text &&
        other.isUser == isUser &&
        _listEquals(other.imageBytes, imageBytes) &&
        _listEquals(other.audioBytes, audioBytes);
  }

  @override
  int get hashCode => 
      text.hashCode ^ 
      isUser.hashCode ^ 
      imageBytes.hashCode ^ 
      audioBytes.hashCode;

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}