# NotesTaker System Review Brief

Use this brief as context for a second-opinion review or prompt-improvement pass.

## Product

NotesTaker is a native SwiftUI macOS app for recording meetings, storing meeting records locally, transcribing saved recordings, generating meeting notes/action items, and exporting notes or transcripts as PDF.

The app is intentionally local-first:
- Meeting metadata is stored in Application Support as JSON.
- Recordings are saved as local `.mov` files.
- Audio chunks extracted for transcription are saved locally.
- API keys are stored in macOS Keychain.
- Transcript text is sent to an AI provider only when the user configures a provider key and processes a recording.

## Platform And Build

- Language/tooling: Swift 6, Swift Package Manager.
- Minimum OS: macOS 14.
- Package product: executable `NotesTaker`.
- App packaging: `scripts/install.sh` builds release, creates `dist/NotesTaker.app`, signs with a local signing identity, and optionally copies to `/Applications`.
- Runtime permissions: Screen Recording, Microphone, Speech Recognition. Accessibility is planned/mentioned only for future automatic meeting detection.

## Current Targets

- `NotesTakerApp`: executable target at `Sources/NotesTakerApp`.
- `NotesTakerAppTests`: test target at `Tests/NotesTakerAppTests`.

Current tests cover:
- Clipboard action-item formatting.
- Meeting store empty initialization for tests.
- Corrupt JSON backup before reset.
- Selected meeting restoration.

## App Architecture

### App Entry

`NotesTakerApp.swift` owns top-level observable services:
- `MeetingStore`
- `RecordingService`
- `AISettingsStore`
- `ProcessingCoordinator`

These are injected into both:
- Main `WindowGroup`
- `MenuBarExtra`

### Main UI

`ContentView` composes:
- `RecordingToolbar`
- `NavigationSplitView`
  - `MeetingSidebar`
  - `MeetingDetailView` or empty state

Important UI files:
- `MeetingSidebar.swift`: meeting list, search, add meeting sheet, row selection/delete controls.
- `RecordingToolbar.swift`: source picker, AI settings button, start/stop capture button.
- `MeetingDetailView.swift`: header, recording panel, processing controls, manual notes, notes/actions/transcript tabs, copy/export controls.
- `AISettingsView.swift`: provider/key/model settings.
- `CaptureSourcePickerView.swift`: display/window selection before capture.
- `NotesOverview.swift`, `ActionItemsView.swift`, `TranscriptView.swift`: detail tabs.

## Data Model

`Meeting` is `Identifiable`, `Codable`, `Hashable`.

Main fields:
- `id`
- `title`
- `startedAt`, `endedAt`
- `source`: Zoom, Chrome, Google Meet, Manual
- `status`: Recording, Processing, Ready, Failed
- `videoPath`, `audioPath`
- `summary`
- `decisions`
- `risks`
- `openQuestions`
- `manualNotes`
- `actionItems`
- `transcript`
- `processingMessage`, `processingProgress`
- `createdAt`, `updatedAt`

Other models:
- `TranscriptSegment`
- `MeetingActionItem`
- `CaptureTarget`

## Recording Pipeline

`RecordingService` coordinates start/stop and active meeting state.

`ScreenMovieRecorder` uses:
- ScreenCaptureKit for screen/window capture.
- AVFoundation `AVAssetWriter` for `.mov` output.
- HEVC low-bitrate video when available, H.264 fallback.
- Video is capped to 960px long edge.
- Video frame rate is 10 FPS.
- Video bitrate is scaled and clamped between 220 kbps and 700 kbps.
- Audio is mono AAC at 44.1 kHz and 96 kbps.

Current intent:
- Keep video file sizes small.
- Preserve speech clarity enough for playback and transcription.

Known recording limits:
- Current capture records screen/window and microphone where available.
- System audio capture from Zoom/Chrome is still pending.
- Screen Recording permission can be sticky across rebuilds because of macOS TCC identity behavior.

## Processing Pipeline

`ProcessingCoordinator` is the single UI-facing owner of processing tasks. It:
- Tracks running meeting IDs.
- Starts processing.
- Stops processing.
- Updates `MeetingStore` with progress and final results.

`MeetingProcessingService`:
1. Validates saved recording path.
2. Loads media duration from `AVURLAsset`.
3. Splits audio into 5-minute `.m4a` chunks using `AVAssetExportSession`.
4. Transcribes chunks with Apple Speech (`SFSpeechRecognizer`, `en_US`).
5. Builds transcript segments.
6. Creates local first-pass notes via sentence/keyword extraction.
7. Optionally enhances notes using AI provider settings.

Cancellation:
- Swift task cancellation is checked between stages.
- Audio export cancellation calls `AVAssetExportSession.cancelExport()`.
- Speech cancellation calls `SFSpeechRecognitionTask.cancel()`.

Known processing limits:
- Speech recognition locale is hardcoded to `en_US`.
- Speaker labels are generic (`Speaker`).
- Transcript segmentation is sentence/time distributed, not aligned to actual speech timestamps.
- Long recordings are chunked, but no cleanup policy exists for processed audio directories.

## AI Notes Pipeline

`AISettingsStore` supports:
- Local
- OpenAI
- Claude
- Gemini

Default models:
- OpenAI: `gpt-4.1-mini`
- Claude: `claude-sonnet-4-20250514`
- Gemini: `gemini-3.5-flash`

