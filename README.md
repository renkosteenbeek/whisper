# WhisperMac

A native transcription app for macOS and iOS, powered by the OpenAI Whisper API.

Drop an audio or video file on the Mac app, or share a Voice Memo from your iPhone, and get a transcript in seconds. Export to TXT, SRT, VTT or JSON.

## Features

- **macOS app** - drag-and-drop transcription with multi-format export
- **iOS app** - persistent library of past transcripts, searchable
- **iOS Share Extension** - transcribe directly from Voice Memos, Files, WhatsApp, or any app that can share audio
- **Multiple Whisper models** - pick whichever fits the job:
  - `whisper-1` - the only model that returns segment timestamps for SRT/VTT export
  - `gpt-4o-transcribe` - best accuracy
  - `gpt-4o-mini-transcribe` - cheapest
  - `gpt-4o-transcribe-diarize` - adds speaker labels
- **Auto re-encoding** - files larger than the OpenAI 25 MB limit are transparently downsampled to mono 16 kHz M4A
- **API key in Keychain** - shared between app and share extension via Keychain access group
- **App Group storage** - transcripts and audio persist in `group.nl.gentle-innovations.whispermac`

## Requirements

- macOS 14+ for the Mac app
- iOS 18+ for the mobile app
- Xcode 16+ and Swift 6
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An OpenAI API key

## Setup

```bash
git clone https://github.com/renkosteenbeek/whisper.git
cd whisper
xcodegen generate
open WhisperMac.xcodeproj
```

### Providing the API key

Two options:

1. **Bundle a default key** - drop a single line file at the repo root before generating:

   ```bash
   echo "sk-proj-..." > openai-key.txt
   xcodegen generate
   ```

   This file is gitignored and gets included as a bundle resource for all targets. The app reads it on first launch and stores it in the Keychain.

2. **Enter in Settings** - leave `openai-key.txt` out, launch the app, open Settings (gear icon) and paste your key.

In both cases the key lives in the macOS/iOS Keychain after first launch and is shared between the iOS app and its Share Extension via a Keychain access group.

## Usage

### macOS

1. Pick the **WhisperMac** scheme in Xcode, Cmd+R
2. Drag any audio or video file onto the drop zone
3. When the row says "Done", click the **Export** menu and pick TXT/SRT/VTT/JSON

### iOS

1. Pick the **WhisperMobile** scheme, choose your iPhone or an iOS Simulator (iPhone 16 Pro Max recommended), Cmd+R
2. From iOS Voice Memos: tap a memo → Share → tap **WhisperMac** in the share sheet
3. The extension queues the file and opens the main app, which transcribes and saves it to the library
4. Or tap **+** in the Library to import a file from the Files app

The Library groups transcripts by date (Today / Yesterday / This Week / Earlier), supports search, swipe-to-delete, and pull-to-refresh.

### Detail screen

Each transcript opens with a metadata row (model, language, duration, date) and a floating bottom bar:

- **Copy** - put the text on the clipboard
- **Share** - iOS share sheet (text)
- **Export** - save as TXT, SRT, VTT or JSON via the Files picker

## Architecture

Single Xcode project with three targets, all generated from `project.yml`:

| Target | Platform | Type | Purpose |
|---|---|---|---|
| `WhisperMac` | macOS 14+ | App | Mac drag-and-drop UI |
| `WhisperMobile` | iOS 18+ | App | iPhone/iPad library and detail UI |
| `WhisperShare` | iOS 18+ | App Extension | Share sheet entry point for audio |

`WhisperMobile` and `WhisperShare` reuse the Mac target's `Models/` and `Services/` (excluding the AppKit-only `ExportService.swift`), so transcription logic lives in one place.

### Cross-process state

- **App Group** `group.nl.gentle-innovations.whispermac` holds shared `transcripts/` (completed JSON), `pending/` (queued from extension), and `media/` (copied audio).
- **Shared Keychain** access group `nl.gentle-innovations.whispermac` keeps the OpenAI key reachable from both the main app and the Share Extension.
- **Shared `UserDefaults`** under the App Group suite stores the default model and language so the Share Extension picks up changes made in the main app's Settings.

### Voice Memo flow

```
Voice Memos → Share → WhisperMac (extension)
  ↓
Extension copies audio to media/<uuid>.m4a
Extension writes pending/<uuid>.json
Extension opens whispermac://process?id=<uuid>
  ↓
Main app receives URL, drains pending queue
JobQueue → AudioPreprocessor (re-encode if >25 MB) → WhisperAPIClient
  ↓
TranscriptStore writes transcripts/<uuid>.json
Library reloads, transcript visible
```

## Project structure

```
project.yml                      XcodeGen manifest, three targets

Shared/                          Cross-platform code used by all targets
├── BundledDefaults.swift          loads openai-key.txt at runtime
├── TranscriptStore.swift          App Group persistence
├── TranscriptExport.swift         TXT/SRT/VTT/JSON renderers
└── WhisperModel+UI.swift          tints + short labels

WhisperMac/                      macOS target
├── WhisperMacApp.swift, ContentView.swift
├── Models/                        AppSettings, JobQueue, TranscriptionJob, TranscriptionResult
├── Services/                      KeychainService, AudioPreprocessor, WhisperAPIClient, ExportService
└── Views/                         DropZoneView, TranscriptionRow, SettingsView, ResultView

WhisperMobile/                   iOS app target
├── WhisperMobileApp.swift
└── Views/                         LibraryView, TranscriptDetailView, SettingsView, EmptyStateView, TranscriptRow, MetadataCapsule

WhisperShare/                    iOS Share Extension target
├── ShareViewController.swift
└── ShareView.swift
```

## Building from the command line

```bash
# macOS
xcodebuild -project WhisperMac.xcodeproj -scheme WhisperMac \
  -destination 'platform=macOS' build

# iOS Simulator
xcodebuild -project WhisperMac.xcodeproj -scheme WhisperMobile \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' build
```

## Distribution

For installation on a physical iPhone you need an Apple ID in Xcode. A free account gives you a 7-day signing certificate (re-install weekly). The Apple Developer Program ($99/year) provides a permanent certificate. The Mac app builds and runs ad-hoc signed without any account.

## Tech stack

Pure Apple frameworks - no external Swift Package dependencies.

- SwiftUI + Observation (`@Observable`, `@Bindable`)
- AVFoundation for audio re-encoding
- URLSession for multipart upload with progress reporting
- Security framework for shared Keychain
- UniformTypeIdentifiers for drop and share predicates
