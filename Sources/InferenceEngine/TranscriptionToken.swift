import Foundation

/// A single token emitted by the transcription engine.
public struct TranscriptionToken: Sendable {
    /// The transcribed text fragment.
    public let text: String

    /// Whether this token represents a finalized (non-revisable) result.
    public let isFinal: Bool

    /// Confidence score from 0.0 to 1.0, if available.
    public let confidence: Double?

    /// Timestamp relative to the start of the recording session.
    public let timestamp: TimeInterval

    public init(text: String, isFinal: Bool, confidence: Double? = nil, timestamp: TimeInterval) {
        self.text = text
        self.isFinal = isFinal
        self.confidence = confidence
        self.timestamp = timestamp
    }
}
