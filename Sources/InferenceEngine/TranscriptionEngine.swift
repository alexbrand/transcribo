import AVFoundation
import Foundation

/// Runs the Voxtral model locally and produces streaming transcription tokens from audio buffers.
///
/// The specific inference runtime (MLX, llama.cpp, or custom) is TBD.
/// This class provides the public API that the rest of the app depends on;
/// the runtime implementation will be swapped in behind this interface.
public final class TranscriptionEngine {
    private let modelManager = ModelManager()
    private var isLoaded = false
    private var sessionStartTime: Date?
    private var language: String

    /// Callback invoked on the main queue with each transcription token.
    public var onToken: ((TranscriptionToken) -> Void)?

    /// Languages supported by the model.
    public static let supportedLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("zh", "Chinese"),
    ]

    public init(language: String = "en") {
        self.language = language
    }

    /// Load the model into GPU memory. Call once at app launch.
    public func loadModel() throws {
        guard modelManager.isModelAvailable else {
            throw ModelError.modelNotFound
        }

        // TODO: Initialize the inference runtime and load model weights into Metal GPU memory.
        // This is where we'll plug in MLX-Swift or llama.cpp.
        isLoaded = true
    }

    /// Unload the model from GPU memory. Call at app termination.
    public func unloadModel() {
        // TODO: Release Metal resources and model weights.
        isLoaded = false
    }

    /// Set the active transcription language.
    public func setLanguage(_ code: String) {
        language = code
    }

    /// Process a single audio buffer. Call this repeatedly as buffers arrive from AudioCaptureSession.
    public func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        if sessionStartTime == nil {
            sessionStartTime = Date()
        }

        // TODO: Feed the buffer to the inference runtime.
        // On partial results, emit tokens via onToken callback:
        //
        // let token = TranscriptionToken(
        //     text: partialText,
        //     isFinal: false,
        //     confidence: score,
        //     timestamp: Date().timeIntervalSince(sessionStartTime!)
        // )
        // DispatchQueue.main.async { self.onToken?(token) }
    }

    /// Signal that audio capture has stopped. Flushes any remaining audio and emits a final token.
    public func finalize() {
        guard let start = sessionStartTime else { return }

        // TODO: Flush the inference runtime's internal buffer and emit the final token.
        let finalToken = TranscriptionToken(
            text: "",
            isFinal: true,
            timestamp: Date().timeIntervalSince(start)
        )
        DispatchQueue.main.async { self.onToken?(finalToken) }

        sessionStartTime = nil
    }
}
