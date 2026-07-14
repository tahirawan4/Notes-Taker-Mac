# NotesTaker for macOS

NotesTaker is a native SwiftUI macOS app for meeting notes, transcripts, action items, meeting history, and modern PDF exports.

It is designed for a Mac workflow where you can keep a lightweight meeting assistant available from the menu bar, review past meetings, and export either clean meeting notes or a full transcript as PDF.

## Features

- Native macOS SwiftUI interface
- Menu-bar start/stop controls
- Capture source picker for full screen or a specific window
- Meeting library with past records
- Meeting detail screen with video area, notes, action items, and transcript tabs
- Local meeting storage in macOS Application Support
- Local screen recording saved as `.mov`
- Optional AI-enhanced notes using the user's own OpenAI or Claude API key
- Modern PDF export for:
  - meeting notes
  - full transcript
- Sample meeting included on first launch so the UI and PDF export can be tested immediately

## Requirements

- macOS 14 or newer

For direct app download, Xcode is not required.

For building from source:

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

## Install From Downloaded App

Download the packaged app from this repository:

```text
artifacts/NotesTaker-macOS.zip
```

Then:

1. Unzip `NotesTaker-macOS.zip`.
2. Move `NotesTaker.app` into `/Applications`.
3. Open `/Applications/NotesTaker.app`.

If macOS blocks the app because it was downloaded from GitHub, right-click `NotesTaker.app`, choose **Open**, then confirm.

## Install From Source

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

To install directly into `/Applications` without the prompt:

```bash
./scripts/install.sh --applications
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

When recording, macOS may ask for:

- Screen Recording
- Microphone
- Speech Recognition
- Accessibility, only for automatic Zoom or Chrome meeting detection

## Optional AI Notes

NotesTaker works without any AI API key. In local mode, it uses Apple Speech for transcription and built-in rules for first-pass notes/action items.

For stronger summaries and cleaner action items:

1. Open NotesTaker.
2. Click the gear/sparkle button in the top toolbar.
3. Choose `OpenAI` or `Claude`.
4. Paste your API key.
5. Save settings.
6. Open a saved meeting and click **Process Recording**.

API keys are stored in macOS Keychain. Transcript text is sent to the selected AI provider only when a key is configured and the user processes a recording.

## Current Recording Status

The current `RecordingService` records either the full screen or a selected window, plus microphone audio where available, to a local `.mov` file using native macOS capture APIs. Meeting records link to the saved video so it can be opened or revealed in Finder.

Saved recordings can be processed with the **Process Recording** button. The current processing flow extracts audio from the saved recording, uses Apple Speech for transcription, and generates first-pass notes and action items. If an OpenAI or Claude key is configured, NotesTaker sends the transcript to that provider for improved summary, decisions, risks, questions, and action items.

Still pending / limited:

- System audio capture from Chrome/Zoom
- Higher-quality AI summarization
- Speaker identification

## Product Plan

See [PRODUCT_BRIEF.md](PRODUCT_BRIEF.md) for the full product direction, including Zoom/Chrome capture, transcription, notes generation, and PDF design.
