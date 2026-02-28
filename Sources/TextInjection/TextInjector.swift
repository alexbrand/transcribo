import Cocoa
import ApplicationServices

/// Injects transcribed text into the currently focused text field of any macOS application
/// using Accessibility APIs and synthesized keyboard events.
public final class TextInjector {
    /// Tracks the length of the last partial insertion so it can be replaced on correction.
    private var lastPartialLength = 0

    public init() {}

    /// Whether the app has been granted Accessibility permission.
    public static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user to grant Accessibility permission by opening System Settings.
    public static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Insert text by synthesizing keyboard events (most universally compatible).
    public func insertText(_ text: String) {
        // Delete previous partial text before inserting the replacement
        if lastPartialLength > 0 {
            deleteCharacters(lastPartialLength)
        }

        for scalar in text.unicodeScalars {
            typeCharacter(scalar)
        }

        lastPartialLength = text.count
    }

    /// Commit the current text and reset partial tracking.
    /// Call this when the transcription session ends (final token).
    public func commitText() {
        lastPartialLength = 0
    }

    // MARK: - Private

    private func typeCharacter(_ scalar: Unicode.Scalar) {
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)

        var utf16 = [UniChar](scalar.utf16)
        keyDown?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        keyUp?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func deleteCharacters(_ count: Int) {
        let backspaceKeyCode: CGKeyCode = 0x33

        for _ in 0..<count {
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: backspaceKeyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: backspaceKeyCode, keyDown: false)
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }
}
