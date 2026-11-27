# Flockerwhisper

A lightweight, fully local macOS menu bar Whisper client powered by Apple Silicon Core ML (`WhisperKit` + Whisper Large v3 Turbo).

## What it does

- **Global hotkey (`⌥ Space`)**: Press Option + Space anywhere on macOS to open the dark floating HUD in the center of your active screen and start recording immediately. No Accessibility or Input Monitoring permission required.
- **Live dot waveform**: Quiet audio renders as a crisp row of dots that rise into vertical bars as you speak. Click the top-right collapse arrows to toggle compact pill mode.
- **Fast local transcription**: Press `⌥ Space` again to stop. A progress bar analyses and converts your speech locally on Apple Silicon (Neural Engine / GPU), copies the transcript to your clipboard, flashes confirmation, and closes automatically. Press `esc` at any time to cancel.
- **Menu bar transcript history**: Click the waveform icon in the macOS menu bar to search past transcripts, click any item to copy it back to your clipboard, switch local Whisper models, or toggle Launch at Login.

## Privacy

- All speech recognition runs 100% locally on your Mac via Core ML.
- Audio is buffered only in memory during recording and discarded immediately after transcription.
- No telemetry, analytics, cloud APIs, or account sign-in.
- The only network request is the one-time download of the open-source Core ML Whisper model weights from Hugging Face (`argmaxinc/whisperkit-coreml`) into `~/Library/Application Support/Flockerwhisper/Models/`. After that, everything works completely offline.

## Requirements

- macOS 14 (Sonoma) or later on Apple Silicon (M1 / M2 / M3 / M4)
- Xcode or Swift Command Line Tools (`swift` 5.10+)

## Build & Install

```sh
git clone https://github.com/chrisjgf/flockerwhisper.git
cd flockerwhisper
./scripts/install.sh
```

This builds a release binary, packages and ad-hoc signs `Flockerwhisper.app`, copies it to `/Applications/Flockerwhisper.app`, and launches it.

1. Grant Microphone permission when macOS prompts on first dictation.
2. On first launch, Flockerwhisper downloads the local Core ML model (`large-v3-v20240930_turbo`, ~1.5 GB) into `~/Library/Application Support/Flockerwhisper/Models/`.

## Local Models

Switch anytime from the menu bar footer menu:

- **Large v3 Turbo** (`large-v3-v20240930_turbo`, default) — best speed & accuracy on Apple Silicon (~1.5 GB)
- **Large v3 Turbo Compact** (`large-v3-v20240930_626MB`) — smaller download (~626 MB)
- **Small (English)** (`small.en`) — ultra-lightweight (~240 MB)

## Development & Tests

```sh
# Run unit tests
swift test

# Build Flockerwhisper.app bundle only (outputs dist/Flockerwhisper.app)
./scripts/build-app.sh

# Optional: generate an Xcode project
xcodegen generate && open Flockerwhisper.xcodeproj
```

Transcript history is saved locally at `~/Library/Application Support/Flockerwhisper/history.json`.
