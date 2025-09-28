import Combine
import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(Photos)
import Photos
#endif

@MainActor
final class DrivingPracticeViewModel: ObservableObject {
    @Published private(set) var sessions: [DrivingSession]
    @Published private(set) var activeSession: DrivingSession?
    @Published var wantsRouteTracking: Bool
    @Published var wantsAudioRecording: Bool
    @Published var elapsedTime: TimeInterval = 0
    @Published var showCompletionSheet: Bool = false
    @Published var amountInput: String = ""
    @Published var noteDraft: String = ""
    @Published var attachments: [NoteAttachment] = []

    let isLocationServiceAvailable: Bool
    let isAudioRecordingAvailable: Bool

    private let sessionStore: DrivingSessionStore
    private let notesStore: NotesStore
    private let locationService: LocationService
    private let audioService: AudioRecordingService
    private let speechService: EnhancedSpeechRecognitionService?
    private let videoExporter: DrivingSessionVideoExporter?

    let availableTranscriptionLocales: [Locale] = [
        Locale(identifier: "de-DE"),
        Locale(identifier: "en-US"),
        Locale(identifier: "zh-CN")
    ]

    var isSpeechServiceAvailable: Bool {
        speechService?.isAvailable ?? false
    }

    var supportedSpeechLanguages: [SpeechLanguage] {
        speechService?.supportedLanguages ?? []
    }

    private var timerCancellable: AnyCancellable?
    private var storeCancellables = Set<AnyCancellable>()
    private var recordedAudioURL: URL?

    init(sessionStore: DrivingSessionStore,
         notesStore: NotesStore,
         locationService: LocationService,
         audioService: AudioRecordingService,
         speechService: EnhancedSpeechRecognitionService?,
         videoExporter: DrivingSessionVideoExporter?) {
        self.sessionStore = sessionStore
        self.notesStore = notesStore
        self.locationService = locationService
        self.audioService = audioService
        self.speechService = speechService
        self.videoExporter = videoExporter
        self.sessions = sessionStore.sessions
        self.activeSession = sessionStore.activeSession

        self.isLocationServiceAvailable = locationService.isAvailable
        self.isAudioRecordingAvailable = audioService.isRecordingSupported

        self.wantsRouteTracking = locationService.isAvailable
        self.wantsAudioRecording = audioService.isRecordingSupported

        sessionStore.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.sessions = $0 }
            .store(in: &storeCancellables)

