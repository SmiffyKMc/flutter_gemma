import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// Example demonstrating audio support with Gemma 3n models
class AudioGemmaExample extends StatefulWidget {
  const AudioGemmaExample({super.key});

  @override
  State<AudioGemmaExample> createState() => _AudioGemmaExampleState();
}

class _AudioGemmaExampleState extends State<AudioGemmaExample> {
  InferenceModel? _model;
  InferenceChat? _chat;
  final List<Message> _messages = [];
  bool _isLoading = false;
  String _status = 'Ready to initialize model';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Gemma 3n Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Status indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: $_status',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Audio Format: ${AudioUtils.audioFormatDescription}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_chat != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Audio Support: ${_chat!.supportsAudio ? "✓ Enabled" : "✗ Disabled"}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _chat!.supportsAudio ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Messages list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageCard(message);
              },
            ),
          ),
          
          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Model initialization
                if (_model == null) ...[
                  ElevatedButton(
                    onPressed: _isLoading ? null : _initializeModel,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Initialize Gemma 3n Model'),
                  ),
                ] else ...[
                  // Audio input examples
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _testAudioTranscription,
                        icon: const Icon(Icons.mic),
                        label: const Text('Test Audio Transcription'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _testAudioTranslation,
                        icon: const Icon(Icons.translate),
                        label: const Text('Test Audio Translation'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _testMultimodalInput,
                        icon: const Icon(Icons.multitrack_audio),
                        label: const Text('Test Multimodal'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _clearChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Clear Chat'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(Message message) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  message.isUser ? Icons.person : Icons.smart_toy,
                  size: 16,
                  color: message.isUser ? Colors.blue : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  message.isUser ? 'User' : 'Gemma 3n',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (message.hasAudio)
                  const Icon(Icons.audiotrack, size: 16, color: Colors.purple),
                if (message.hasImage)
                  const Icon(Icons.image, size: 16, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 8),
            Text(message.text),
            if (message.hasAudio) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.audiotrack, size: 16, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text(
                      'Audio: ${AudioUtils.estimateDuration(message.audioBytes!).toStringAsFixed(1)}s '
                      '(~${AudioUtils.estimateTokenCount(message.audioBytes!)} tokens)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _initializeModel() async {
    setState(() {
      _isLoading = true;
      _status = 'Initializing Gemma 3n model with audio support...';
    });

    try {
      // Initialize model with audio support
      _model = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.gemma3nE2B, // Use Gemma 3n for audio support
        maxTokens: 2048,
        supportImage: true,
        supportAudio: true, // Enable audio support
        maxAudioLength: 30, // 30 seconds max
      );

      // Create chat with audio support
      _chat = await _model!.createChat(
        temperature: 0.8,
        supportImage: true,
        supportAudio: true, // Enable audio in chat
      );

      setState(() {
        _status = 'Model ready with audio support';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testAudioTranscription() async {
    if (_chat == null) return;
    
    setState(() {
      _isLoading = true;
      _status = 'Testing audio transcription...';
    });

    try {
      // Create example audio data (16kHz, mono, float32)
      final audioData = _createExampleAudioData(duration: 5.0);
      
      // Validate audio format
      AudioUtils.validateAudioFormat(audioData);
      
      // Create message with audio
      final message = Message.withAudio(
        text: 'Please transcribe this audio:',
        audioBytes: audioData,
        isUser: true,
      );

      setState(() {
        _messages.add(message);
      });

      // Add message to chat and get response
      await _chat!.addQueryChunk(message);
      final response = await _chat!.generateChatResponse();

      setState(() {
        _messages.add(Message.text(text: response, isUser: false));
        _status = 'Audio transcription completed';
      });
    } catch (e) {
      setState(() {
        _status = 'Error in audio transcription: $e';
      });
      
      // Add error message
      setState(() {
        _messages.add(Message.text(
          text: 'Error: Audio transcription is not yet implemented in MediaPipe Tasks.',
          isUser: false,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testAudioTranslation() async {
    if (_chat == null) return;
    
    setState(() {
      _isLoading = true;
      _status = 'Testing audio translation...';
    });

    try {
      // Create example audio data
      final audioData = _createExampleAudioData(duration: 3.0);
      
      // Create message with audio for translation
      final message = Message.withAudio(
        text: 'Please translate this Spanish audio to English:',
        audioBytes: audioData,
        isUser: true,
      );

      setState(() {
        _messages.add(message);
      });

      await _chat!.addQueryChunk(message);
      final response = await _chat!.generateChatResponse();

      setState(() {
        _messages.add(Message.text(text: response, isUser: false));
        _status = 'Audio translation completed';
      });
    } catch (e) {
      setState(() {
        _status = 'Error in audio translation: $e';
        _messages.add(Message.text(
          text: 'Error: Audio translation is not yet implemented in MediaPipe Tasks.',
          isUser: false,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testMultimodalInput() async {
    if (_chat == null) return;
    
    setState(() {
      _isLoading = true;
      _status = 'Testing multimodal input...';
    });

    try {
      // Create example audio and image data
      final audioData = _createExampleAudioData(duration: 2.0);
      final imageData = _createExampleImageData();
      
      // Create multimodal message
      final message = Message.withImageAndAudio(
        text: 'Describe what you see and hear:',
        imageBytes: imageData,
        audioBytes: audioData,
        isUser: true,
      );

      setState(() {
        _messages.add(message);
      });

      await _chat!.addQueryChunk(message);
      final response = await _chat!.generateChatResponse();

      setState(() {
        _messages.add(Message.text(text: response, isUser: false));
        _status = 'Multimodal processing completed';
      });
    } catch (e) {
      setState(() {
        _status = 'Error in multimodal processing: $e';
        _messages.add(Message.text(
          text: 'Error: Multimodal audio processing is not yet implemented.',
          isUser: false,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _status = 'Chat cleared';
    });
  }

  /// Creates example audio data (sine wave) for testing
  Uint8List _createExampleAudioData({required double duration}) {
    const sampleRate = AudioUtils.requiredSampleRate;
    final numSamples = (sampleRate * duration).round();
    final samples = Float32List(numSamples);
    
    // Generate a simple sine wave at 440Hz
    for (int i = 0; i < numSamples; i++) {
      final time = i / sampleRate;
      samples[i] = 0.3 * (440 * 2 * 3.14159 * time).sin(); // Sine wave
    }
    
    return AudioUtils.float32ListToBytes(samples);
  }

  /// Creates example image data for testing
  Uint8List _createExampleImageData() {
    // Create a simple 100x100 RGB image (red square)
    final width = 100;
    final height = 100;
    final bytes = Uint8List(width * height * 3); // RGB
    
    for (int i = 0; i < bytes.length; i += 3) {
      bytes[i] = 255;     // Red
      bytes[i + 1] = 0;   // Green
      bytes[i + 2] = 0;   // Blue
    }
    
    return bytes;
  }
}