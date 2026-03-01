import Foundation
import HuggingFace
import MLX
import MLXAudioSTT
import OSLog

/// Tracks the lifecycle of the Voxtral model: download, load, and readiness.
public enum ModelState: Equatable {
    case notDownloaded
    case downloading
    case downloaded
    case loading
    case ready
    case error(String)
}

/// Manages downloading, caching, and loading the Voxtral Realtime model.
///
/// Designed as `@Observable @MainActor` so SwiftUI views can react to state changes directly.
@Observable
@MainActor
public final class ModelManager {
    /// HuggingFace repository for the 4-bit quantized Voxtral model (~3.1 GB).
    public static let modelIdentifier = "mlx-community/Voxtral-Mini-4B-Realtime-2602-4bit"

    private static let repoID: Repo.ID = "mlx-community/Voxtral-Mini-4B-Realtime-2602-4bit"

    private static let allowedExtensions = ["*.safetensors", "*.json", "*.txt", "*.wav"]
    private static let expectedModelSizeBytes: Double = 3_100_000_000
    private static let logger = Logger(subsystem: "Transcribo", category: "ModelManager")

    /// Current state of the model lifecycle.
    public private(set) var state: ModelState = .notDownloaded

    /// Download progress from 0.0 to 1.0.
    public private(set) var downloadProgress: Double = 0
    public private(set) var downloadStatus: String = "Idle"

    /// The loaded model, read by TranscriptionEngine when state is `.ready`.
    public private(set) var model: VoxtralRealtimeModel?

    /// HuggingFace cache used for downloads.
    private let cache: HubCache
    private var lastLoggedPercent = -1
    private var lastLoggedCompletedBytes: Int64 = 0
    private var hasLoggedMetalLibraryChecks = false

    /// Computed path where model files are stored (matches ModelUtils convention).
    public var modelDirectory: URL {
        let modelSubdir = Self.repoID.description.replacingOccurrences(of: "/", with: "_")
        return cache.cacheDirectory
            .appendingPathComponent("mlx-audio")
            .appendingPathComponent(modelSubdir)
    }

    public init(cache: HubCache = .default) {
        self.cache = cache
        checkCachedModel()
    }

    public static var diagnosticsLogPath: String {
        diagnosticsLogURL.path
    }

    /// Check whether model files already exist in cache.
    public func checkCachedModel() {
        let dir = modelDirectory
        guard FileManager.default.fileExists(atPath: dir.path) else {
            state = .notDownloaded
            downloadStatus = "Model not downloaded"
            return
        }

        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []

        let hasSafetensors = files.contains { file in
            guard file.pathExtension == "safetensors" else { return false }
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return size > 0
        }

        let hasConfig = FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("config.json").path
        )

