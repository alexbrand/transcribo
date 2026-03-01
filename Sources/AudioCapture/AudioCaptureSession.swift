import AVFoundation
import OSLog

/// Captures microphone audio in real time using AVAudioEngine.
/// Streams audio buffers converted to the format expected by the inference engine (16 kHz, mono, Float32).
public final class AudioCaptureSession {
    private static let logger = Logger(subsystem: "Transcribo", category: "AudioCapture")
    private let engine = AVAudioEngine()
    private var isCapturing = false
    private var hasLoggedConvertError = false

    /// The audio format used for inference: 16 kHz, mono, Float32.
    public static let inferenceFormat: AVAudioFormat = {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            fatalError("Failed to create inference audio format")
        }
        return format
    }()

    public init() {}

    /// Request microphone permission. Calls the completion handler with `true` if granted.
    public static func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// Start capturing audio from the default microphone.
    /// - Parameter bufferHandler: Called on an audio thread with each captured buffer in inference format.
    @discardableResult
    public func start(
        bufferHandler: @escaping (AVAudioPCMBuffer) -> Void,
        failureHandler: ((String) -> Void)? = nil
    ) -> Bool {
        guard !isCapturing else {
            return true
        }

        let permission = AVCaptureDevice.authorizationStatus(for: .audio)
        guard permission == .authorized else {
            let message: String
            switch permission {
            case .authorized:
                message = "Microphone permission check failed unexpectedly."
            case .denied, .restricted:
                message = "Microphone permission denied. Enable it in System Settings > Privacy & Security > Microphone."
            case .notDetermined:
                Self.logger.log("Microphone permission not determined; requesting access")
                Self.requestPermission { granted in
                    let followUp = granted
                        ? "Microphone permission granted. Press and hold the shortcut key again to start recording."
                        : "Microphone permission denied. Enable it in System Settings > Privacy & Security > Microphone."
                    Self.logger.log("\(followUp, privacy: .public)")
                    failureHandler?(followUp)
                }
                message = "Microphone access requested. Approve the macOS prompt, then press and hold the shortcut key again."
            @unknown default:
                message = "Microphone permission unavailable."
            }
            Self.logger.error("\(message, privacy: .public)")
            failureHandler?(message)
            return false
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else {
            let message = "No microphone input format available (sample rate is 0)."
            Self.logger.error("\(message, privacy: .public)")
            failureHandler?(message)
            return false
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: Self.inferenceFormat) else {
            let message = "Failed to create audio converter (\(inputFormat.sampleRate) Hz -> 16000 Hz)."
            Self.logger.error("\(message, privacy: .public)")
            failureHandler?(message)
            return false
        }

        let bufferSize: AVAudioFrameCount = 2048
        hasLoggedConvertError = false

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { buffer, _ in
            let outputCapacity = AVAudioFrameCount(
                max(
                    1,
                    Int(ceil(Double(buffer.frameLength) * Self.inferenceFormat.sampleRate / inputFormat.sampleRate))
                )
            )
            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: Self.inferenceFormat,
                frameCapacity: outputCapacity
            ) else { return }

            var error: NSError?
            var consumedInput = false
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                guard !consumedInput else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                consumedInput = true
                outStatus.pointee = .haveData
                return buffer
            }

            if status == .haveData, error == nil {
                bufferHandler(convertedBuffer)
            } else if let error, !self.hasLoggedConvertError {
                self.hasLoggedConvertError = true
                Self.logger.error("Audio conversion failed once: \(error.localizedDescription, privacy: .public) [\(error.domain, privacy: .public):\(error.code)]")
            }
        }

        do {
            if engine.isRunning {
                engine.stop()
            }
            try engine.start()
            isCapturing = true
            Self.logger.log("Audio capture started (\(inputFormat.sampleRate, privacy: .public) Hz, \(inputFormat.channelCount, privacy: .public) ch)")
            return true
        } catch {
            inputNode.removeTap(onBus: 0)
            let nsError = error as NSError
            let message = "Audio engine start failed: \(nsError.localizedDescription) [\(nsError.domain):\(nsError.code)]"
            Self.logger.error("\(message, privacy: .public)")
            failureHandler?(message)
            return false
        }
    }

    /// Stop capturing audio.
    public func stop() {
        guard isCapturing else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        engine.reset()
        isCapturing = false
        Self.logger.log("Audio capture stopped")
    }
}