        sessionStore.$activeSession
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                self?.activeSession = session
                self?.handleActiveSessionChange()
            }
            .store(in: &storeCancellables)

        locationService.routeSamplePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sample in
                self?.sessionStore.appendRouteSample(sample)
            }
            .store(in: &storeCancellables)
    }

    @Published private(set) var isVideoExporting: Bool = false
    @Published private(set) var videoExportProgress: Double = 0
    @Published private(set) var activeVideoExportSessionID: UUID?
    @Published private(set) var completedVideoExport: (sessionID: UUID, url: URL)?
    @Published private(set) var videoExportError: String?
    @Published private(set) var videoExportSuccessMessage: String?

    func startSession() {
        guard activeSession == nil else { return }
        Task { @MainActor in
            var routeTracking = wantsRouteTracking && isLocationServiceAvailable
            var audioRecording = wantsAudioRecording && isAudioRecordingAvailable

            if routeTracking {
                let granted = await locationService.requestAuthorization()
                routeTracking = granted
                if !granted { wantsRouteTracking = false }
            }

            if audioRecording {
                let granted = await audioService.requestPermission()
                audioRecording = granted
                if !granted { wantsAudioRecording = false }
            }

            sessionStore.startSession(routeTracking: routeTracking, recordAudio: audioRecording)
            attachments = []
            noteDraft = ""
            amountInput = ""

            if routeTracking {
                locationService.startTracking()
            }

            if audioRecording {
                do {
                    let startTimestamp = Date()
                    recordedAudioURL = try audioService.startRecording()
                    sessionStore.markAudioRecordingStarted(at: startTimestamp)
                    sessionStore.updateAudioFileURL(recordedAudioURL)
                } catch {
                    audioService.cancelRecording()
                    recordedAudioURL = nil
                    sessionStore.updateAudioFileURL(nil)
                    wantsAudioRecording = false
                }
            } else {
                recordedAudioURL = nil
            }

            handleActiveSessionChange()
        }
    }

    func stopSession() {
        guard activeSession != nil else { return }
        locationService.stopTracking()
        if let session = activeSession, session.audio.isEnabled {
            recordedAudioURL = audioService.stopRecording() ?? recordedAudioURL
            sessionStore.updateAudioFileURL(recordedAudioURL)
        } else {
            audioService.cancelRecording()
        }
        sessionStore.markActiveSessionEnded()
        amountInput = ""
        noteDraft = ""
        attachments = []
        showCompletionSheet = true
    }

    func confirmCompletion() {
        guard activeSession != nil else { return }
        let normalized = amountInput.replacingOccurrences(of: ",", with: ".")
        let amount = Decimal(string: normalized)

        var noteAttachments = persistAttachmentsIfNeeded(attachments)
        var finalizedAudioURL: URL? = nil
        if let audioURL = recordedAudioURL {
            finalizedAudioURL = persistRecordingIfNeeded(at: audioURL)
            if let storedURL = finalizedAudioURL {
                noteAttachments.append(NoteAttachment(kind: .audio, resourceURL: storedURL))
            }
        }

        let body = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        var noteID: UUID? = nil
        if !body.isEmpty || !noteAttachments.isEmpty {
            let note = UserNote(category: .practice,
                                body: body,
                                practiceSessionID: activeSession?.id,
                                attachments: noteAttachments)
            notesStore.add(note: note)
            noteID = note.id
        }

        let audioURLForSession = finalizedAudioURL ?? recordedAudioURL
        let completedSession = sessionStore.finishSession(amountPaid: amount, noteID: noteID, audioURL: audioURLForSession)
        attachments = []
        noteDraft = ""
        amountInput = ""
        recordedAudioURL = nil
        showCompletionSheet = false

    }

    func cancelCompletion() {
        showCompletionSheet = false
    }

    func addSketchAttachment() {
        attachments.append(NoteAttachment(kind: .sketch))
    }

    func addImageAttachment(url: URL) {
        attachments.append(NoteAttachment(kind: .image, resourceURL: url))
    }

    func removeAttachment(_ attachment: NoteAttachment) {
        attachments.removeAll { $0.id == attachment.id }
    }

    func session(with id: UUID) -> DrivingSession? {
        if let active = activeSession, active.id == id { return active }
        if let stored = sessionStore.session(with: id) { return stored }
        return sessions.first { $0.id == id }
    }

    func transcribe(sessionID: UUID, language: SpeechLanguage) async throws {
        guard let speechService else {
            throw SpeechRecognitionError.recognizerUnavailable
        }
        guard let session = session(with: sessionID), let audioURL = session.audio.fileURL else {
            throw SpeechRecognitionError.recognizerUnavailable
        }
        await transcribeRecording(for: sessionID,
                                  audioURL: audioURL,
                                  language: language,
                                  speechService: speechService)
    }

    func note(for session: DrivingSession) -> UserNote? {
        guard let noteID = session.noteID else { return nil }
        return notesStore.notes.first { $0.id == noteID }
    }

    func recordingURL(for session: DrivingSession) -> URL? {
        let url = session.audio.fileURL
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func canExportVideo(for session: DrivingSession) -> Bool {
        videoExporter != nil && session.routeSamples.count > 1
    }

    func isVideoExportInProgress(for session: DrivingSession) -> Bool {
        isVideoExporting && activeVideoExportSessionID == session.id
    }

    func currentVideoExportProgress(for session: DrivingSession) -> Double {
        isVideoExportInProgress(for: session) ? videoExportProgress : 0
    }

    func exportedVideoURL(for session: DrivingSession) -> URL? {
        guard let export = completedVideoExport, export.sessionID == session.id else { return nil }
        return export.url
    }

    func clearCompletedVideoExport() {
        completedVideoExport = nil
    }

    func exportVideo(for session: DrivingSession, includeAudio: Bool) {
        guard let exporter = videoExporter else { return }
        isVideoExporting = true
        videoExportProgress = 0
        activeVideoExportSessionID = session.id
        videoExportError = nil
        completedVideoExport = nil
        videoExportSuccessMessage = nil

        let options = DrivingSessionVideoExportOptions(includeAudio: includeAudio,
                                                       canvasSize: CGSize(width: 1080, height: 1920),
                                                       framesPerSecond: 30)

        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let url = try await exporter.export(session: session,
                                                     options: options,
                                                     progressHandler: { progress in
                                                         DispatchQueue.main.async { [weak self] in
                                                             self?.videoExportProgress = progress
                                                         }
                                                     })
#if canImport(Photos)
                do {
                    try await self.saveVideoToPhotoLibrary(url)
                    await MainActor.run {
                        self.completedVideoExport = (session.id, url)
                        self.videoExportProgress = 1
                        self.isVideoExporting = false
                        self.activeVideoExportSessionID = nil
                        self.videoExportSuccessMessage = "视频已保存至相册"
                    }
                } catch {
                    await MainActor.run {
                        self.videoExportError = error.localizedDescription
                        self.isVideoExporting = false
                        self.activeVideoExportSessionID = nil
                        self.videoExportProgress = 0
                    }
                }
#else
                await MainActor.run {
                    self.completedVideoExport = (session.id, url)
                    self.videoExportProgress = 1
                    self.isVideoExporting = false
                    self.activeVideoExportSessionID = nil
                    self.videoExportSuccessMessage = "视频已导出"
                }
#endif
            } catch {
                await MainActor.run {
                    self.videoExportError = error.localizedDescription
                    self.isVideoExporting = false
                    self.activeVideoExportSessionID = nil
                    self.videoExportProgress = 0
                }
            }
        }
    }

    func renameSession(_ session: DrivingSession, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized: String? = {
            if trimmed.isEmpty { return nil }
            if trimmed == session.defaultTitle { return nil }
            return trimmed
        }()

        if session.customTitle == normalized {
            return
        }

        sessionStore.renameSession(with: session.id, title: normalized)
    }

    func clearCustomTitle(_ session: DrivingSession) {
        guard session.customTitle != nil else { return }
        sessionStore.renameSession(with: session.id, title: nil)
    }

    func deleteSession(_ session: DrivingSession) {
        guard let removed = sessionStore.deleteSession(with: session.id) else { return }
        if let noteID = removed.noteID,
           let note = notesStore.notes.first(where: { $0.id == noteID }) {
            cleanupNoteAttachments(note)
            notesStore.remove(noteID: noteID)
        }
        cleanupSessionMedia(removed)
    }

    var totalSessionsCount: Int {
        sessions.count
    }

    var audioRecordingStatus: String? {
        guard let active = activeSession, active.audio.isEnabled else { return nil }
        if let _ = recordedAudioURL ?? active.audio.fileURL {
            return "录音已就绪"
        }
        return "录音进行中"
    }

    var recordedAudioDurationText: String? {
#if canImport(AVFoundation)
        guard let url = recordedAudioURL ?? activeSession?.audio.fileURL else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            let seconds = player.duration
            guard seconds.isFinite else { return nil }
            return Self.durationFormatter.string(from: seconds)
        } catch {
            return nil
        }
