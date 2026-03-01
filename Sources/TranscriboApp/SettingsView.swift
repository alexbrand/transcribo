import SwiftUI

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

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)

            LabeledContent("Push-to-talk shortcut") {
                Text("Right Option (⌥)")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
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
    var body: some View {
        Form {
            LabeledContent("Model") {
                Text("Voxtral")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Status") {
                Text("Not downloaded")
                    .foregroundStyle(.orange)
            }
            Button("Download Model") {
                // TODO: Trigger model download (M4)
            }
        }
        .padding()
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
