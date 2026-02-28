# Transcribo — Implementation Plan

This plan breaks the Transcribo build into eight sequential milestones. Each milestone is self-contained and produces a testable artifact. Later milestones depend on earlier ones.

-----

## Milestone 0: Project Scaffolding

**Goal:** Establish the Xcode project, build targets, and CI foundation.

- [ ] Create a new Xcode project (macOS App, Swift + SwiftUI, minimum deployment target macOS 14).
- [ ] Configure the app as a menu-bar-only agent (`LSUIElement = YES` in Info.plist).
- [ ] Set up a Swift Package Manager workspace for internal modules:
  - `TranscriboApp` — main app target.
  - `AudioCapture` — microphone recording library.
  - `InferenceEngine` — model loading and transcription.
  - `TextInjection` — accessibility-based text insertion.
- [ ] Add a `Makefile` or `justfile` with common commands (`build`, `test`, `run`, `clean`).
- [ ] Configure code signing and entitlements (microphone, accessibility, network-client for model download).
- [ ] Add `.gitignore` for Xcode / Swift artifacts.

**Exit criteria:** Project builds and launches as a menu bar icon that does nothing yet.

-----

## Milestone 1: CI/CD (GitHub Actions)

**Goal:** Establish continuous integration so every push and PR is automatically built and tested on Apple Silicon.

### 1.1 Build Workflow (`.github/workflows/build.yml`)

- [ ] Trigger on: push to `main`, pull requests targeting `main`.
- [ ] Runner: `macos-15` (Apple Silicon).
- [ ] Steps:
  1. Checkout repo.
  2. Select Xcode version (`sudo xcode-select -s`).
  3. Resolve Swift Package dependencies (`xcodebuild -resolvePackageDependencies`).
  4. Build the project (`xcodebuild build`).
  5. Run unit tests (`xcodebuild test`).
- [ ] Cache SPM dependencies (`~/Library/Developer/Xcode/DerivedData` and `.build`) to speed up builds.
- [ ] Fail the workflow on any compiler warning (`SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`).

### 1.2 Lint Workflow (`.github/workflows/lint.yml`)

- [ ] Trigger on: push to `main`, pull requests targeting `main`.
- [ ] Run **SwiftLint** (install via Homebrew on the runner).
- [ ] Add a `.swiftlint.yml` config to the repo with project-appropriate rules.
- [ ] Fail the workflow on any lint violation.

### 1.3 Release Workflow (`.github/workflows/release.yml`)

- [ ] Trigger on: push of a version tag (`v*.*.*`).
- [ ] Build a release archive (`xcodebuild archive`).
- [ ] Export the archive as a signed `.app` bundle.
- [ ] Notarize the app using `notarytool` (Apple ID credentials stored as GitHub Actions secrets).
- [ ] Package the notarized app into a DMG.
- [ ] Create a GitHub Release and attach the DMG as an artifact.

### 1.4 Secrets & Configuration

- [ ] Store in GitHub Actions secrets:
  - `APPLE_DEVELOPER_ID_CERTIFICATE` — base64-encoded signing certificate.
  - `APPLE_DEVELOPER_ID_PASSWORD` — certificate passphrase.
  - `APPLE_ID` — Apple ID for notarization.
  - `APPLE_ID_PASSWORD` — app-specific password for notarization.
  - `APPLE_TEAM_ID` — developer team identifier.
- [ ] Document the required secrets in the repo README or a `CONTRIBUTING.md`.

**Exit criteria:** Pushes to `main` trigger build + test + lint. Tagged releases produce a notarized DMG attached to a GitHub Release.

-----

## Milestone 2: Menu Bar Agent & Global Shortcut

**Goal:** Ship the always-running menu bar shell with a working global hotkey.

### 1.1 Menu Bar Icon

- [ ] Implement `NSStatusItem` with an SF Symbol icon (e.g. `waveform`).
- [ ] Add a menu with items: *Settings…*, *History…*, *Quit Transcribo*.
- [ ] Toggle icon appearance between idle and recording states (swap symbol or tint color).

### 1.2 Global Keyboard Shortcut

- [ ] Register a global event monitor (`NSEvent.addGlobalMonitorForEvents`) for key-down and key-up of the configured shortcut.
- [ ] Also register a local monitor so the shortcut works when Transcribo itself is focused.
- [ ] Expose a `ShortcutManager` that emits two events: `recordingStarted` and `recordingStopped`.
- [ ] Store the chosen shortcut key in `UserDefaults`. Default: Right Option (⌥) key.

