@preconcurrency import AVFoundation
import Foundation
import Speech

enum MeetingProcessingError: LocalizedError {
    case missingRecording
    case audioExportFailed(String)
    case speechUnavailable
    case speechDenied
    case transcriptionFailed(String)
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .missingRecording:
            "This meeting has no saved recording to process."
        case .audioExportFailed(let detail):
            "Could not extract audio from the recording: \(detail)"
        case .speechUnavailable:
            "Apple Speech recognition is not available right now."
        case .speechDenied:
            "Speech Recognition permission is required. Enable it in System Settings, then process the recording again."
        case .transcriptionFailed(let detail):
            "Transcription failed: \(detail)"
        case .emptyTranscript:
            "No speech was detected in the recording. Make sure microphone audio was captured."
        }
    }
}

struct MeetingProcessingService {
    struct ProgressUpdate: Sendable {
        var message: String
        var fraction: Double
    }

    typealias ProgressHandler = @Sendable (ProgressUpdate) async -> Void

    func process(_ meeting: Meeting, progress: ProgressHandler? = nil) async throws -> Meeting {
        guard let videoPath = meeting.videoPath else {
            throw MeetingProcessingError.missingRecording
        }

        let videoURL = URL(filePath: videoPath)
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw MeetingProcessingError.missingRecording
        }

