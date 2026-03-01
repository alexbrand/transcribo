import SwiftUI
import AVFoundation
import AppKit
import InferenceEngine
import AudioCapture
import TextInjection

struct SettingsView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsHeader()
                    GeneralSettingsSection()
                    LanguageSettingsSection()
                    ModelSettingsSection()
                    AboutSection()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 760, height: 620)
    }
}

struct SettingsHeader: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.9), Color.cyan.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "waveform.and.magnifyingglass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text("Transcribo Settings")
                    .font(.system(size: 24, weight: .bold))
                Text("Configure permissions, model behavior, and transcription defaults.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(2)
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder var content: Content

    init(
        title: String,
        icon: String,
        iconColor: Color = .accentColor,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 24, height: 24)
                    .background(iconColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
                Text(title)
                    .font(.title3.weight(.semibold))
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct SectionSubtext: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - General

struct GeneralSettingsSection: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("shortcutKeyCode") private var shortcutKeyCode = 0x3D
    @State private var micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var accessibilityGranted = TextInjector.isAccessibilityGranted

    var body: some View {
        SettingsCard(title: "General", icon: "slider.horizontal.3", iconColor: .blue) {
            VStack(alignment: .leading, spacing: 12) {
                if !accessibilityGranted {
                    Label("Accessibility access is required for text insertion.", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.orange)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Toggle("Launch at login", isOn: $launchAtLogin)
                    .toggleStyle(.switch)

                LabeledContent("Push-to-talk shortcut") {
                    Text("Right Option (⌥)")
                        .foregroundStyle(.secondary)
                }
                SectionSubtext(text: "Hold the shortcut to record and release to transcribe.")

                Divider()

                LabeledContent("Microphone") {
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
                    Button("Open Microphone Settings") {
                        openMicrophoneSettings()
                    }
                }

                Divider()

                LabeledContent("Accessibility") {
                    Text(accessibilityGranted ? "Allowed" : "Not granted")
                        .foregroundStyle(accessibilityGranted ? .green : .red)
                }

                if !accessibilityGranted {
                    HStack(spacing: 10) {
                        Button("Grant Accessibility Access") {
                            TextInjector.requestAccessibilityPermission()
                        }
                        Button("Open Accessibility Settings") {
                            openAccessibilitySettings()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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

struct LanguageSettingsSection: View {
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
        SettingsCard(title: "Language", icon: "globe", iconColor: .teal) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Transcription language", selection: $language) {
                    ForEach(supportedLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                .pickerStyle(.menu)
                SectionSubtext(text: "Choose the language that best matches incoming speech for better recognition quality.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Model

struct ModelSettingsSection: View {
    @Environment(ModelManager.self) private var modelManager
    @AppStorage("hfToken") private var hfToken = ""

    var body: some View {
        SettingsCard(title: "Model", icon: "cpu", iconColor: .indigo) {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Model") {
                    Text("Voxtral Mini 4B (4-bit, ~3.1 GB)")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Status") {
                    statusView
                }

                actionButton

                Divider()

                SecureField("HuggingFace Token (optional)", text: $hfToken)
                    .textFieldStyle(.roundedBorder)

                SectionSubtext(text: "Speeds up downloads and avoids rate limits. Get one at huggingface.co/settings/tokens")

                Divider()

                Text("Download details")
                    .font(.subheadline.weight(.semibold))

                Text(modelManager.downloadStatus)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Text(ModelManager.diagnosticsLogPath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                        .frame(width: 160)
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
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
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

struct AboutSection: View {
    var body: some View {
        SettingsCard(title: "About", icon: "info.circle", iconColor: .mint) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "waveform.badge.mic")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Transcribo")
                            .font(.headline)
                        Text("Version 1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Privacy-first voice transcription for macOS.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
