import Testing
import AVFoundation
@testable import AudioCapture

@Suite("AudioCaptureSession")
struct AudioCaptureSessionTests {

    // MARK: - Inference format

    @Test("Inference format has 16kHz sample rate")
    func inferenceFormatSampleRate() {
        #expect(AudioCaptureSession.inferenceFormat.sampleRate == 16000)
    }

    @Test("Inference format is mono")
    func inferenceFormatMono() {
        #expect(AudioCaptureSession.inferenceFormat.channelCount == 1)
    }

    @Test("Inference format is Float32")
    func inferenceFormatFloat32() {
        #expect(AudioCaptureSession.inferenceFormat.commonFormat == .pcmFormatFloat32)
    }

    @Test("Inference format is non-interleaved")
    func inferenceFormatNonInterleaved() {
        #expect(!AudioCaptureSession.inferenceFormat.isInterleaved)
    }

    @Test("Can create a PCM buffer from inference format")
    func bufferFromInferenceFormat() {
        let buffer = AVAudioPCMBuffer(
            pcmFormat: AudioCaptureSession.inferenceFormat,
            frameCapacity: 4096
        )
        #expect(buffer != nil)
        #expect(buffer?.frameCapacity == 4096)
    }

    // MARK: - Session lifecycle

    @Test("Session initializes without error")
    func initialization() {
        let session = AudioCaptureSession()
        _ = session
    }

    @Test("Stop is safe when not capturing")
    func stopWithoutStart() {
        let session = AudioCaptureSession()
        // Calling stop() before start() should be a no-op, not a crash
        session.stop()
    }

    @Test("Double stop is safe")
    func doubleStop() {
        let session = AudioCaptureSession()
        session.stop()
        session.stop()
    }

    @Test("Multiple sessions can be created independently")
    func multipleSessions() {
        let session1 = AudioCaptureSession()
        let session2 = AudioCaptureSession()
        _ = (session1, session2)
    }
}