#else
        return nil
#endif
    }

    private func handleActiveSessionChange() {
        timerCancellable?.cancel()
        timerCancellable = nil

        guard let session = activeSession else {
            elapsedTime = 0
            return
        }

        elapsedTime = session.duration
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let session = self.sessionStore.activeSession else { return }
                self.elapsedTime = session.duration
            }
    }
    private func persistAttachmentsIfNeeded(_ attachments: [NoteAttachment]) -> [NoteAttachment] {
        attachments.map { attachment in
            guard let url = attachment.resourceURL else { return attachment }
            switch attachment.kind {
            case .image:
                if let stored = persistFile(at: url, subdirectory: "Images") {
                    return NoteAttachment(id: attachment.id, kind: attachment.kind, resourceURL: stored)
                }
            case .sketch:
                if let stored = persistFile(at: url, subdirectory: "Sketches") {
                    return NoteAttachment(id: attachment.id, kind: attachment.kind, resourceURL: stored)
                }
            case .audio:
                break
            }
            return attachment
        }
    }

    private func persistRecordingIfNeeded(at url: URL) -> URL? {
        persistFile(at: url, subdirectory: "Audio", preferredExtension: url.pathExtension.isEmpty ? "m4a" : url.pathExtension)
    }

    private func persistFile(at url: URL, subdirectory: String, preferredExtension: String? = nil) -> URL? {
        guard url.isFileURL else { return url }
        let fileManager = FileManager.default
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let directory = documents.appendingPathComponent("PracticeMedia/\(subdirectory)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let trimmedPreferred = preferredExtension?.trimmingCharacters(in: CharacterSet(charactersIn: ".")) ?? ""
            let fallbackExtension = url.pathExtension
            let finalExtension: String
            if !trimmedPreferred.isEmpty {
                finalExtension = trimmedPreferred
            } else if !fallbackExtension.isEmpty {
                finalExtension = fallbackExtension
            } else {
                finalExtension = ""
            }
            let filename: String
            if finalExtension.isEmpty {
                filename = UUID().uuidString
            } else {
                filename = UUID().uuidString + "." + finalExtension
            }
            let destination = directory.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: url, to: destination)
            return destination
        } catch {
            NSLog("Failed to persist media: \(error.localizedDescription)")
            return url
        }
    }

