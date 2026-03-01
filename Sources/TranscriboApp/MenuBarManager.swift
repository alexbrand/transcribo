import Cocoa

@MainActor
final class MenuBarManager {
    private var statusItem: NSStatusItem?
    var onOpenSettings: (() -> Void)?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Transcribo")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "History…", action: #selector(openHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Transcribo", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem?.menu = menu
    }

    func setRecording(_ isRecording: Bool) {
        let symbolName = isRecording ? "waveform.circle.fill" : "waveform"
        statusItem?.button?.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: isRecording ? "Transcribo (Recording)" : "Transcribo"
        )
    }

    func setModelStatus(_ text: String) {
        statusItem?.button?.toolTip = "Transcribo — \(text)"
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func openHistory() {
        // TODO: Open history window (M6)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
