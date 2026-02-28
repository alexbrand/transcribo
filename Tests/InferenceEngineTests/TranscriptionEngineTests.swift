import Testing
import Foundation
@testable import InferenceEngine

@Suite("TranscriptionEngine")
struct TranscriptionEngineTests {
    @Test("Engine initializes with default language")
    func defaultLanguage() {
        let engine = TranscriptionEngine()
        _ = engine
    }

    @Test("Engine initializes with custom language")
    func customLanguage() {
        let engine = TranscriptionEngine(language: "fr")
        _ = engine
    }

    @Test("Supported languages list is not empty")
    func supportedLanguages() {
        #expect(!TranscriptionEngine.supportedLanguages.isEmpty)
    }

    @Test("loadModel throws when model not downloaded")
    func loadModelWithoutDownload() {
        let engine = TranscriptionEngine()
        #expect(throws: ModelError.self) {
            try engine.loadModel()
        }
    }
}

@Suite("TranscriptionToken")
struct TranscriptionTokenTests {
    @Test("Token stores text and metadata")
    func tokenCreation() {
        let token = TranscriptionToken(text: "hello", isFinal: false, confidence: 0.95, timestamp: 1.5)
        #expect(token.text == "hello")
        #expect(token.isFinal == false)
        #expect(token.confidence == 0.95)
        #expect(token.timestamp == 1.5)
    }

    @Test("Token works without confidence")
    func tokenWithoutConfidence() {
        let token = TranscriptionToken(text: "world", isFinal: true, timestamp: 2.0)
        #expect(token.confidence == nil)
    }
}

@Suite("ModelManager")
struct ModelManagerTests {
    @Test("Model directory is in Application Support")
    func modelDirectory() {
        let path = ModelManager.modelDirectory.path
        #expect(path.contains("Application Support/Transcribo/models"))
    }

    @Test("Model is not available on fresh state")
    func modelNotAvailable() {
        let manager = ModelManager()
        #expect(!manager.isModelAvailable)
    }
}
