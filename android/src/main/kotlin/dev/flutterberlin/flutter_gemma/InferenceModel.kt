package dev.flutterberlin.flutter_gemma

import android.content.Context
import android.graphics.BitmapFactory
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.genai.llminference.GraphOptions
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import com.google.mediapipe.tasks.genai.llminference.LlmInferenceSession
import java.io.File
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.asSharedFlow

// Enum generated via Pigeon
enum class PreferredBackendEnum(val value: Int) {
    UNKNOWN(0), CPU(1), GPU(2), GPU_FLOAT16(3), GPU_MIXED(4), GPU_FULL(5), TPU(6)
}

// Configuration data classes

data class InferenceModelConfig(
    val modelPath: String,
    val maxTokens: Int,
    val supportedLoraRanks: List<Int>?,
    val preferredBackend: PreferredBackendEnum?,
    val maxNumImages: Int?,
    val supportAudio: Boolean = false,
    val maxAudioLength: Int = 30,
)

data class InferenceSessionConfig(
    val temperature: Float,
    val randomSeed: Int,
    val topK: Int,
    val topP: Float?,
    val loraPath: String?,
    val enableVisionModality: Boolean?,
    val enableAudioModality: Boolean?,
)

// Updated InferenceModel

class InferenceModel(
    context: Context,
    val config: InferenceModelConfig
) {
    val llmInference: LlmInference

    private val _partialResults = MutableSharedFlow<Pair<String, Boolean>>(
        extraBufferCapacity = 1,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )
    val partialResults: SharedFlow<Pair<String, Boolean>> = _partialResults.asSharedFlow()

    private val _errors = MutableSharedFlow<Throwable>(
        extraBufferCapacity = 1,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )
    val errors: SharedFlow<Throwable> = _errors.asSharedFlow()

    private val modelExists: Boolean
        get() = File(config.modelPath).exists()

    init {
        if (!modelExists) {
            throw IllegalArgumentException("Model not found at path: ${config.modelPath}")
        }
        try {
            val optionsBuilder = LlmInference.LlmInferenceOptions.builder()
                .setModelPath(config.modelPath)
                .setMaxTokens(config.maxTokens)
                .apply {
                    config.supportedLoraRanks?.let { setSupportedLoraRanks(it) }
                    config.preferredBackend?.let {
                        val backendEnum = LlmInference.Backend.values().getOrNull(it.ordinal)
                            ?: throw IllegalArgumentException("Invalid preferredBackend value: ${it.ordinal}")
                        setPreferredBackend(backendEnum)
                    }
                    config.maxNumImages?.let { setMaxNumImages(it) }
                    // Note: Audio support would be configured here when MediaPipe supports it
                    // For now, we store the configuration for future use
                }
            val options = optionsBuilder.build()
            llmInference = LlmInference.createFromOptions(context, options)
        } catch (e: Exception) {
            throw RuntimeException("Failed to initialize LlmInference: ${e.message}", e)
        }
    }

    fun createSession(config: InferenceSessionConfig): InferenceModelSession {
        return InferenceModelSession(llmInference, config, _partialResults, _errors)
    }

    fun close() {
        llmInference.close()
    }
}

// Updated InferenceModelSession

class InferenceModelSession(
    private val llmInference: LlmInference,
    val config: InferenceSessionConfig,
    private val resultFlow: MutableSharedFlow<Pair<String, Boolean>>,
    private val errorFlow: MutableSharedFlow<Throwable>
) {
    private val session: LlmInferenceSession

    init {
        val sessionOptionsBuilder = LlmInferenceSession.LlmInferenceSessionOptions.builder()
            .setTemperature(config.temperature)
            .setRandomSeed(config.randomSeed)
            .setTopK(config.topK)
            .apply {
                config.topP?.let { setTopP(it) }
                config.loraPath?.let { setLoraPath(it) }
                
                // Configure vision and audio modalities
                val graphOptionsBuilder = GraphOptions.builder()
                config.enableVisionModality?.let { enableVision ->
                    graphOptionsBuilder.setEnableVisionModality(enableVision)
                }
                config.enableAudioModality?.let { enableAudio ->
                    // Note: Audio modality support would be added here when MediaPipe supports it
                    // For now, we store the configuration for future implementation
                    // graphOptionsBuilder.setEnableAudioModality(enableAudio)
                }
                setGraphOptions(graphOptionsBuilder.build())
            }

        val sessionOptions = sessionOptionsBuilder.build()
        session = LlmInferenceSession.createFromOptions(llmInference, sessionOptions)
    }

    fun sizeInTokens(prompt: String): Int = session.sizeInTokens(prompt)

    fun addQueryChunk(prompt: String) = session.addQueryChunk(prompt)

    fun addImage(imageBytes: ByteArray) {
        val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
            ?: throw IllegalArgumentException("Failed to decode image bytes")
        val mpImage = BitmapImageBuilder(bitmap).build()
        session.addImage(mpImage)
    }

    fun addAudio(audioBytes: ByteArray) {
        // TODO: Implement audio preprocessing and USM encoding
        // This is a placeholder for the audio processing pipeline
        
        if (!config.enableAudioModality!!) {
            throw IllegalArgumentException("Audio modality is not enabled for this session")
        }
        
        try {
            // Step 1: Validate audio format and convert to 16kHz mono float32
            val processedAudio = preprocessAudio(audioBytes)
            
            // Step 2: Convert audio to USM tokens (placeholder)
            // In actual implementation, this would use MediaPipe's USM encoder
            // val audioTokens = encodeAudioToTokens(processedAudio)
            
            // Step 3: Add audio tokens to session (placeholder)
            // session.addAudio(audioTokens) // This method doesn't exist yet in MediaPipe
            
            // For now, we'll throw an exception indicating this is not yet implemented
            throw UnsupportedOperationException(
                "Audio input is not yet implemented in MediaPipe Tasks. " +
                "This requires MediaPipe to support audio input for LLM inference."
            )
            
        } catch (e: Exception) {
            throw RuntimeException("Failed to process audio input: ${e.message}", e)
        }
    }
    
    private fun preprocessAudio(audioBytes: ByteArray): FloatArray {
        // TODO: Implement audio preprocessing pipeline
        // 1. Decode audio format (MP3, WAV, etc.) to raw samples
        // 2. Resample to 16kHz if needed
        // 3. Convert to mono if stereo
        // 4. Convert to float32 in range [-1, 1]
        // 5. Validate audio length (max 30 seconds)
        
        // Placeholder implementation
        return FloatArray(0)
    }

    fun generateResponse(): String = session.generateResponse()

    fun generateResponseAsync() {
        session.generateResponseAsync { result, done ->
            result?.let {
                resultFlow.tryEmit(it to done)
            }
        }
    }

    fun close() {
        session.close()
    }
}