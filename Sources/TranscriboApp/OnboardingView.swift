import SwiftUI
import AudioCapture
import TextInjection

struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var micPermissionGranted = false
    @State private var accessibilityGranted = false
    @State private var modelDownloadProgress: Double = 0
    @State private var modelDownloaded = false
    @Environment(\.dismiss) private var dismiss

    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 24) {
            // Progress indicator
            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Capsule()
                        .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal)

            Spacer()

            switch currentStep {
            case 0:
                welcomeStep
            case 1:
                microphoneStep
            case 2:
                accessibilityStep
            case 3:
                modelDownloadStep
            case 4:
                doneStep
            default:
                EmptyView()
            }

            Spacer()

            // Navigation buttons
            HStack {
                if currentStep > 0 && currentStep < totalSteps - 1 {
                    Button("Back") { currentStep -= 1 }
                }
                Spacer()
                Button(currentStep == totalSteps - 1 ? "Get Started" : "Continue") {
                    if currentStep == totalSteps - 1 {
                        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                        dismiss()
                    } else {
                        currentStep += 1
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        }
        .padding(32)
        .frame(width: 500, height: 400)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text("Welcome to Transcribo")
                .font(.title)
                .bold()
            Text("System-wide voice transcription that runs entirely on your Mac. No data ever leaves your device.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var microphoneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: micPermissionGranted ? "mic.fill" : "mic.slash")
                .font(.system(size: 48))
                .foregroundStyle(micPermissionGranted ? .green : .orange)
            Text("Microphone Access")
                .font(.title2)
                .bold()
            Text("Transcribo needs access to your microphone to hear your voice for transcription.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if micPermissionGranted {
                Label("Permission granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Grant Microphone Access") {
                    AudioCaptureSession.requestPermission { granted in
                        micPermissionGranted = granted
                    }
                }
            }
        }
    }

    private var accessibilityStep: some View {
        VStack(spacing: 16) {
            Image(systemName: accessibilityGranted ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(accessibilityGranted ? .green : .orange)
            Text("Accessibility Access")
                .font(.title2)
                .bold()
            Text("Transcribo needs Accessibility access to detect the global shortcut and type text into other apps.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if accessibilityGranted {
                Label("Permission granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Open System Settings") {
                    TextInjector.requestAccessibilityPermission()
                }
            }
        }
        .onAppear { checkAccessibility() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            checkAccessibility()
        }
    }

    private var modelDownloadStep: some View {
        VStack(spacing: 16) {
            Image(systemName: modelDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(modelDownloaded ? .green : Color.accentColor)
            Text("Download Model")
                .font(.title2)
                .bold()
            Text("The Voxtral speech model will be downloaded to your Mac. This is a one-time download.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if modelDownloaded {
                Label("Model ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                ProgressView(value: modelDownloadProgress)
                    .padding(.horizontal, 40)
                Button("Download") {
                    // TODO: Wire up ModelManager.downloadModel() (M4)
                }
            }
        }
    }

    private var doneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("You're All Set!")
                .font(.title)
                .bold()
            Text("Hold the Right Option key (⌥) to start dictating into any text field.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private func checkAccessibility() {
        accessibilityGranted = TextInjector.isAccessibilityGranted
    }
}
