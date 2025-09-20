import Combine
import Foundation

enum SyncEvent {
    case idle
    case questionsUpdated([Question])
    case signsUpdated([Sign])
    case notesUpdated([UserNote])
    case progressUpdated(UserProgress)
    case examBlueprintUpdated(ExamBlueprint)
    case failed(Error)
}

protocol SyncService {
    var syncEvents: AnyPublisher<SyncEvent, Never> { get }
    func triggerRefresh()
}
