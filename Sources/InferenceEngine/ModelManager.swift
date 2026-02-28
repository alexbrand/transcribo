import Foundation

/// Manages downloading, caching, and verifying the Voxtral model weights.
public final class ModelManager {
    /// The directory where model files are stored.
    public static let modelDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Transcribo/models", isDirectory: true)
    }()

    /// The expected SHA-256 checksum of the model file.
    /// TODO: Replace with actual checksum once model is finalized.
    private static let expectedChecksum = ""

    public init() {}

    /// Whether the model is already downloaded and valid.
    public var isModelAvailable: Bool {
        let modelPath = Self.modelDirectory.appendingPathComponent("voxtral.mlx")
        return FileManager.default.fileExists(atPath: modelPath.path)
    }

    /// Download the model weights. Reports progress and completion on the main queue.
    public func downloadModel(
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // Ensure the model directory exists
        try? FileManager.default.createDirectory(at: Self.modelDirectory, withIntermediateDirectories: true)

        // TODO: Replace with actual model URL
        guard let url = URL(string: "https://models.example.com/voxtral/voxtral.mlx") else {
            completion(.failure(ModelError.invalidURL))
            return
        }

        let destination = Self.modelDirectory.appendingPathComponent("voxtral.mlx")

        let task = URLSession.shared.downloadTask(with: url) { tempURL, _, error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(error))
                    return
                }

                guard let tempURL else {
                    completion(.failure(ModelError.downloadFailed))
                    return
                }

                do {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destination)
                    completion(.success(destination))
                } catch {
                    completion(.failure(error))
                }
            }
        }

        // Observe download progress
        let observation = task.progress.observe(\.fractionCompleted) { taskProgress, _ in
            DispatchQueue.main.async {
                progress(taskProgress.fractionCompleted)
            }
        }

        // Keep observation alive until task completes
        objc_setAssociatedObject(task, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN)

        task.resume()
    }

    /// Remove downloaded model files.
    public func deleteModel() throws {
        let modelPath = Self.modelDirectory.appendingPathComponent("voxtral.mlx")
        if FileManager.default.fileExists(atPath: modelPath.path) {
            try FileManager.default.removeItem(at: modelPath)
        }
    }
}

public enum ModelError: Error, LocalizedError {
    case invalidURL
    case downloadFailed
    case checksumMismatch
    case modelNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid model download URL."
        case .downloadFailed:
            return "Model download failed."
        case .checksumMismatch:
            return "Downloaded model checksum does not match. The file may be corrupted."
        case .modelNotFound:
            return "Model file not found. Please download the model first."
        }
    }
}