#if canImport(AVFoundation)
    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        formatter.unitsStyle = .positional
        return formatter
    }()
#endif
}

#if canImport(Photos)
private enum VideoExportSaveError: LocalizedError {
    case photosAccessDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .photosAccessDenied:
            return "无权保存到相册，请在系统设置中授权后重试。"
        case .saveFailed:
            return "视频保存到相册失败，请稍后再试。"
        }
    }
}
#endif

extension DrivingPracticeViewModel {
    private func cleanupSessionMedia(_ session: DrivingSession) {
        deleteFileIfExists(at: session.audio.fileURL)
    }

    private func cleanupNoteAttachments(_ note: UserNote) {
        note.attachments
            .compactMap(\.resourceURL)
            .forEach { deleteFileIfExists(at: $0) }
    }

    private func deleteFileIfExists(at url: URL?) {
        guard let url, url.isFileURL else { return }
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                NSLog("Failed to delete media at \(url): \(error.localizedDescription)")
            }
        }
    }

#if canImport(Photos)
    private func saveVideoToPhotoLibrary(_ url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw VideoExportSaveError.photosAccessDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: VideoExportSaveError.saveFailed)
                }
            }
        }
    }
#endif

    private func transcribeRecording(for sessionID: UUID,
                                     audioURL: URL,
                                     language: SpeechLanguage,
                                     speechService: EnhancedSpeechRecognitionService) async {
        let authorized = await speechService.requestAuthorization()
        guard authorized else {
            NSLog("Speech transcription skipped: authorization denied")
            return
        }

        do {
            let result = try await speechService.transcribeAudioWithTimestamps(at: audioURL, language: language)
            let trimmed = result.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                NSLog("Speech transcription produced empty output")
                return
            }
            
            let segments = result.segments.map {
                DrivingSession.AudioTranscriptSegment(
                    startOffset: $0.startTime,
                    duration: $0.endTime - $0.startTime,
                    text: $0.text
                )
            }

            await MainActor.run {
                sessionStore.updateTranscript(
                    result.fullText,
                    segments: segments,
                    languageCode: language.locale.identifier,
                    for: sessionID
                )
            }
        } catch {
            NSLog("Speech transcription failed for language \(language.displayName): \(error.localizedDescription)")
        }
    }
}
