import Cocoa
import OSLog
import SwiftUI
import AudioCapture
import InferenceEngine
import TextInjection

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private static let logger = Logger(subsystem: "Transcribo", category: "AppDelegate")
    private(set) var modelManager = ModelManager()
    private var menuBarManager: MenuBarManager?
    private var shortcutManager: ShortcutManager?
    private var audioCaptureSession: AudioCaptureSession?
    private var transcriptionEngine: TranscriptionEngine?
    private var textInjector: TextInjector?

    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.logger.log("applicationDidFinishLaunching")

        // Required for bare executables (swift run) to get a GUI context.
        NSApp.setActivationPolicy(.regular)

        audioCaptureSession = AudioCaptureSession()
        transcriptionEngine = TranscriptionEngine()
        textInjector = TextInjector()

        // Wire transcription output to text injection
        transcriptionEngine?.onToken = { [weak self] token in
            guard let self, let injector = self.textInjector else { return }
            Self.logger.log("Received token. isFinal=\(token.isFinal, privacy: .public), length=\(token.text.count, privacy: .public)")
            guard token.isFinal else { return }

            guard !token.text.isEmpty else {
                self.menuBarManager?.setModelStatus("No speech detected")
                Self.logger.log("Final token is empty; nothing to insert")
                return
            }

            guard TextInjector.isAccessibilityGranted else {
                Self.logger.error("Accessibility permission missing; cannot inject text")
                self.menuBarManager?.setModelStatus("Enable Accessibility access for text insertion")
                TextInjector.requestAccessibilityPermission()
                return
            }

            injector.insertText(token.text)
            injector.commitText()
            self.menuBarManager?.setModelStatus("Ready")
        }

        shortcutManager = ShortcutManager()
        shortcutManager?.onRecordingStarted = { [weak self] in
            self?.startTranscription()
        }
        shortcutManager?.onRecordingStopped = { [weak self] in
            self?.stopTranscription()
        }

        menuBarManager = MenuBarManager()
        menuBarManager?.onOpenSettings = { [weak self] in
            self?.showSettingsWindow()
        }
        menuBarManager?.setup()
        Self.logger.log("Menu bar setup complete")

        shortcutManager?.register()

        // Observe model state changes to wire model into engine and update menu bar
        observeModelState()

        // Show onboarding for first-timers; open Settings for returning users without a model
        let onboardingCompleted = UserDefaults.standard.bool(forKey: "onboardingCompleted")
        if !onboardingCompleted {
            showOnboardingWindow()
            Self.logger.log("Showing onboarding window")
        } else if modelManager.state != .ready {
            showSettingsWindow()
            Self.logger.log("Showing settings window")
        } else {
            Self.logger.log("Startup complete with model ready; waiting in menu bar")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutManager?.unregister()
        transcriptionEngine?.setModel(nil)
    }

    // MARK: - Window Management

    func showSettingsWindow() {
        if settingsWindow == nil {
            let view = SettingsView()
                .environment(modelManager)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.title = "Settings"
            window.contentView = NSHostingView(rootView: view)
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showOnboardingWindow() {
        if onboardingWindow == nil {
            let view = OnboardingView(onComplete: { [weak self] in
                self?.handleOnboardingComplete()
            })
            .environment(modelManager)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.title = "Welcome to Transcribo"
            window.contentView = NSHostingView(rootView: view)
            window.center()
            onboardingWindow = window
        }

        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func handleOnboardingComplete() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else {
            return
        }

        if let settingsWindow, closingWindow === settingsWindow {
            self.settingsWindow = nil
        }
        if let onboardingWindow, closingWindow === onboardingWindow {
            self.onboardingWindow = nil
        }
    }

    // MARK: - Transcription

    private func startTranscription() {
        guard self.modelManager.state == .ready else {
            Self.logger.error("Recording requested while model state is not ready: \(String(describing: self.modelManager.state), privacy: .public)")
            self.menuBarManager?.setModelStatus("Model not ready. Open Settings to load model.")
            showSettingsWindow()
            return
        }

        menuBarManager?.setRecording(true)
        let started = audioCaptureSession?.start(
            bufferHandler: { [weak self] buffer in
                self?.transcriptionEngine?.processAudioBuffer(buffer)
            },
            failureHandler: { [weak self] message in
                Self.logger.error("Audio capture failed: \(message, privacy: .public)")
                self?.menuBarManager?.setRecording(false)
                self?.menuBarManager?.setModelStatus(message)
            }
        ) ?? false

        if !started {
            menuBarManager?.setRecording(false)
            Self.logger.error("Audio capture did not start")
        } else {
            Self.logger.log("Recording started")
        }
    }

    private func stopTranscription() {
        audioCaptureSession?.stop()
        transcriptionEngine?.finalize()
        menuBarManager?.setRecording(false)
        Self.logger.log("Recording stopped and transcription finalized")
    }

    // MARK: - Model State Observation

    private func observeModelState() {
        func track() {
            withObservationTracking {
                _ = self.modelManager.state
                _ = self.modelManager.downloadProgress
            } onChange: {
                Task { @MainActor [weak self] in
                    self?.handleModelStateChange()
                    track()
                }
            }
        }
        track()
    }

    private func handleModelStateChange() {
        let state = modelManager.state
        switch state {
        case .notDownloaded:
            menuBarManager?.setModelStatus("Model not downloaded")
        case .downloading:
            let pct = Int(modelManager.downloadProgress * 100)
            menuBarManager?.setModelStatus("Downloading \(pct)%...")
        case .downloaded:
            menuBarManager?.setModelStatus("Loading model...")
        case .loading:
            menuBarManager?.setModelStatus("Loading model...")
        case .ready:
            transcriptionEngine?.setModel(modelManager.model)
            menuBarManager?.setModelStatus("Ready")
        case .error(let msg):
            transcriptionEngine?.setModel(nil)
            menuBarManager?.setModelStatus("Error: \(msg)")
        }
    }
}
