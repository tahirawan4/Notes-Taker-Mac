# NotesTaker for macOS

NotesTaker is a native SwiftUI macOS app for meeting notes, transcripts, action items, meeting history, and modern PDF exports.

It is designed for a Mac workflow where you can keep a lightweight meeting assistant available from the menu bar, review past meetings, and export either clean meeting notes or a full transcript as PDF.

## Features

- Native macOS SwiftUI interface
- Menu-bar start/stop controls
- Meeting library with past records
- Meeting detail screen with video area, notes, action items, and transcript tabs
- Local meeting storage in macOS Application Support
- Modern PDF export for:
  - meeting notes
  - full transcript
- Sample meeting included on first launch so the UI and PDF export can be tested immediately

## Requirements

- macOS 14 or newer
- Xcode command line tools or Xcode
- Swift 6 compatible toolchain

Check your Swift install:

```bash
swift --version
```

## Clone

```bash
git clone git@github.com:tahirawan4/Notes-Taker-Mac.git
cd Notes-Taker-Mac
```

## Install

Run the installer script:

```bash
./scripts/install.sh
```

The script will:

1. Build NotesTaker in release mode.
2. Create `dist/NotesTaker.app`.
3. Ask whether to copy the app to `/Applications`.

After installation, open:

```text
/Applications/NotesTaker.app
```

If you skip the `/Applications` copy, open:

```text
dist/NotesTaker.app
```

## Run Without Installing

For development, you can run directly from Swift Package Manager:

```bash
swift run NotesTaker
```

## Build

```bash
swift build
```

For a release build:

```bash
swift build -c release
```

## App Permissions

The current app includes the meeting library, notes UI, transcript UI, action items, and PDF export pipeline.

When live recording is connected, macOS may ask for:

- Screen Recording
- Microphone
- Accessibility, only for automatic Zoom or Chrome meeting detection

## Current Recording Status

The current `RecordingService` manages meeting capture state and creates meeting records. The next engineering step is wiring it to native macOS capture APIs:

- `ScreenCaptureKit` for screen/window recording
- `AVFoundation` for writing video and audio files
- A transcription provider for generating transcript segments, summaries, and action items

## Product Plan

See [PRODUCT_BRIEF.md](PRODUCT_BRIEF.md) for the full product direction, including Zoom/Chrome capture, transcription, notes generation, and PDF design.
