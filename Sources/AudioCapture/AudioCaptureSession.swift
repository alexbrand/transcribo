import AVFoundation

/// Captures microphone audio in real time using AVAudioEngine.
/// Streams audio buffers converted to the format expected by the inference engine (16 kHz, mono, Float32).
public final class AudioCaptureSession {
    private let engine = AVAudioEngine()
    private var isCapturing = false

    /// The audio format used for inference: 16 kHz, mono, Float32.
    public static let inferenceFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

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
    public func start(bufferHandler: @escaping (AVAudioPCMBuffer) -> Void) {
        guard !isCapturing else { return }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let converter = AVAudioConverter(from: inputFormat, to: Self.inferenceFormat) else {
            return
        }

        let bufferSize: AVAudioFrameCount = 4096

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { buffer, _ in
            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: Self.inferenceFormat,
                frameCapacity: bufferSize
            ) else { return }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if status == .haveData, error == nil {
                bufferHandler(convertedBuffer)
            }
        }

        do {
            try engine.start()
            isCapturing = true
        } catch {
            inputNode.removeTap(onBus: 0)
        }
    }

    /// Stop capturing audio.
    public func stop() {
        guard isCapturing else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isCapturing = false
    }
}
