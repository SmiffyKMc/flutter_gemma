import 'package:flutter_gemma/core/message.dart';
import 'package:flutter_gemma/flutter_gemma_interface.dart';

class InferenceChat {
  final Future<InferenceModelSession> Function()? sessionCreator;
  final int maxTokens;
  final int tokenBuffer;
  final bool supportImage;
  final bool supportAudio;
  late InferenceModelSession session;

  final List<Message> _fullHistory = [];
  final List<Message> _modelHistory = [];
  int _currentTokens = 0;

  InferenceChat({
    required this.sessionCreator,
    required this.maxTokens,
    this.tokenBuffer = 2000,
    this.supportImage = false,
    this.supportAudio = false,
  });

  List<Message> get fullHistory => List.unmodifiable(_fullHistory);

  Future<void> initSession() async {
    session = await sessionCreator!();
  }

  Future<void> addQueryChunk(Message message) async {
    final messageTokens = await session.sizeInTokens(message.text);
    _currentTokens += messageTokens;

    if (message.hasImage) {
      _currentTokens += 257;
    }

    if (message.hasAudio) {
      final estimatedAudioTokens = _estimateAudioTokens(message.audioBytes!);
      _currentTokens += estimatedAudioTokens;
    }

    if (_currentTokens >= (maxTokens - tokenBuffer)) {
      await _recreateSessionWithReducedChunks();
    }

    await session.addQueryChunk(message);

    _fullHistory.add(message);
    _modelHistory.add(message);
  }

  Future<String> generateChatResponse() async {
    final response = await session.getResponse();
    final responseTokens = await session.sizeInTokens(response);
    _currentTokens += responseTokens;

    if (_currentTokens >= (maxTokens - tokenBuffer)) {
      await _recreateSessionWithReducedChunks();
    }

    final chatMessage = Message(text: response, isUser: false);
    _fullHistory.add(chatMessage);
    _modelHistory.add(chatMessage);

    return response;
  }

  Stream<String> generateChatResponseAsync() async* {
    final buffer = StringBuffer();

    await for (final token in session.getResponseAsync()) {
      buffer.write(token);
      yield token;
    }

    final response = buffer.toString();
    final responseTokens = await session.sizeInTokens(response);
    _currentTokens += responseTokens;

    if (_currentTokens >= (maxTokens - tokenBuffer)) {
      await _recreateSessionWithReducedChunks();
    }

    final chatMessage = Message(text: response, isUser: false);
    _fullHistory.add(chatMessage);
    _modelHistory.add(chatMessage);
  }

  Future<void> _recreateSessionWithReducedChunks() async {
    while (_currentTokens >= (maxTokens - tokenBuffer) && _modelHistory.isNotEmpty) {
      final removedMessage = _modelHistory.removeAt(0);
      final size = await session.sizeInTokens(removedMessage.text);
      _currentTokens -= size;

      if (removedMessage.hasImage) {
        _currentTokens -= 257;
      }

      if (removedMessage.hasAudio) {
        final estimatedAudioTokens = _estimateAudioTokens(removedMessage.audioBytes!);
        _currentTokens -= estimatedAudioTokens;
      }
    }

    await session.close();
    session = await sessionCreator!();

    for (final message in _modelHistory) {
      await session.addQueryChunk(message);
    }
  }

  Future<void> clearHistory() async {
    _fullHistory.clear();
    _modelHistory.clear();
    _currentTokens = 0;
    await session.close();
    session = await sessionCreator!();
  }

  /// Estimates the number of tokens for audio data
  /// In real implementation, this should use the actual USM encoder
  int _estimateAudioTokens(List<int> audioBytes) {
    // Rough estimation: assume 16kHz sample rate, 32-bit float
    // audioBytes length / 4 (bytes per sample) / 16000 (samples per second) * 6.25 (tokens per second)
    final estimatedSeconds = audioBytes.length / (4 * 16000);
    return (estimatedSeconds * 6.25).ceil();
  }

  bool get supportsImages => supportImage;

  bool get supportsAudio => supportAudio;

  int get imageMessageCount => _fullHistory.where((msg) => msg.hasImage).length;

  int get audioMessageCount => _fullHistory.where((msg) => msg.hasAudio).length;

  int get multimodalMessageCount => _fullHistory.where((msg) => msg.isMultimodal).length;
}