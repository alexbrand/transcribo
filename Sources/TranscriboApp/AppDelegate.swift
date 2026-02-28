import Cocoa
import AudioCapture
import InferenceEngine
import TextInjection

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    private var shortcutManager: ShortcutManager?
    private var audioCaptureSession: AudioCaptureSession?
    private var transcriptionEngine: TranscriptionEngine?
    private var textInjector: TextInjector?

    func applicationDidFinishLaunching(_ notification: Notification) {
        audioCaptureSession = AudioCaptureSession()
        transcriptionEngine = TranscriptionEngine()
        textInjector = TextInjector()

        shortcutManager = ShortcutManager()
        shortcutManager?.onRecordingStarted = { [weak self] in
            self?.startTranscription()
        }
        shortcutManager?.onRecordingStopped = { [weak self] in
            self?.stopTranscription()
        }

        menuBarManager = MenuBarManager()
        menuBarManager?.setup()

        shortcutManager?.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutManager?.unregister()
        transcriptionEngine?.unloadModel()
    }

    private func startTranscription() {
        menuBarManager?.setRecording(true)
        audioCaptureSession?.start { [weak self] buffer in
            self?.transcriptionEngine?.processAudioBuffer(buffer)
        }
    }

    private func stopTranscription() {
        audioCaptureSession?.stop()
        transcriptionEngine?.finalize()
        menuBarManager?.setRecording(false)
    }
}
