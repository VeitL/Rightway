import Combine
import Foundation
#if canImport(AVFoundation)
import AVFoundation
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

    private var timerCancellable: AnyCancellable?
    private var storeCancellables = Set<AnyCancellable>()
    private var recordedAudioURL: URL?

    init(sessionStore: DrivingSessionStore,
         notesStore: NotesStore,
         locationService: LocationService,
         audioService: AudioRecordingService) {
        self.sessionStore = sessionStore
        self.notesStore = notesStore
        self.locationService = locationService
        self.audioService = audioService
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
        sessionStore.finishSession(amountPaid: amount, noteID: noteID, audioURL: audioURLForSession)
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

    func note(for session: DrivingSession) -> UserNote? {
        guard let noteID = session.noteID else { return nil }
        return notesStore.notes.first { $0.id == noteID }
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
