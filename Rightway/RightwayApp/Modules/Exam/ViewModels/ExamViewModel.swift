import Combine
import Foundation

@MainActor
final class ExamViewModel: ObservableObject {
    @Published var blueprint: ExamBlueprint
    @Published var selectedLanguageCode: String
    @Published var isPresentingExam = false

    private let store: ExamStore

    init(store: ExamStore) {
        self.store = store
        self.blueprint = store.blueprint
        self.selectedLanguageCode = store.blueprint.languageCodes.first ?? "de"
        store.$blueprint
            .receive(on: DispatchQueue.main)
            .assign(to: &self.$blueprint)
    }

    func startExam() {
        isPresentingExam = true
    }
}