        try Task.checkCancellation()
        let asset = AVURLAsset(url: videoURL)
        let assetDuration = try await asset.load(.duration)
        let totalDuration = max(CMTimeGetSeconds(assetDuration), meeting.duration, 1)
        let chunkedResult = try await transcribeInChunks(
            asset: asset,
            meetingID: meeting.id,
            totalDuration: totalDuration,
            progress: progress
        )
        let transcriptText = chunkedResult.transcript
        let cleaned = transcriptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw MeetingProcessingError.emptyTranscript
        }

        try Task.checkCancellation()
        await report("Building transcript sections...", 0.72, progress)
        var processed = meeting
        processed.audioPath = chunkedResult.audioDirectory.path
        processed.status = .ready
        processed.transcript = makeTranscriptSegments(from: cleaned, duration: totalDuration)
        try Task.checkCancellation()
        await report("Extracting summary and action items...", 0.82, progress)
        let notes = makeLocalNotes(from: cleaned)
        processed.summary = notes.summary
        processed.decisions = notes.decisions
        processed.risks = notes.risks
        processed.openQuestions = notes.openQuestions
        processed.actionItems = notes.actionItems

        if processed.summary.isEmpty {
            processed.summary = ["Transcript generated successfully. Review the transcript tab for details."]
        }

        let settings = AISettingsStore.currentSnapshot()
        if settings.isAIEnabled {
            do {
                try Task.checkCancellation()
                await report("Enhancing notes with AI...", 0.90, progress)
                processed = try await AINotesService().enhance(meeting: processed, transcript: cleaned, settings: settings)
            } catch {
                processed.openQuestions.append("AI enhancement was skipped: \(error.localizedDescription)")
            }
        }

        await report("Processing complete.", 1.0, progress)
        return processed
    }

    private func report(_ message: String, _ fraction: Double, _ progress: ProgressHandler?) async {
        await progress?(ProgressUpdate(message: message, fraction: fraction))
    }

    private func transcribeInChunks(
        asset: AVURLAsset,
        meetingID: UUID,
        totalDuration: TimeInterval,
        progress: ProgressHandler?
    ) async throws -> ChunkedTranscriptionResult {
        let chunkLength: TimeInterval = 300
        let chunkCount = max(1, Int(ceil(totalDuration / chunkLength)))
        let audioDirectory = try prepareChunkDirectory(meetingID: meetingID)
        var transcripts: [String] = []

        await report("Splitting recording into \(chunkCount) audio chunk\(chunkCount == 1 ? "" : "s")...", 0.10, progress)

        for index in 0..<chunkCount {
            try Task.checkCancellation()
            let start = Double(index) * chunkLength
            let duration = min(chunkLength, totalDuration - start)
            let current = index + 1
            let baseProgress = 0.12 + (Double(index) / Double(chunkCount)) * 0.56

            await report("Exporting audio chunk \(current) of \(chunkCount)...", baseProgress, progress)
            let chunkURL = try await exportAudioChunk(
                asset: asset,
                meetingID: meetingID,
                index: current,
                start: start,
                duration: duration,
                directory: audioDirectory
            )

            try Task.checkCancellation()
            await report("Transcribing chunk \(current) of \(chunkCount)...", baseProgress + (0.28 / Double(chunkCount)), progress)
            let chunkText: String
            do {
                chunkText = try await transcribe(audioURL: chunkURL).trimmingCharacters(in: .whitespacesAndNewlines)
            } catch MeetingProcessingError.transcriptionFailed {
                await report("Chunk \(current) had no usable speech. Continuing...", baseProgress + (0.40 / Double(chunkCount)), progress)
                continue
            }
            if !chunkText.isEmpty {
                transcripts.append(chunkText)
            }
        }

        return ChunkedTranscriptionResult(
            audioDirectory: audioDirectory,
            transcript: transcripts.joined(separator: " ")
        )
    }

    private func exportAudioChunk(
        asset: AVURLAsset,
        meetingID: UUID,
        index: Int,
        start: TimeInterval,
        duration: TimeInterval,
        directory: URL
    ) async throws -> URL {
        let outputURL = directory.appending(path: "\(meetingID.uuidString)-chunk-\(String(format: "%03d", index)).m4a")
        try? FileManager.default.removeItem(at: outputURL)

        let cancellation = MediaCancellationState()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                    continuation.resume(throwing: MeetingProcessingError.audioExportFailed("Audio export session could not be created."))
                    return
                }
                cancellation.setExportSession(session)
                session.outputURL = outputURL
                session.outputFileType = .m4a
                session.shouldOptimizeForNetworkUse = false
                session.timeRange = CMTimeRange(
                    start: CMTime(seconds: start, preferredTimescale: 600),
                    duration: CMTime(seconds: duration, preferredTimescale: 600)
                )

                session.exportAsynchronously {
                    switch cancellation.exportStatus {
                    case .completed:
                        continuation.resume(returning: outputURL)
                    case .cancelled:
                        continuation.resume(throwing: CancellationError())
                    case .failed:
                        continuation.resume(throwing: MeetingProcessingError.audioExportFailed(cancellation.exportErrorMessage ?? "Unknown export error."))
                    default:
                        continuation.resume(throwing: MeetingProcessingError.audioExportFailed("Export ended with status \(cancellation.exportStatus.rawValue)."))
                    }
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    private func prepareChunkDirectory(meetingID: UUID) throws -> URL {
        let directory = try processingDirectory()
            .appending(path: meetingID.uuidString, directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func transcribe(audioURL: URL) async throws -> String {
        let status = await requestSpeechAuthorization()
        try Task.checkCancellation()
        guard status == .authorized else {
            throw MeetingProcessingError.speechDenied
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US")), recognizer.isAvailable else {
            throw MeetingProcessingError.speechUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false

        let cancellation = MediaCancellationState()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                let task = recognizer.recognitionTask(with: request) { result, error in
                    if let result, result.isFinal {
                        cancellation.resumeOnce {
                            continuation.resume(returning: result.bestTranscription.formattedString)
                        }
                    } else if let error {
                        cancellation.resumeOnce {
                            if cancellation.isCancelled {
                                continuation.resume(throwing: CancellationError())
                            } else {
                                continuation.resume(throwing: MeetingProcessingError.transcriptionFailed(error.localizedDescription))
                            }
                        }
                    }
                }
                cancellation.setSpeechTask(task)
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func makeTranscriptSegments(from text: String, duration: TimeInterval) -> [TranscriptSegment] {
        let parts = sentences(from: text)
        guard !parts.isEmpty else {
            return [TranscriptSegment(startTime: 0, endTime: duration, speaker: "Speaker", text: text)]
        }

        let segmentLength = max(duration / Double(parts.count), 1)
        return parts.enumerated().map { index, sentence in
            let start = Double(index) * segmentLength
            return TranscriptSegment(
                startTime: start,
                endTime: min(start + segmentLength, duration),
                speaker: "Speaker",
                text: sentence
            )
        }
    }

    private func makeLocalNotes(from text: String) -> LocalNotes {
        let all = sentences(from: text)
        let decisions = findSentences(
            in: text,
            matching: ["decided", "decision", "agreed to", "approved", "confirmed", "signed off", "finalized"]
        )
        let risks = findSentences(
            in: text,
            matching: ["risk", "blocked", "blocker", "issue", "problem", "concern", "delay", "dependency", "challenge"]
        )
        let openQuestions = all.filter { $0.contains("?") }.prefixArray(4)
        let actionItems = makeActionItems(from: text)

        let reserved = Set((decisions + risks + openQuestions + actionItems.map(\.task)).map(normalized))
        let summary = makeSummary(from: text, excluding: reserved)

        return LocalNotes(
            summary: summary,
            decisions: decisions,
            risks: risks,
            openQuestions: openQuestions,
            actionItems: actionItems
        )
    }

    private func makeSummary(from text: String, excluding reserved: Set<String>) -> [String] {
        let all = sentences(from: text)
        let available = all.filter { !reserved.contains(normalized($0)) }
        let priority = all.filter { sentence in
            !reserved.contains(normalized(sentence)) &&
            contains(sentence, anyOf: ["discussed", "reviewed", "covered", "talked about", "plan", "priority", "progress", "update", "goal"])
        }

        let chosen = (priority.isEmpty ? available : priority).prefixArray(5)
        if chosen.isEmpty, let first = all.first {
            return ["The discussion covered: \(first)"]
        }
        return chosen.map { $0 }
    }

    private func makeActionItems(from text: String) -> [MeetingActionItem] {
        let actionSentences = findSentences(
            in: text,
            matching: ["action", "todo", "to do", "follow up", "need to", "needs to", "please", "should", "we will", "we'll", "i will", "i'll", "next step", "assign", "send", "share"]
        )

        return actionSentences.prefix(8).map { sentence in
            MeetingActionItem(
                owner: guessOwner(from: sentence),
                task: sentence,
                dueDate: nil,
                priority: contains(sentence, anyOf: ["urgent", "important", "asap", "today", "tomorrow"]) ? .high : .medium,
                status: .open,
                evidenceTimestamp: nil
            )
        }
    }

    private func guessOwner(from sentence: String) -> String {
        let lowercased = sentence.lowercased()
        if lowercased.contains(" i will ") || lowercased.hasPrefix("i will") {
            return "Me"
        }
        if lowercased.contains(" we will ") || lowercased.hasPrefix("we will") {
            return "Team"
        }
        return "Unassigned"
    }

    private func findSentences(in text: String, matching keywords: [String]) -> [String] {
        sentences(from: text).filter { contains($0, anyOf: keywords) }.prefixArray(6)
    }

    private func contains(_ sentence: String, anyOf keywords: [String]) -> Bool {
        let value = sentence.lowercased()
        return keywords.contains { value.contains($0) }
    }

    private func normalized(_ sentence: String) -> String {
        sentence
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
    }

    private func sentences(from text: String) -> [String] {
        let pattern = #"[^.!?\n]+[.!?]?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [text]
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            let sentence = text[matchRange].trimmingCharacters(in: .whitespacesAndNewlines)
            return sentence.isEmpty ? nil : sentence
        }
    }

    private func processingDirectory() throws -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = baseURL
            .appending(path: "NotesTaker", directoryHint: .isDirectory)
            .appending(path: "ProcessedAudio", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private extension Array {
    func prefixArray(_ maxLength: Int) -> [Element] {
        Array(prefix(maxLength))
    }
}

private struct LocalNotes {
    var summary: [String]
    var decisions: [String]
    var risks: [String]
    var openQuestions: [String]
    var actionItems: [MeetingActionItem]
}

private struct ChunkedTranscriptionResult {
    var audioDirectory: URL
    var transcript: String
}

private final class MediaCancellationState: @unchecked Sendable {
    private let lock = NSLock()
    private var exportSession: AVAssetExportSession?
    private var speechTask: SFSpeechRecognitionTask?
    private var didResume = false
    private(set) var isCancelled = false

    var exportStatus: AVAssetExportSession.Status {
        lock.lock()
        defer { lock.unlock() }
        return exportSession?.status ?? .unknown
    }

    var exportErrorMessage: String? {
        lock.lock()
        defer { lock.unlock() }
        return exportSession?.error?.localizedDescription
    }

    func setExportSession(_ session: AVAssetExportSession) {
        lock.lock()
        exportSession = session
        let shouldCancel = isCancelled
        lock.unlock()
        if shouldCancel {
            session.cancelExport()
        }
    }

    func setSpeechTask(_ task: SFSpeechRecognitionTask) {
        lock.lock()
        speechTask = task
        let shouldCancel = isCancelled
        lock.unlock()
        if shouldCancel {
            task.cancel()
        }
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let session = exportSession
        let task = speechTask
        lock.unlock()
        session?.cancelExport()
        task?.cancel()
    }

    func resumeOnce(_ action: () -> Void) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }
        didResume = true
        lock.unlock()
        action()
    }
}