**Exit criteria:** Pressing and holding the shortcut logs "recording started"; releasing logs "recording stopped". Menu bar icon reflects the state change.

-----

## Milestone 3: Audio Capture

**Goal:** Capture microphone audio in real time and produce buffers suitable for the inference engine.

- [ ] Request microphone permission on first use (`AVCaptureDevice.requestAccess`).
- [ ] Build `AudioCaptureSession` around `AVAudioEngine`:
  - Install a tap on the input node.
  - Convert audio to the format expected by Voxtral (16 kHz, mono, Float32).
  - Expose a callback or `AsyncStream<AVAudioPCMBuffer>` for downstream consumers.
- [ ] Wire `ShortcutManager` events to start/stop the capture session.
- [ ] Handle edge cases: microphone disconnected, permission revoked, audio route changes.

**Exit criteria:** While the shortcut is held, audio buffers are captured and can be written to a WAV file for manual verification.

-----

## Milestone 4: Inference Engine (Local Voxtral)

**Goal:** Run the Voxtral speech-to-text model on-device with streaming output.

### 3.1 Runtime Selection & Integration

- [ ] Prototype with **MLX-Swift** (preferred for native Apple Silicon support and Swift interop).
  - If MLX proves insufficient (latency, missing features), fall back to **llama.cpp** with a Swift C-bridging layer.
- [ ] Add the chosen runtime as a Swift Package dependency.

### 3.2 Model Management

- [ ] On first launch, download model weights to `~/Library/Application Support/Transcribo/models/`.
- [ ] Show a progress view (bytes downloaded / total) during download.
- [ ] Verify download integrity with a SHA-256 checksum.
- [ ] On subsequent launches, load the cached model. Skip download if checksum matches.
- [ ] Provide a "Re-download Model" option in Settings for recovery.

### 3.3 Streaming Transcription

- [ ] Build `TranscriptionEngine` that accepts `AsyncStream<AVAudioPCMBuffer>` and emits `AsyncStream<TranscriptionToken>`.
- [ ] `TranscriptionToken` contains: partial text, `isFinal` flag, confidence score (if available), timestamp.
- [ ] Load the model into GPU memory on app launch. Unload on quit.
- [ ] Target latency: partial results within 300 ms of speech.

### 3.4 Language Support

- [ ] Accept a `language` parameter (ISO 639-1 code) to configure the model.
- [ ] Expose the list of supported languages so the Settings UI can present them.

**Exit criteria:** Hold the shortcut, speak, and see streamed partial transcription tokens printed to the console in real time.

-----

## Milestone 5: Text Injection

**Goal:** Insert transcribed text into the focused text field of any macOS application.

### 4.1 Accessibility Setup

- [ ] Prompt the user to grant Accessibility permission (guide them to System Settings → Privacy & Security → Accessibility).
- [ ] Detect whether permission is granted at runtime using `AXIsProcessTrusted()`.

### 4.2 Text Insertion

