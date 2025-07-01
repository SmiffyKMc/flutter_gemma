import Foundation
import MediaPipeTasksGenAI
import MediaPipeTasksGenAIC

struct InferenceModel {
    private(set) var inference: LlmInference

    init(modelPath: String,
         maxTokens: Int,
         supportedLoraRanks: [Int]? = nil,
         maxNumImages: Int = 0,
         supportAudio: Bool = false,
         maxAudioLength: Int = 30) throws {

        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "InferenceModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Document directory not found"])
        }

        let fileName = (modelPath as NSString).lastPathComponent
        let resolvedPath = documentDirectory.appendingPathComponent(fileName).path
        let llmOptions = LlmInference.Options(modelPath: resolvedPath)

        llmOptions.maxTokens = maxTokens
        llmOptions.waitForWeightUploads = true

        if let supportedLoraRanks = supportedLoraRanks {
            llmOptions.supportedLoraRanks = supportedLoraRanks
        }

        if maxNumImages > 0 {
            llmOptions.maxImages = maxNumImages
        }

        // Note: Audio support would be configured here when MediaPipe supports it
        // For now, we store the configuration for future use

        self.inference = try LlmInference(options: llmOptions)
    }

    // Access to metrics
    var metrics: LlmInference.Metrics {
        return inference.metrics
    }
}

final class InferenceSession {
    private let session: LlmInference.Session
    private let supportsAudio: Bool

    init(inference: LlmInference,
         temperature: Float,
         randomSeed: Int,
         topk: Int,
         topP: Double? = nil,
         loraPath: String? = nil,
         enableVisionModality: Bool = false,
         enableAudioModality: Bool = false) throws {

        self.supportsAudio = enableAudioModality
        
        let options = LlmInference.Session.Options()
        options.temperature = temperature
        options.randomSeed = randomSeed
        options.topk = topk

        if let topP = topP {
            options.topp = Float(topP)
        }

        if let loraPath = loraPath {
            options.loraPath = loraPath
        }

        options.enableVisionModality = enableVisionModality
        // Note: Audio modality support would be added here when MediaPipe supports it
        // options.enableAudioModality = enableAudioModality

        // Initialize session with proper error handling for Gemma 3n
        do {
            let newSession = try LlmInference.Session(llmInference: inference, options: options)
            // Force initial token processing to ensure input*pos is properly set
            _ = try newSession.sizeInTokens(text: " ")
            self.session = newSession
        } catch {
            // Fallback: retry with minimal configuration for Gemma 3n compatibility
            let fallbackOptions = LlmInference.Session.Options()
            fallbackOptions.temperature = temperature
            fallbackOptions.randomSeed = randomSeed
            fallbackOptions.topk = topk
            fallbackOptions.enableVisionModality = enableVisionModality

            if let topP = topP {
                fallbackOptions.topp = Float(topP)
            }
            if let loraPath = loraPath {
                fallbackOptions.loraPath = loraPath
            }
            self.session = try LlmInference.Session(llmInference: inference, options: fallbackOptions)
        }
    }

    func sizeInTokens(prompt: String) throws -> Int {
        return try session.sizeInTokens(text: prompt)
    }

    func addQueryChunk(prompt: String) throws {
        try session.addQueryChunk(inputText: prompt)
    }

    func addImage(image: CGImage) throws {
        try session.addImage(image: image)
    }

    func addAudio(audioData: Data) throws {
        guard supportsAudio else {
            throw NSError(domain: "InferenceSession", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio modality is not enabled for this session"])
        }
        
        // TODO: Implement audio preprocessing and USM encoding
        // This is a placeholder for the audio processing pipeline
        
        do {
            // Step 1: Validate audio format and convert to 16kHz mono float32
            let processedAudio = try preprocessAudio(audioData)
            
            // Step 2: Convert audio to USM tokens (placeholder)
            // In actual implementation, this would use MediaPipe's USM encoder
            // let audioTokens = try encodeAudioToTokens(processedAudio)
            
            // Step 3: Add audio tokens to session (placeholder)
            // try session.addAudio(audioTokens) // This method doesn't exist yet in MediaPipe
            
            // For now, we'll throw an exception indicating this is not yet implemented
            throw NSError(domain: "InferenceSession", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Audio input is not yet implemented in MediaPipe Tasks. This requires MediaPipe to support audio input for LLM inference."
            ])
            
        } catch {
            throw NSError(domain: "InferenceSession", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Failed to process audio input: \(error.localizedDescription)"
            ])
        }
    }
    
    private func preprocessAudio(_ audioData: Data) throws -> [Float] {
        // TODO: Implement audio preprocessing pipeline
        // 1. Decode audio format (MP3, WAV, etc.) to raw samples
        // 2. Resample to 16kHz if needed
        // 3. Convert to mono if stereo
        // 4. Convert to float32 in range [-1, 1]
        // 5. Validate audio length (max 30 seconds)
        
        // Placeholder implementation
        return []
    }

    // Clone session (GPU models only)
    func clone() throws -> InferenceSession {
        let clonedSession = try session.clone()
        return InferenceSession(wrapping: clonedSession, supportsAudio: supportsAudio)
    }

    // Private initializer for wrapping existing session (used by clone)
    private init(wrapping session: LlmInference.Session, supportsAudio: Bool = false) {
        self.session = session
        self.supportsAudio = supportsAudio
    }

    func generateResponse(prompt: String? = nil) throws -> String {
        if let prompt = prompt {
            try session.addQueryChunk(inputText: prompt)
        }
        return try session.generateResponse()
    }

    @available(iOS 13.0.0, *)
    func generateResponseAsync(prompt: String? = nil) throws -> AsyncThrowingStream<String, any Error> {
        if let prompt = prompt {
            try session.addQueryChunk(inputText: prompt)
        }
        return session.generateResponseAsync()
    }

    // Access to session metrics
    var metrics: LlmInference.Session.Metrics {
        return session.metrics
    }
}