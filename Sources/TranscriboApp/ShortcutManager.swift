import Cocoa

final class ShortcutManager {
    var onRecordingStarted: (() -> Void)?
    var onRecordingStopped: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isRecording = false

    /// The key code for the configured shortcut. Default: Right Option key (kVK_RightOption = 0x3D).
    var shortcutKeyCode: UInt16 {
        UInt16(UserDefaults.standard.integer(forKey: "shortcutKeyCode"))
    }

    init() {
        if UserDefaults.standard.object(forKey: "shortcutKeyCode") == nil {
            UserDefaults.standard.set(0x3D, forKey: "shortcutKeyCode") // Right Option
        }
    }

    func register() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    func unregister() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let isShortcutKeyPressed = event.keyCode == shortcutKeyCode

        guard isShortcutKeyPressed else { return }

        // Check if the modifier key is now pressed (flags contain it) or released
        let isPressed = event.modifierFlags.contains(.option)

        if isPressed && !isRecording {
            isRecording = true
            onRecordingStarted?()
        } else if !isPressed && isRecording {
            isRecording = false
            onRecordingStopped?()
        }
    }
}
