import Combine
import Foundation

final class SupabaseSyncService: SyncService {
    private let questionService: SupabaseQuestionService
    private let subject = CurrentValueSubject<SyncEvent, Never>(.idle)

    init(questionService: SupabaseQuestionService = SupabaseQuestionService()) {
        self.questionService = questionService
        Task { await fetchLatest() }
    }

    var syncEvents: AnyPublisher<SyncEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    func triggerRefresh() {
        Task { await fetchLatest() }
    }

    private func fetchLatest() async {
        do {
            let questions = try await questionService.loadAuthorizedQuestionSet()
            subject.send(.questionsUpdated(questions))
            subject.send(.idle)
        } catch {
            subject.send(.failed(error))
        }
    }
}
