import Cocoa
import ApplicationServices

/// Abstraction over keyboard event posting, enabling test mocking.
public protocol KeyboardDriver {
    func typeCharacter(_ scalar: Unicode.Scalar)
    func deleteCharacters(_ count: Int)
}

/// Posts real CGEvent keyboard events.
public struct CGEventKeyboardDriver: KeyboardDriver {
    public init() {}

    public func typeCharacter(_ scalar: Unicode.Scalar) {
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)

        var utf16 = [UniChar](scalar.utf16)
        keyDown?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        keyUp?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    public func deleteCharacters(_ count: Int) {
        let backspaceKeyCode: CGKeyCode = 0x33

        for _ in 0..<count {
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: backspaceKeyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: backspaceKeyCode, keyDown: false)
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }
}

/// Injects transcribed text into the currently focused text field of any macOS application
/// using Accessibility APIs and synthesized keyboard events.
public final class TextInjector {
    private let driver: KeyboardDriver

    /// Tracks the length of the last partial insertion so it can be replaced on correction.
    public private(set) var partialLength = 0

    public init(driver: KeyboardDriver = CGEventKeyboardDriver()) {
        self.driver = driver
    }

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
        if partialLength > 0 {
            driver.deleteCharacters(partialLength)
        }

        for scalar in text.unicodeScalars {
            driver.typeCharacter(scalar)
        }

        partialLength = text.count
    }

    /// Commit the current text and reset partial tracking.
    /// Call this when the transcription session ends (final token).
    public func commitText() {
        partialLength = 0
    }
}
