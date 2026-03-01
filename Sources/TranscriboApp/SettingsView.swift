import SwiftUI
import AVFoundation
import AppKit
import InferenceEngine
import AudioCapture
import TextInjection

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            LanguageSettingsTab()
                .tabItem {
                    Label("Language", systemImage: "globe")
                }

            ModelSettingsTab()
                .tabItem {
                    Label("Model", systemImage: "cpu")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
    }
}

// MARK: - General

struct GeneralSettingsTab: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("shortcutKeyCode") private var shortcutKeyCode = 0x3D
    @State private var micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var accessibilityGranted = TextInjector.isAccessibilityGranted

    var body: some View {
        Form {
            if !accessibilityGranted {
                Label("Accessibility access is required for text insertion.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }

            Toggle("Launch at login", isOn: $launchAtLogin)

            LabeledContent("Push-to-talk shortcut") {
                Text("Right Option (⌥)")
                    .foregroundStyle(.secondary)
            }

            Section("Permissions") {
                LabeledContent("Status") {
                    Text(microphoneStatusText)
                        .foregroundStyle(microphoneStatusColor)
                }

                if micStatus == .notDetermined {
                    Button("Request Microphone Access") {
                        AudioCaptureSession.requestPermission { _ in
                            refreshMicStatus()
                        }
                    }
                } else if micStatus == .denied || micStatus == .restricted {
                    Button("Open System Settings") {
                        openMicrophoneSettings()
                    }
                }

                Divider()

                LabeledContent("Accessibility") {
                    Text(accessibilityGranted ? "Allowed" : "Not granted")
                        .foregroundStyle(accessibilityGranted ? .green : .red)
                }

                if !accessibilityGranted {
                    Button("Grant Accessibility Access") {
                        TextInjector.requestAccessibilityPermission()
                    }
                    Button("Open Accessibility Settings") {
                        openAccessibilitySettings()
                    }
                }
            }
        }
        .padding()
        .onAppear {
            refreshMicStatus()
            refreshAccessibilityStatus()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            refreshAccessibilityStatus()
        }
    }

    private var microphoneStatusText: String {
        switch micStatus {
        case .authorized:
            "Allowed"
        case .notDetermined:
            "Not requested"
        case .denied:
            "Denied"
        case .restricted:
            "Restricted"
        @unknown default:
            "Unknown"
        }
    }

    private var microphoneStatusColor: Color {
        switch micStatus {
        case .authorized:
            .green
        case .notDetermined:
            .orange
        case .denied, .restricted:
            .red
        @unknown default:
            .secondary
        }
    }

    private func refreshMicStatus() {
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    }

    private func refreshAccessibilityStatus() {
        accessibilityGranted = TextInjector.isAccessibilityGranted
    }

    private func openMicrophoneSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Language

struct LanguageSettingsTab: View {
    @AppStorage("transcriptionLanguage") private var language = "en"

    private let supportedLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("zh", "Chinese"),
    ]

    var body: some View {
        Form {
            Picker("Transcription language", selection: $language) {
                ForEach(supportedLanguages, id: \.code) { lang in
                    Text(lang.name).tag(lang.code)
                }
            }
        }
        .padding()
    }
}

// MARK: - Model

struct ModelSettingsTab: View {
    @Environment(ModelManager.self) private var modelManager
    @AppStorage("hfToken") private var hfToken = ""

    var body: some View {
        Form {
            LabeledContent("Model") {
                Text("Voxtral Mini 4B (4-bit, ~3.1 GB)")
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Status") {
                statusView
            }

            actionButton

            Section {
                SecureField("HuggingFace Token (optional)", text: $hfToken)
                Text("Speeds up downloads and avoids rate limits. Get one at huggingface.co/settings/tokens")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Diagnostics") {
                Text(modelManager.downloadStatus)
                    .foregroundStyle(.secondary)
                Text(ModelManager.diagnosticsLogPath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var statusView: some View {
        switch modelManager.state {
        case .notDownloaded:
            Text("Not downloaded")
                .foregroundStyle(.orange)
        case .downloading:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ProgressView(value: modelManager.downloadProgress)
                        .frame(width: 100)
                    Text("\(Int(modelManager.downloadProgress * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Text(modelManager.downloadStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .downloaded:
            Text("Downloaded")
                .foregroundStyle(.blue)
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading...")
                    .foregroundStyle(.secondary)
            }
        case .ready:
            Label("Model loaded", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .error(let msg):
            Text(msg)
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch modelManager.state {
        case .notDownloaded:
            Button("Download Model") {
                Task { await modelManager.downloadAndLoad() }
            }
        case .downloading:
            EmptyView()
        case .downloaded:
            Button("Load Model") {
                Task { await modelManager.loadModel() }
            }
        case .loading:
            EmptyView()
        case .ready:
            Button("Delete Model", role: .destructive) {
                modelManager.deleteModel()
            }
        case .error:
            Button("Retry") {
                Task { await modelManager.downloadAndLoad() }
            }
        }
    }
}

// MARK: - About

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
            Text("Transcribo")
                .font(.title)
            Text("Version 1.0.0")
                .foregroundStyle(.secondary)
            Text("Privacy-first voice transcription for macOS.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
