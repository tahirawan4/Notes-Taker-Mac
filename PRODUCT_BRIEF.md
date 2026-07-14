# Meeting Notes Taker for macOS

## Target Device

- Primary platform: macOS on MacBook Pro / Mac Pro class hardware from 2021.
- Meeting apps: Zoom desktop app and browser meetings in Chrome, including Google Meet.
- App shape: modern macOS menu-bar app with a full meeting library window.

## Core Experience

The user can switch the app on before a meeting. When recording starts, the app captures the meeting video, meeting audio, and microphone audio. After the meeting, it produces a polished meeting record with summary notes, decisions, action items, and the full transcript.

## MVP Workflow

1. Open the macOS app.
2. Click `Start Capture`.
3. Choose capture source:
   - Full screen
   - Zoom window
   - Chrome window
4. App records:
   - Video recording
   - Meeting/system audio where permitted
   - Microphone audio
5. Click `Stop`.
6. App transcribes the meeting.
7. App generates:
   - Executive summary
   - Detailed notes
   - Decisions
   - Action items
   - Full transcript
8. User can revisit past meetings and export either notes or the full transcript as PDF.

## Main Screens

### Menu Bar

- Start / stop capture
- Current recording timer
- Quick access to latest meeting
- Open meeting library

### Meeting Library

- Search past meetings
- Filter by date, app, project, or participants
- List cards with:
  - Meeting title
  - Date and duration
  - Source app: Zoom, Chrome, Google Meet
  - Status: Recording, Processing, Ready, Failed
  - Action item count

### Meeting Detail

- Video playback
- Summary tab
- Notes tab
- Action items tab
- Transcript tab
- Export menu:
  - Export meeting notes PDF
  - Export full transcript PDF
  - Export Markdown
  - Export DOCX later

## PDF Export Requirements

The PDF should feel like a modern business report, not a plain transcript dump.

### Notes PDF

- Cover/header section with meeting title, date, duration, and source app.
- Soft modern color palette with high readability:
  - Deep navy text
  - Warm off-white page background
  - Accent colors such as teal, indigo, coral, and amber
- Summary cards for:
  - Key outcomes
  - Decisions
  - Risks / blockers
  - Follow-ups
- Action item table with:
  - Owner
  - Action
  - Due date
  - Priority
  - Status
- Section dividers and subtle badges.

### Full Transcript PDF

- Clean document layout optimized for long reading.
- Timestamps in a muted accent column.
- Speaker labels when available.
- Searchable text.
- Optional appendix with action items and summary at the end.

## Technical Recommendation

### Best Native Approach

Use a native Swift / SwiftUI macOS app.

Reasons:

- Best access to macOS Screen Recording permissions.
- Better integration with ScreenCaptureKit for screen/window video capture.
- Better menu-bar experience.
- More reliable background recording behavior.
- Cleaner path to local files, notifications, and app permissions.

### Capture

- `ScreenCaptureKit` for screen/window capture on modern macOS.
- `AVFoundation` for video/audio writing.
- macOS permissions required:
  - Screen Recording
  - Microphone
  - Accessibility, only if meeting/window detection is automated

### Transcription

Two possible modes:

- Local/private: Whisper.cpp or Apple Speech where suitable.
- Cloud/high accuracy: send audio to a speech-to-text API, then summarize.

### Notes Generation

After transcription, the app should create structured JSON first:

```json
{
  "summary": [],
  "decisions": [],
  "actionItems": [],
  "risks": [],
  "openQuestions": [],
  "transcript": []
}
```

PDFs and UI views should render from this structured data so exports stay consistent.

## Data Model

### Meeting

- id
- title
- startedAt
- endedAt
- duration
- sourceApp
- videoPath
- audioPath
- status
- createdAt
- updatedAt

### Transcript Segment

- id
- meetingId
- startTime
- endTime
- speaker
- text

### Action Item

- id
- meetingId
- owner
- task
- dueDate
- priority
- status
- evidenceTimestamp

## Suggested Build Phases

### Phase 1: Manual Capture MVP

- Native macOS app shell.
- Start / stop recording.
- Save video locally.
- Meeting library with past recordings.
- Basic manual title editing.

### Phase 2: Transcription and Notes

- Extract audio.
- Transcribe meeting.
- Generate summary, decisions, and action items.
- Store transcript and notes locally.

### Phase 3: Modern PDF Export

- Notes PDF export.
- Full transcript PDF export.
- Modern visual design with tables, section cards, badges, and readable typography.

### Phase 4: Smart Meeting Detection

- Detect Zoom meetings.
- Detect Chrome / Google Meet windows.
- Optional calendar integration.
- Auto-suggest meeting titles and participants.

## Important Compliance Note

The app should show a clear recording indicator and should be used only when recording is allowed and participants have consented. Meeting recording laws and company policies vary by region and organization.
