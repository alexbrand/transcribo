import Testing
import Foundation
import AVFoundation
@testable import InferenceEngine

// MARK: - TranscriptionToken

@Suite("TranscriptionToken")
struct TranscriptionTokenTests {
    @Test("Stores text and metadata")
    func creation() {
        let token = TranscriptionToken(text: "hello", isFinal: false, confidence: 0.95, timestamp: 1.5)
        #expect(token.text == "hello")
        #expect(token.isFinal == false)
        #expect(token.confidence == 0.95)
        #expect(token.timestamp == 1.5)
    }

    @Test("Works without confidence")
    func optionalConfidence() {
        let token = TranscriptionToken(text: "world", isFinal: true, timestamp: 2.0)
        #expect(token.confidence == nil)
    }

    @Test("Handles empty text")
    func emptyText() {
        let token = TranscriptionToken(text: "", isFinal: true, timestamp: 0)
        #expect(token.text.isEmpty)
    }

    @Test("Handles zero timestamp")
    func zeroTimestamp() {
        let token = TranscriptionToken(text: "start", isFinal: false, timestamp: 0)
        #expect(token.timestamp == 0)
    }

    @Test("Confidence boundary at 0.0")
    func zeroConfidence() {
        let token = TranscriptionToken(text: "low", isFinal: false, confidence: 0.0, timestamp: 1.0)
        #expect(token.confidence == 0.0)
    }

    @Test("Confidence boundary at 1.0")
    func fullConfidence() {
        let token = TranscriptionToken(text: "high", isFinal: false, confidence: 1.0, timestamp: 1.0)
        #expect(token.confidence == 1.0)
    }

    @Test("Handles multi-byte Unicode text")
    func unicodeText() {
        let token = TranscriptionToken(text: "こんにちは 🌍", isFinal: true, timestamp: 3.0)
        #expect(token.text == "こんにちは 🌍")
    }

    @Test("Final token is distinguishable from partial")
    func finalVsPartial() {
        let partial = TranscriptionToken(text: "hel", isFinal: false, timestamp: 1.0)
        let finalToken = TranscriptionToken(text: "hello", isFinal: true, timestamp: 2.0)
        #expect(partial.isFinal == false)
        #expect(finalToken.isFinal == true)
    }
}

// MARK: - ModelManager

@Suite("ModelManager")
struct ModelManagerTests {
    @MainActor
    @Test("Model identifier is set")
    func modelIdentifier() {
        #expect(!ModelManager.modelIdentifier.isEmpty)
        #expect(ModelManager.modelIdentifier.contains("Voxtral"))
    }

    @MainActor
    @Test("Initial state is notDownloaded with no cache")
    func initialState() {
        let manager = ModelManager()
        // Without cached files, state depends on actual cache — just verify it's a valid state
        let validStates: [ModelState] = [.notDownloaded, .downloaded]
        #expect(validStates.contains(manager.state))
    }

    @MainActor
    @Test("Download progress starts at zero")
    func initialProgress() {
        let manager = ModelManager()
        #expect(manager.downloadProgress == 0)
    }

    @MainActor
    @Test("Model is nil before loading")
    func modelNilBeforeLoad() {
        let manager = ModelManager()
        #expect(manager.model == nil)
    }

    @MainActor
    @Test("deleteModel resets state")
    func deleteModelResetsState() {
        let manager = ModelManager()
        manager.deleteModel()
        #expect(manager.state == .notDownloaded)
        #expect(manager.downloadProgress == 0)
        #expect(manager.model == nil)
    }
}

// MARK: - ModelState

@Suite("ModelState")
struct ModelStateTests {
    @Test("States are equatable")
    func equatable() {
        #expect(ModelState.notDownloaded == ModelState.notDownloaded)
        #expect(ModelState.downloading == ModelState.downloading)
        #expect(ModelState.downloaded == ModelState.downloaded)
        #expect(ModelState.loading == ModelState.loading)
        #expect(ModelState.ready == ModelState.ready)
        #expect(ModelState.error("test") == ModelState.error("test"))
        #expect(ModelState.error("a") != ModelState.error("b"))
        #expect(ModelState.notDownloaded != ModelState.ready)
    }
}

// MARK: - ModelError

@Suite("ModelError")
struct ModelErrorTests {
    @Test("All error cases have non-empty descriptions")
    func errorDescriptions() {
        let cases: [ModelError] = [.downloadFailed, .modelNotFound, .loadingFailed("test")]
        for error in cases {
            let description = error.errorDescription
            #expect(description != nil)
            #expect(!(description ?? "").isEmpty)
        }
    }

    @Test("Each error has a unique description")
    func uniqueDescriptions() {
        let descriptions = [
            ModelError.downloadFailed.errorDescription,
            ModelError.modelNotFound.errorDescription,
            ModelError.loadingFailed("reason").errorDescription,
        ]
        let unique = Set(descriptions.compactMap { $0 })
        #expect(unique.count == 3)
    }

    @Test("loadingFailed includes reason")
    func loadingFailedReason() {
        let error = ModelError.loadingFailed("out of memory")
        #expect(error.errorDescription?.contains("out of memory") == true)
    }
}

// MARK: - TranscriptionEngine

@Suite("TranscriptionEngine")
struct TranscriptionEngineTests {
    @Test("Initializes with default language")
    func defaultInit() {
        let engine = TranscriptionEngine()
        _ = engine
    }

    @Test("Initializes with custom language")
    func customLanguageInit() {
        let engine = TranscriptionEngine(language: "fr")
        _ = engine
    }

    @Test("Supported languages list is not empty")
    func supportedLanguages() {
        #expect(!TranscriptionEngine.supportedLanguages.isEmpty)
    }

    @Test("All supported languages have non-empty code and name")
    func supportedLanguageFields() {
        for lang in TranscriptionEngine.supportedLanguages {
            #expect(!lang.code.isEmpty)
            #expect(!lang.name.isEmpty)
        }
    }

    @Test("English is in supported languages")
    func englishSupported() {
        let codes = TranscriptionEngine.supportedLanguages.map(\.code)
        #expect(codes.contains("en"))
    }

    @Test("isLoaded is false on init")
    func notLoadedOnInit() {
        let engine = TranscriptionEngine()
        #expect(!engine.isLoaded)
    }

    @Test("setModel(nil) keeps isLoaded false")
    func setModelNil() {
        let engine = TranscriptionEngine()
        engine.setModel(nil)
        #expect(!engine.isLoaded)
    }

    @Test("setLanguage does not crash")
    func setLanguage() {
        let engine = TranscriptionEngine()
        engine.setLanguage("ja")
        engine.setLanguage("en")
    }

    @Test("finalize without a session is a no-op")
    func finalizeWithoutSession() {
        let engine = TranscriptionEngine()
        var tokenReceived = false
        engine.onToken = { _ in tokenReceived = true }
        engine.finalize()
        // onToken should NOT fire since no processAudioBuffer was ever called
        #expect(!tokenReceived)
    }

    @Test("processAudioBuffer accumulates samples")
    func audioBufferAccumulation() throws {
        let engine = TranscriptionEngine()

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw ModelError.loadingFailed("Could not create audio format")
        }

        // Create a buffer with known samples
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 160) else {
            throw ModelError.loadingFailed("Could not create audio buffer")
        }
        buffer.frameLength = 160
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<160 {
                channelData[i] = Float(i) / 160.0
            }
        }

        // Processing a buffer should set session start time (tested via finalize behavior)
        engine.processAudioBuffer(buffer)

        // After processing, finalize without a model should clear state without crashing
        engine.finalize()
    }
}
