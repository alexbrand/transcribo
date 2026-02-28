# Transcribo — Design Document v1.0

*System-wide voice transcription for macOS*

-----

|Property      |Value                                            |
|--------------|-------------------------------------------------|
|App Name      |Transcribo                                       |
|Platform      |macOS (Apple Silicon required, M1+)              |
|Tech Stack    |Swift + SwiftUI                                  |
|AI Model      |Voxtral (local inference, Metal GPU acceleration)|
|Distribution  |Mac App Store + Direct download                  |
|Business Model|TBD                                              |

-----

## 1. Product Vision

Transcribo is a lightweight, privacy-first macOS utility that enables system-wide voice-to-text transcription. Users can dictate into any text field across any application using a global keyboard shortcut. All transcription runs locally on-device using the Voxtral model with Metal GPU acceleration, ensuring zero data leaves the machine.

-----

## 2. Core User Flow

The interaction model is designed for speed and invisibility. Transcribo operates entirely in the background with no persistent UI overlay.

### 2.1 Activation

- User focuses any text input field in any macOS application.
- User presses and holds a configurable global keyboard shortcut.
- Recording begins immediately. No UI overlay or floating window appears.

### 2.2 Transcription

- Audio is streamed to the local Voxtral model in real time.
- Transcribed text is inserted directly into the focused text field as it is recognized (streaming insertion).

### 2.3 Completion

- User releases the keyboard shortcut.
- Recording stops. Final transcription is committed to the text field. The session is logged to transcription history.

-----

## 3. Architecture

### 3.1 System Components

|Component             |Description                                                                                                                                                                         |
|----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|**Menu Bar Agent**    |Persistent background process. Hosts the menu bar icon, manages global shortcut registration, and coordinates all subsystems.                                                       |
|**Audio Capture**     |Uses `AVAudioEngine` to capture microphone input. Streams audio buffers to the inference engine in real time.                                                                       |
|**Inference Engine**  |Runs Voxtral model locally with Metal GPU acceleration. Runtime TBD (candidates: MLX, llama.cpp with Metal, or custom). Accepts streaming audio, emits partial transcription tokens.|
|**Text Injection**    |Uses macOS Accessibility APIs (`CGEvent` / `AXUIElement`) to inject transcribed text into the currently focused text field.                                                         |
|**Settings & History**|SwiftUI preferences window. Stores keyboard shortcut config, language selection, and transcription history log using SwiftData or UserDefaults + local SQLite.                      |

### 3.2 Model Distribution

The Voxtral model weights are not bundled in the app binary. On first launch, the app downloads the model to `~/Library/Application Support/Transcribo/`. A progress indicator is shown during download. Subsequent launches load the cached model.

-----

## 4. Features (v1 Scope)

|Feature                   |Details                                                                              |Priority        |
|--------------------------|-------------------------------------------------------------------------------------|----------------|
|Push-to-talk transcription|Hold shortcut to record, real-time text insertion, release to stop                   |P0 — Must have  |
|Global keyboard shortcut  |Customizable in Settings. Default TBD (e.g. Fn or Right Option)                      |P0 — Must have  |
|Multi-language support    |User selects active language from Settings. Languages supported by Voxtral.          |P0 — Must have  |
|Transcription history     |Searchable log of past transcriptions with timestamp and source app                  |P1 — Should have|
|Menu bar icon             |Shows recording state. Access to Settings, History, and Quit.                        |P0 — Must have  |
|First-launch onboarding   |Model download, accessibility permission grant, microphone permission, shortcut setup|P0 — Must have  |

-----

## 5. Technical Requirements

### 5.1 Hardware

- Apple Silicon (M1 or later) — required for Metal GPU inference performance.
- Minimum 8 GB unified memory (16 GB recommended for larger model variants).
- Internet required only for initial model download.

### 5.2 macOS Permissions

- **Microphone access** — for audio capture.
- **Accessibility access** — for global keyboard shortcut monitoring and text injection into other apps.
- **Input Monitoring** — may be required for global hotkey depending on implementation.

### 5.3 Inference Runtime

The specific inference runtime is TBD. Candidates under evaluation:

- **MLX** — Apple's ML framework, native Apple Silicon optimization. Best integration with Swift ecosystem.
- **llama.cpp (Metal backend)** — Mature, well-tested. Supports streaming. C++ with Swift bridging required.
- **Custom engine** — Maximum control but highest development cost.

Decision criteria: streaming latency, memory footprint, Swift interop, and community support.

-----

## 6. Privacy & Data

- All audio processing and transcription happens on-device. No audio or text is transmitted to external servers.
- Transcription history is stored locally and can be cleared by the user at any time.
- No analytics or telemetry in v1.

-----

## 7. Open Questions

|#|Question                                                                     |Status             |
|-|-----------------------------------------------------------------------------|-------------------|
|1|Which inference runtime to use (MLX vs llama.cpp vs custom)?                 |Needs prototyping  |
|2|Business model: free, paid, freemium?                                        |TBD                |
|3|Default keyboard shortcut that doesn't conflict with common apps?            |Needs user testing |
|4|Model size vs quality tradeoff. Ship one model or offer small/large variants?|Needs benchmarking |
|5|Mac App Store sandboxing constraints on Accessibility APIs and model storage?|Needs investigation|
