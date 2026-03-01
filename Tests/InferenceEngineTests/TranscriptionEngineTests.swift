import Testing
import Foundation
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

// MARK: - ModelManager (uses temp directory)

@Suite("ModelManager")
struct ModelManagerTests {
    private func makeTempManager() throws -> (ModelManager, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TranscriboTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return (ModelManager(modelDirectory: tempDir), tempDir)
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    @Test("Default directory is in Application Support")
    func defaultDirectory() {
        let path = ModelManager.defaultModelDirectory.path
        #expect(path.contains("Application Support/Transcribo/models"))
    }

    @Test("Custom directory is used when injected")
    func customDirectory() throws {
        let (manager, dir) = try makeTempManager()
        defer { cleanup(dir) }
        #expect(manager.modelDirectory == dir)
    }

    @Test("Model not available on empty directory")
    func modelNotAvailableOnEmpty() throws {
        let (manager, dir) = try makeTempManager()
        defer { cleanup(dir) }
        #expect(!manager.isModelAvailable)
    }

    @Test("Model available after placing file")
    func modelAvailableAfterPlacing() throws {
        let (manager, dir) = try makeTempManager()
        defer { cleanup(dir) }

        let modelPath = dir.appendingPathComponent("voxtral.mlx")
        try Data("fake-model".utf8).write(to: modelPath)

        #expect(manager.isModelAvailable)
    }

    @Test("deleteModel removes the model file")
    func deleteRemovesFile() throws {
        let (manager, dir) = try makeTempManager()
        defer { cleanup(dir) }

        let modelPath = dir.appendingPathComponent("voxtral.mlx")
        try Data("fake-model".utf8).write(to: modelPath)
        #expect(manager.isModelAvailable)

        try manager.deleteModel()
        #expect(!manager.isModelAvailable)
    }

    @Test("deleteModel does not throw when no model exists")
    func deleteNonexistent() throws {
        let (manager, dir) = try makeTempManager()
        defer { cleanup(dir) }
        try manager.deleteModel()
    }

    @Test("Availability toggles with create and delete")
    func availabilityToggle() throws {
        let (manager, dir) = try makeTempManager()
        defer { cleanup(dir) }

        #expect(!manager.isModelAvailable)

        let modelPath = dir.appendingPathComponent("voxtral.mlx")
        try Data("data".utf8).write(to: modelPath)
        #expect(manager.isModelAvailable)

        try manager.deleteModel()
        #expect(!manager.isModelAvailable)
    }
}

// MARK: - ModelError

@Suite("ModelError")
struct ModelErrorTests {
    @Test("All error cases have non-empty descriptions")
    func errorDescriptions() {
        let cases: [ModelError] = [.invalidURL, .downloadFailed, .checksumMismatch, .modelNotFound]
        for error in cases {
            let description = error.errorDescription
            #expect(description != nil)
            #expect(!(description ?? "").isEmpty)
        }
    }

    @Test("Each error has a unique description")
    func uniqueDescriptions() {
        let descriptions = [
            ModelError.invalidURL.errorDescription,
            ModelError.downloadFailed.errorDescription,
            ModelError.checksumMismatch.errorDescription,
            ModelError.modelNotFound.errorDescription,
        ]
        let unique = Set(descriptions.compactMap { $0 })
        #expect(unique.count == 4)
    }
}

// MARK: - TranscriptionEngine

@Suite("TranscriptionEngine")
struct TranscriptionEngineTests {
    private func makeEngine() throws -> (TranscriptionEngine, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TranscriboTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let manager = ModelManager(modelDirectory: tempDir)
        return (TranscriptionEngine(modelManager: manager), tempDir)
    }

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

    @Test("loadModel throws when model not downloaded")
    func loadModelWithoutDownload() throws {
        let (engine, dir) = try makeEngine()
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(throws: ModelError.self) {
            try engine.loadModel()
        }
    }

    @Test("loadModel succeeds when model file exists")
    func loadModelWithFile() throws {
        let (engine, dir) = try makeEngine()
        defer { try? FileManager.default.removeItem(at: dir) }

        try Data("fake".utf8).write(to: dir.appendingPathComponent("voxtral.mlx"))
        try engine.loadModel()
        #expect(engine.isLoaded)
    }

    @Test("unloadModel sets isLoaded to false")
    func unloadModel() throws {
        let (engine, dir) = try makeEngine()
        defer { try? FileManager.default.removeItem(at: dir) }

        try Data("fake".utf8).write(to: dir.appendingPathComponent("voxtral.mlx"))
        try engine.loadModel()
        #expect(engine.isLoaded)

        engine.unloadModel()
        #expect(!engine.isLoaded)
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

    @Test("setLanguage does not crash")
    func setLanguage() {
        let engine = TranscriptionEngine()
        engine.setLanguage("ja")
        engine.setLanguage("en")
    }

    @Test("isLoaded is false on init")
    func notLoadedOnInit() {
        let engine = TranscriptionEngine()
        #expect(!engine.isLoaded)
    }
}
