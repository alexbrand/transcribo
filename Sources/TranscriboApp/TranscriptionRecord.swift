import Foundation
import SwiftData

/// A persisted record of a completed transcription session.
@Model
final class TranscriptionRecord {
    var timestamp: Date
    var text: String
    var sourceAppName: String
    var language: String
    var durationSeconds: Double

    init(timestamp: Date, text: String, sourceAppName: String, language: String, durationSeconds: Double) {
        self.timestamp = timestamp
        self.text = text
        self.sourceAppName = sourceAppName
        self.language = language
        self.durationSeconds = durationSeconds
    }
}