        if hasSafetensors && hasConfig {
            state = .downloaded
            downloadStatus = "Model is downloaded"
        } else {
            state = .notDownloaded
            downloadStatus = "Model not downloaded"
        }
    }

    /// Download the model from HuggingFace Hub.
    ///
    /// Token resolution:
    /// 1. `UserDefaults("hfToken")` — user-provided from Settings
    /// 2. Falls back to HubClient default which checks `HF_TOKEN` env var and `~/.cache/huggingface/token`
    public func downloadModel() async {
        guard state == .notDownloaded || isError else {
            log("Ignoring download request because state is \(String(describing: state))")
            return
        }

        state = .downloading
        downloadProgress = 0
        downloadStatus = "Preparing download..."
        lastLoggedPercent = -1
        lastLoggedCompletedBytes = 0
        log("Starting model download for \(Self.repoID.description)")
        log("Destination directory: \(modelDirectory.path)")
        log("Using custom HF token: \(hasCustomToken)")

        do {
            let client = makeHubClient()

            try FileManager.default.createDirectory(
                at: modelDirectory, withIntermediateDirectories: true
            )

            _ = try await client.downloadSnapshot(
                of: Self.repoID,
                kind: .model,
                to: modelDirectory,
                revision: "main",
                matching: Self.allowedExtensions,
                progressHandler: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.handleDownloadProgress(progress)
                    }
                }
            )

            state = .downloaded
            downloadProgress = 1
            downloadStatus = "Download complete"
            log("Download finished. Cached bytes: \(humanBytes(directorySizeBytes(at: modelDirectory)))")
        } catch {
            let nsError = error as NSError
            state = .error("Download failed: \(nsError.localizedDescription)")
            downloadStatus = "Download failed"
            log("Download failed [\(nsError.domain):\(nsError.code)] \(nsError.localizedDescription)")
        }
    }

    /// Load the model from downloaded files into memory.
    public func loadModel() async {
        guard state == .downloaded else {
            log("Ignoring load request because state is \(String(describing: state))")
            return
        }

        state = .loading
        downloadStatus = "Loading model into memory..."
        log("Loading model from \(modelDirectory.path)")
        logMetalLibraryChecksIfNeeded()

        do {
            let dir = modelDirectory
            let device = ComputeDeviceResolver.preferredDevice()
            log("Using MLX device for model load: \(ComputeDeviceResolver.deviceName(device))")
            // VoxtralRealtimeModel is not Sendable but is safe to transfer across isolation
            // boundaries since we create it on the detached task and only use it on MainActor after.
            nonisolated(unsafe) let loaded = try await Task.detached {
                try Device.withDefaultDevice(device) {
                    try VoxtralRealtimeModel.fromDirectory(dir)
                }
            }.value

            model = loaded
            state = .ready
            downloadStatus = "Model ready"
            log("Model loaded successfully")
        } catch {
            let userMessage = userFacingErrorMessage(for: error, context: "load")
            state = .error(userMessage)
            downloadStatus = "Loading failed"
            log("Loading failed: \(error)")
        }
    }

    /// Remove cached model files and reset state.
    public func deleteModel() {
        model = nil
        try? FileManager.default.removeItem(at: modelDirectory)
        state = .notDownloaded
        downloadProgress = 0
        downloadStatus = "Model not downloaded"
        log("Model cache deleted at \(modelDirectory.path)")
    }

    /// Convenience: download (if needed) then load.
    public func downloadAndLoad() async {
        if state == .notDownloaded || isError {
            await downloadModel()
        }
        if state == .downloaded {
            await loadModel()
        }
    }

    // MARK: - Private

    private var isError: Bool {
        if case .error = state { return true }
        return false
    }

    private func makeHubClient() -> HubClient {
        if let token = UserDefaults.standard.string(forKey: "hfToken"), !token.isEmpty {
            return HubClient(host: HubClient.defaultHost, bearerToken: token, cache: cache)
        }
        return HubClient(cache: cache)
    }

    private var hasCustomToken: Bool {
        guard let token = UserDefaults.standard.string(forKey: "hfToken") else {
            return false
        }
        return !token.isEmpty
    }

    private func handleDownloadProgress(_ progress: Progress) {
        let completed = max(progress.completedUnitCount, 0)
        let total = progress.totalUnitCount

        if total > 0 {
            let fraction = min(max(Double(completed) / Double(total), 0), 1)
            downloadProgress = fraction
            let percent = Int((fraction * 100).rounded(.down))
            downloadStatus = "Downloading \(percent)% (\(humanBytes(completed))/\(humanBytes(total)))"

            if percent >= lastLoggedPercent + 5 || percent == 100 {
                lastLoggedPercent = percent
                log("Download progress: \(percent)% (\(humanBytes(completed))/\(humanBytes(total)))")
            }
            return
        }

        if completed > 0 {
            let estimated = min(Double(completed) / Self.expectedModelSizeBytes, 0.99)
            downloadProgress = max(downloadProgress, estimated)
            downloadStatus = "Downloading \(humanBytes(completed)) (total size pending...)"

            if completed - lastLoggedCompletedBytes >= 50_000_000 {
                lastLoggedCompletedBytes = completed
                log("Download progress: \(humanBytes(completed)) received (server has not reported total size yet)")
            }
        } else {
            downloadStatus = "Contacting HuggingFace..."
        }
    }

    private func userFacingErrorMessage(for error: Error, context: String) -> String {
        let nsError = error as NSError
        let rawDescription = nsError.localizedDescription
        let rawDebug = String(describing: error)
        let combined = "\(rawDescription)\n\(rawDebug)".lowercased()

        if combined.contains("default metallib")
            || combined.contains("mlx.metallib")
            || combined.contains("failed to load the default metallib")
            || combined.contains("library not found")
        {
            let message = """
            MLX Metal shaders are missing (`default.metallib`). Build/run with Xcode so `mlx-swift_Cmlx.bundle` is available; `swift run` alone does not produce these shaders.
            """
            log("Mapped MLX metallib error during \(context): \(rawDescription)")
            return message
        }

        return "\(context.capitalized) failed: \(rawDescription)"
    }

    private func logMetalLibraryChecksIfNeeded() {
        guard !hasLoggedMetalLibraryChecks else { return }
        hasLoggedMetalLibraryChecks = true

        for candidate in metalLibraryCandidates() {
            let exists = FileManager.default.fileExists(atPath: candidate.path)
            log("Metal shader candidate \(exists ? "FOUND" : "missing"): \(candidate.path)")
        }
    }

    private func metalLibraryCandidates() -> [URL] {
        ComputeDeviceResolver.metalLibraryCandidates()
    }

    private func log(_ message: String) {
        Self.logger.log("\(message, privacy: .public)")

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        let url = Self.diagnosticsLogURL

        do {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            if !FileManager.default.fileExists(atPath: url.path) {
                try Data().write(to: url)
            }

            guard let data = line.data(using: .utf8),
                  let fileHandle = try? FileHandle(forWritingTo: url) else {
                return
            }
            defer { try? fileHandle.close() }

            try fileHandle.seekToEnd()
            try fileHandle.write(contentsOf: data)
        } catch {
            Self.logger.error("Failed to write diagnostics log: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static var diagnosticsLogURL: URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return library
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Transcribo", isDirectory: true)
            .appendingPathComponent("model-manager.log", isDirectory: false)
    }

    private func directorySizeBytes(at root: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values?.isRegularFile == true, let size = values?.fileSize else {
                continue
            }
            total += Int64(size)
        }
        return total
    }

    private func humanBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

public enum ModelError: Error, LocalizedError {
    case downloadFailed
    case modelNotFound
    case loadingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .downloadFailed:
            return "Model download failed."
        case .modelNotFound:
            return "Model file not found. Please download the model first."
        case .loadingFailed(let reason):
            return "Failed to load model: \(reason)"
        }
    }
}