- [ ] Primary method: synthesize keyboard events via `CGEvent` to type each character. This is the most universally compatible approach.
- [ ] Fallback method: use `AXUIElement` to find the focused text field and set its `AXValue` attribute directly (works in some apps where `CGEvent` doesn't).
- [ ] Handle streaming: as each `TranscriptionToken` arrives, inject the new characters immediately.
- [ ] Handle corrections: if the model revises a partial result, delete the previous partial text (via synthetic backspace events) and re-type the corrected version.

### 4.3 Edge Cases

- [ ] Detect when no text field is focused and skip injection (optionally notify via menu bar icon).
- [ ] Respect text field character limits where detectable.
- [ ] Handle rapid shortcut toggling (debounce to avoid duplicate sessions).

**Exit criteria:** Hold the shortcut, speak into the mic, and see transcribed text appear in a TextEdit document in real time.

-----

## Milestone 6: Settings & History

**Goal:** Build the preferences window and transcription history log.

### 5.1 Settings Window

- [ ] Create a SwiftUI `Settings` scene (opens via menu bar → *Settings…* or ⌘,).
- [ ] **General tab:**
  - Keyboard shortcut picker (record a new shortcut).
  - Launch at login toggle (`SMAppService`).
- [ ] **Language tab:**
  - Dropdown to select active transcription language.
  - Display list sourced from `TranscriptionEngine.supportedLanguages`.
- [ ] **Model tab:**
  - Show current model status (downloaded, size on disk, version).
  - "Re-download Model" button.
- [ ] **About tab:**
  - App version, credits, link to website.

### 5.2 Transcription History

- [ ] Define a `TranscriptionRecord` model: id, timestamp, transcribed text, source app name, language, duration.
- [ ] Store records using **SwiftData** (backed by local SQLite).
- [ ] Build a history list view with:
  - Chronological list of past transcriptions.
  - Search bar filtering by text content.
  - Click to copy text to clipboard.
  - Swipe or button to delete individual records.
  - "Clear All History" button with confirmation.
- [ ] Write a `TranscriptionRecord` at the end of each dictation session.

**Exit criteria:** Settings changes persist across app restarts. Completed transcriptions appear in the history view and are searchable.

-----

## Milestone 7: First-Launch Onboarding

**Goal:** Guide new users through setup so the app is fully functional after onboarding.

- [ ] Detect first launch (check `UserDefaults` flag or absence of model files).
- [ ] Present a multi-step onboarding flow (SwiftUI sheet or dedicated window):
  1. **Welcome** — brief explanation of what Transcribo does.
  2. **Microphone Permission** — request access, show status indicator.
  3. **Accessibility Permission** — explain why it's needed, deep-link to System Settings, poll `AXIsProcessTrusted()` until granted.
  4. **Model Download** — start download, show progress, handle errors/retry.
  5. **Shortcut Setup** — let user confirm or customize the global shortcut.
  6. **Done** — confirm everything is set up, dismiss onboarding.
- [ ] Allow re-running onboarding from Settings ("Setup Assistant" button) for troubleshooting.

**Exit criteria:** A fresh install walks through onboarding, grants all permissions, downloads the model, and is ready to transcribe.

-----

## Milestone 8: Polish & Release Prep

**Goal:** Harden the app for public release.

### 7.1 Error Handling & Resilience

- [ ] Handle model loading failures gracefully (corrupt file → re-download prompt).
- [ ] Handle inference errors (out of memory → suggest closing other apps).
- [ ] Handle microphone disconnection mid-recording (stop session, notify user).
- [ ] Handle accessibility permission revocation (detect and prompt to re-enable).

### 7.2 Performance

- [ ] Profile Metal GPU utilization and memory footprint during transcription.
- [ ] Optimize audio buffer sizes for latency vs. efficiency tradeoff.
- [ ] Ensure idle CPU/GPU usage is near zero when not transcribing.

### 7.3 Distribution

- [ ] Configure notarization for direct download distribution.
- [ ] Evaluate Mac App Store submission:
  - Test sandboxing constraints with accessibility APIs.
  - Test model storage in app container vs. Application Support.
  - If sandboxing is incompatible, ship direct download only for v1.
- [ ] Build a DMG installer with background image and Applications folder alias.

### 7.4 Testing

- [ ] Unit tests for `AudioCaptureSession`, `TranscriptionEngine`, `ShortcutManager`.
- [ ] Integration tests for the full pipeline (audio → inference → text injection) using recorded audio samples.
- [ ] Manual test matrix across common apps: Safari, Chrome, Slack, VS Code, TextEdit, Notes, Terminal.

**Exit criteria:** App is signed, notarized, and installable. Core flow works reliably across the test matrix.

-----

## Dependency Graph

```
M0 (Scaffolding)
 ├── M1 (CI/CD)
 └── M2 (Menu Bar + Shortcut)
      ├── M3 (Audio Capture)
      │    └── M4 (Inference Engine)
      │         └── M5 (Text Injection)
      │              └── M8 (Polish)
      ├── M6 (Settings & History)
      └── M7 (Onboarding)
```

M1 (CI/CD) should be set up immediately after M0 so all subsequent milestones benefit from automated builds and tests. M6 and M7 can be developed in parallel with M4/M5 once M2 is complete.

-----

## Open Decisions (to resolve during implementation)

|Decision|Options|Resolve by|
|--------|-------|----------|
|Inference runtime|MLX-Swift vs llama.cpp|End of M4 prototype|
|Persistence layer|SwiftData vs raw SQLite|Start of M6|
|Default shortcut key|Right Option, Fn, Globe, or other|User testing during M7|
|Mac App Store feasibility|Sandbox-compatible or direct-only|During M8|
