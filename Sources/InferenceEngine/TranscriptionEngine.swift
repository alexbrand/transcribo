import AVFoundation
import Foundation
import MLX
import MLXAudioSTT
import OSLog

/// Runs the Voxtral Realtime model locally and produces transcription tokens from audio buffers.
///
/// Audio buffers are accumulated during a push-to-talk session. When `finalize()` is called
/// (user releases the key), the accumulated audio is sent to the model for transcription
/// and the result is emitted via the `onToken` callback.
///
/// The model is injected externally via `setModel(_:)` — ModelManager owns the download/load lifecycle.
public final class TranscriptionEngine {
    private static let logger = Logger(subsystem: "Transcribo", category: "TranscriptionEngine")
    private var model: VoxtralRealtimeModel?
    private var sessionStartTime: Date?
    private var language: String

    /// Accumulated audio samples (16 kHz mono Float32) for the current session.
    private var audioBuffer: [Float] = []

    /// Callback invoked on the main queue with each transcription token.
    public var onToken: ((TranscriptionToken) -> Void)?

    /// Whether a model has been injected and is ready for inference.
    public var isLoaded: Bool { model != nil }

    /// Languages supported by the Voxtral Realtime model.
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

    /// Inject or replace the loaded model. Called by AppDelegate when ModelManager reaches `.ready`.
    public func setModel(_ model: VoxtralRealtimeModel?) {
        self.model = model
    }

    /// Set the active transcription language using an ISO 639-1 code (e.g. "en", "fr").
    public func setLanguage(_ code: String) {
        language = code
    }

    /// Process a single audio buffer. Call this repeatedly as buffers arrive from AudioCaptureSession.
    /// Buffers are accumulated and transcribed when `finalize()` is called.
    public func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        if sessionStartTime == nil {
            sessionStartTime = Date()
        }

        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        audioBuffer.append(contentsOf: samples)
    }

    /// Signal that audio capture has stopped. Runs inference on accumulated audio and emits
    /// the transcription as a final token.
    public func finalize() {
        guard let start = sessionStartTime else { return }
        guard let model = self.model, !audioBuffer.isEmpty else {
            Self.logger.error("Finalize skipped: modelLoaded=\(self.model != nil, privacy: .public), audioSamples=\(self.audioBuffer.count, privacy: .public)")
            sessionStartTime = nil
            audioBuffer.removeAll()
            return
        }

        let samples = audioBuffer
        let lang = language
        let elapsed = Date().timeIntervalSince(start)
        Self.logger.log("Running transcription with \(samples.count, privacy: .public) samples, language=\(lang, privacy: .public), elapsed=\(elapsed, privacy: .public)s")

        audioBuffer.removeAll()
        sessionStartTime = nil

        // Run inference on a background thread since generate() is synchronous and blocking.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            Self.logger.log("Entered transcription worker thread")
            let generationStart = Date()
            let device = ComputeDeviceResolver.preferredDevice()
            let output = Device.withDefaultDevice(device) {
                Self.logger.log("Calling model.generate on \(ComputeDeviceResolver.deviceName(device), privacy: .public)")
                let audio = MLXArray(samples)

                let params = STTGenerateParameters(
                    maxTokens: 256,
                    temperature: 0.0,
                    language: lang,
                    chunkDuration: 30.0,
                    minChunkDuration: 1.0
                )

                return model.generate(audio: audio, generationParameters: params)
            }
            let generationElapsed = Date().timeIntervalSince(generationStart)
            Self.logger.log("model.generate completed in \(generationElapsed, privacy: .public)s")

            let token = TranscriptionToken(
                text: output.text,
                isFinal: true,
                timestamp: elapsed
            )
            Self.logger.log("Transcription finished. textLength=\(token.text.count, privacy: .public)")

            DispatchQueue.main.async {
                self?.onToken?(token)
            }
        }
    }
}
