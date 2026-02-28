import Testing
import AVFoundation
@testable import AudioCapture

@Suite("AudioCaptureSession")
struct AudioCaptureSessionTests {
    @Test("Inference format is 16kHz mono Float32")
    func inferenceFormat() {
        let format = AudioCaptureSession.inferenceFormat
        #expect(format.sampleRate == 16000)
        #expect(format.channelCount == 1)
        #expect(format.commonFormat == .pcmFormatFloat32)
    }

    @Test("Session initializes without error")
    func initialization() {
        let session = AudioCaptureSession()
        _ = session // no crash
    }
}
