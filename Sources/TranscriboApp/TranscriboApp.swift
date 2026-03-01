import SwiftUI
import InferenceEngine

@main
struct TranscriboApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // All windows are created manually in AppDelegate via NSWindow + NSHostingView
        // because SwiftUI Window scenes don't work for bare SwiftPM executables.
        Settings {
            EmptyView()
        }
    }
}
