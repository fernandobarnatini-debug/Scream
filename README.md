# Scream

Fully local push-to-talk dictation for macOS. Hold a key, speak, release — your words are typed into whichever app you're using. Transcription runs entirely on your Mac with [WhisperKit](https://github.com/argmaxinc/argmax-oss-swift); no audio or text ever leaves your machine.

## Features

- **Hold-to-talk** (default: `fn`) and **toggle** (default: right `⌘`) hotkeys — rebindable to almost any key, including mouse side/middle buttons
- Lives in the menu bar and the Dock, with a floating pill while you dictate
- Whisper model manager: from Tiny (66 MB) up to Large v3 Turbo (626 MB, recommended)
- Custom vocabulary (names, jargon) and find-and-replace rules applied to every transcript
- Spoken commands like "new line" and "scratch that"
- Optional transcript cleanup through a local [Ollama](https://ollama.com) model, with per-app tone presets — also fully offline
- Skips typing into password fields (secure input detection), can restore your clipboard after inserting

## Requirements

- Apple Silicon Mac (the model runs on the Neural Engine)
- macOS 15.0 or later

## Install (no Xcode required)

1. Download `Scream.zip` from the [latest release](../../releases/latest) and unzip it.
2. Drag `Scream.app` into your **Applications** folder and open it.
3. macOS will refuse the first launch because the app isn't notarized. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to the message about Scream, then confirm. This is only needed once.
4. Follow the in-app setup: grant Microphone and Accessibility permissions and download a model. First activation optimizes the model for the Neural Engine and can take a minute or two — after that it's instant.

Hold `fn`, say something, let go. That's it.

## Build from source

Requires Xcode 16+ and [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate
xcodebuild -project Scream.xcodeproj -scheme Scream -configuration Release -derivedDataPath build build
```

The app lands in `build/Build/Products/Release/`. Set `DEVELOPMENT_TEAM` in `project.yml` to your own team ID to sign it.

## License

[MIT](LICENSE)