`AINotesService` calls:
- OpenAI Responses API: `/v1/responses`
- Anthropic Messages API: `/v1/messages`
- Gemini GenerateContent API: `/v1beta/models/{model}:generateContent`

AI output is expected as JSON matching:
- `summary: [String]`
- `decisions: [String]`
- `risks: [String]`
- `openQuestions: [String]`
- `actionItems: [{ owner, task, priority }]`

Current hardening:
- OpenAI request includes JSON schema format.
- Claude request uses a forced tool call with input schema.
- Gemini request uses `responseMimeType: application/json`.
- Response parsing strips code fences and extracts JSON object boundaries when needed.

Known AI limits:
- No token counting or transcript truncation strategy yet.
- No retry/backoff for network/provider errors.
- No provider-specific model availability check in UI.
- No streaming progress from AI providers.

## Persistence

`MeetingStore`:
- Reads/writes `meetings.json` under Application Support.
- Seeds a sample meeting on first launch.
- Recovers interrupted processing states on load.
- Persists selected meeting ID via UserDefaults keyed by store file path.
- Backs up corrupt JSON to `meetings-corrupt-<timestamp>.json` before resetting.

Known persistence limits:
- No schema version/migration layer.
- No user-facing corrupt-store recovery message.
- Recording files are not deleted when meeting records are deleted.
- Processed audio directories are not automatically cleaned up.

## Export And Clipboard

`PDFExporter` creates:
- Meeting notes PDF.
- Full transcript PDF.

`ClipboardFormatter` creates text for:
- Manual notes.
- Meeting notes.
- Action items.
- Transcript.
- Full discussion.

Known export limits:
- PDF generation has no automated visual regression tests.
- Export location/error handling could be made more user-visible.

## Current Validation State

Commands recently passing:

```bash
swift build
swift test
```

Latest test result:
- 7 XCTest tests.
- 0 failures.

Runtime smoke:
- App launches via `swift run`.
- Recording logs confirmed compressed video settings and HEVC low-bitrate path.

## July 18 Hardening Pass

Implemented after the senior-review prompt:

- Added a testable `RecordingStateMachine` so duplicate start/stop transitions are rejected before they can race the recorder.
- Changed recording output to write to a hidden temporary `.mov`, validate it with AVFoundation, then move it into the final meeting path only after it is readable and has duration/video tracks.
- Added validation diagnostics for duration, byte size, video tracks, and audio tracks.
- Kept compact video settings while making audio bitrate an internal quality choice (`96 kbps` speech balanced, `128 kbps` speech high).
- Removed force unwraps in touched provider/file-system paths (`Application Support`, AI provider URLs, AI action owners, capture window titles).
- Added XCTest coverage for the recording state lifecycle and duplicate transition rejection.

Current important recording tradeoff:

- Video remains aggressively compressed for minimum file size: 960px long edge, 10 FPS, HEVC when available, H.264 fallback.
- Audio remains speech-oriented AAC mono at 44.1 kHz / 96 kbps. If real meeting playback/transcription is still weak, the next small change is to switch the internal `AudioQuality` from `speechBalanced` to `speechHigh` at 128 kbps and compare file size versus transcription quality.

## Highest-Value Refinement Areas

1. **System audio capture**
   Add reliable capture of meeting/system audio from Zoom/Chrome/Google Meet, with clear permission onboarding and fallbacks.

2. **Audio/transcription quality**
   Test speech quality with 44.1 kHz / 96 kbps mono. Consider 128 kbps mono if transcription or playback is still poor.

3. **Processing reliability**
   Add cleanup for stale audio chunks. Add retry/backoff for provider calls. Add user-visible recovery messages.

4. **Transcription accuracy**
   Support locale selection, on-device/cloud speech configuration, and better timestamp alignment.

5. **Speaker diarization**
   Add a provider or local approach for speaker labels instead of generic `Speaker`.

6. **AI robustness**
   Add transcript chunk summarization for long meetings, structured-output tests, model validation, and clearer provider errors.

7. **SwiftUI performance**
   Continue extracting large computed subviews in `MeetingDetailView` into standalone `View` structs with narrow inputs.

8. **Testing**
   Add tests for AI JSON parsing, meeting processing local note extraction, corrupted store recovery edge cases, and PDF generation smoke output.

9. **Packaging**
   Add CI build/test checks and optionally generate a signed/notarized release artifact.

## Suggested Claude Prompt

```text
You are reviewing a SwiftUI macOS app called NotesTaker. It records meetings, stores local meeting records, transcribes recordings with Apple Speech, optionally enhances notes via OpenAI/Claude/Gemini, and exports notes/transcripts as PDF.

Use the system brief below as source context. Please give a senior-engineer second opinion focused on:
1. Correctness risks and bugs.
2. SwiftUI architecture/performance issues.
3. AVFoundation/ScreenCaptureKit recording and audio-quality tradeoffs.
4. Speech transcription reliability.
5. AI provider integration and structured output robustness.
6. Privacy/security concerns around local recordings, key storage, and transcript upload.
7. A prioritized implementation roadmap.

Do not rewrite the whole app. Give concrete, incremental changes with file-level suggestions and explain why each one matters.

[Paste SYSTEM_REVIEW_BRIEF.md here]
```

## Prompt For Enhancement Suggestions

```text
Based on this NotesTaker system brief, propose a better product and engineering prompt I can give to a coding agent. The prompt should ask the agent to improve the app in small safe commits, validate each change with SwiftPM build/tests, avoid broad rewrites, preserve local-first privacy, and focus first on recording/transcription reliability.
```
