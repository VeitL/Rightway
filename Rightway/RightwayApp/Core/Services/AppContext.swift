import Combine
import Foundation
import SwiftUI

/// Central dependency container so the SwiftUI hierarchy can stay declarative while keeping testability high.
final class AppContext: ObservableObject {
    let apiClient: APIClient
    let syncService: SyncService
    let mediaCache: MediaCache
    let authService: AuthService
    let persistence: CoreDataStack

    let questionStore: QuestionStore
    let signStore: SignStore
    let notesStore: NotesStore
    let progressStore: ProgressStore
    let examStore: ExamStore
    let drivingSessionStore: DrivingSessionStore
    let glossaryStore: GlossaryStore
    let locationService: LocationService
    let audioRecordingService: AudioRecordingService
    let srsEngine: SRSEngine
    let userPreferences: UserPreferencesStore

    private var cancellables = Set<AnyCancellable>()

    init(apiClient: APIClient = RemoteAPIClient(),
         syncService: SyncService? = nil,
         mediaCache: MediaCache = DefaultMediaCache(),
         authService: AuthService = DefaultAuthService(),
         persistence: CoreDataStack = CoreDataStack()) {
        self.apiClient = apiClient
        self.mediaCache = mediaCache
        self.authService = authService
        self.persistence = persistence

        self.questionStore = QuestionStore()
        self.signStore = SignStore()
        self.notesStore = NotesStore()
        self.progressStore = ProgressStore()
        self.examStore = ExamStore()
        self.drivingSessionStore = DrivingSessionStore()
        self.glossaryStore = GlossaryStore()
#if canImport(CoreLocation) && !os(macOS)
        self.locationService = CoreLocationService()
#else
        self.locationService = StubLocationService()
#endif
#if canImport(AVFoundation) && !os(macOS)
        self.audioRecordingService = AVAudioRecorderService()
#else
        self.audioRecordingService = StubAudioRecorderService()
#endif
        self.srsEngine = SRSEngine()
        self.userPreferences = UserPreferencesStore()

        if let providedSyncService = syncService {
            self.syncService = providedSyncService
        } else {
            let questionService = SupabaseQuestionService(configuration: .current)
            self.syncService = SupabaseSyncService(questionService: questionService)
        }

        wireSyncPipeline()
    }

    func bootstrap() {
        guard !authService.hasActiveSession else { return }
        authService.signInAnonymously()
    }

    private func wireSyncPipeline() {
        syncService.syncEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handle(event: event)
            }
            .store(in: &cancellables)
    }

    private func handle(event: SyncEvent) {
        switch event {
        case .questionsUpdated(let snapshot):
            questionStore.apply(snapshot: snapshot)
        case .signsUpdated(let signs):
            signStore.apply(signs: signs)
        case .notesUpdated(let notes):
            notesStore.apply(notes: notes)
        case .progressUpdated(let progress):
            progressStore.apply(progress: progress)
        case .examBlueprintUpdated(let blueprint):
            examStore.apply(blueprint: blueprint)
        case .failed(let error):
            NSLog("Sync error: \(error.localizedDescription)")
        case .idle:
            break
        }
    }
}
