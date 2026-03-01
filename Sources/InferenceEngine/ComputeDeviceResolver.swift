import Foundation
import MLX

enum ComputeDeviceResolver {
    static func preferredDevice() -> Device {
        hasMetalLibrary() ? .gpu : .cpu
    }

    static func deviceName(_ device: Device) -> String {
        switch device.deviceType {
        case .gpu:
            "gpu"
        case .cpu:
            "cpu"
        case .none:
            "unknown"
        }
    }

    static func hasMetalLibrary() -> Bool {
        metalLibraryCandidates().contains { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func metalLibraryCandidates() -> [URL] {
        var candidates: [URL] = []
        if let executableURL = Bundle.main.executableURL {
            let executableDir = executableURL.deletingLastPathComponent()
            let resourcesDir = executableDir.appendingPathComponent("Resources", isDirectory: true)
            candidates.append(executableDir.appendingPathComponent("mlx.metallib", isDirectory: false))
            candidates.append(executableDir.appendingPathComponent("default.metallib", isDirectory: false))
            candidates.append(resourcesDir.appendingPathComponent("mlx.metallib", isDirectory: false))
            candidates.append(resourcesDir.appendingPathComponent("default.metallib", isDirectory: false))
            candidates.append(
                executableDir
                    .appendingPathComponent("mlx-swift_Cmlx.bundle", isDirectory: true)
                    .appendingPathComponent("Contents", isDirectory: true)
                    .appendingPathComponent("Resources", isDirectory: true)
                    .appendingPathComponent("default.metallib", isDirectory: false)
            )
        }

        if let dyldPath = ProcessInfo.processInfo.environment["DYLD_FRAMEWORK_PATH"] {
            for path in dyldPath.split(separator: ":") {
                let base = URL(fileURLWithPath: String(path), isDirectory: true)
                candidates.append(
                    base
                        .appendingPathComponent("mlx-swift_Cmlx.bundle", isDirectory: true)
                        .appendingPathComponent("Contents", isDirectory: true)
                        .appendingPathComponent("Resources", isDirectory: true)
                        .appendingPathComponent("default.metallib", isDirectory: false)
                )
            }
        }

        var seen = Set<String>()
        return candidates.filter { seen.insert($0.path).inserted }
    }
}
