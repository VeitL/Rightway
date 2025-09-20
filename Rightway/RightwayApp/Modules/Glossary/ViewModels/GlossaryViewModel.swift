import Combine
import Foundation

@MainActor
final class GlossaryViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var filtered: [GlossaryTerm]

    private let store: GlossaryStore
    private var cancellables = Set<AnyCancellable>()

    init(store: GlossaryStore) {
        self.store = store
        self.filtered = store.terms

        $query
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] keyword in
                self?.updateFilteredTerms(keyword: keyword)
            }
            .store(in: &cancellables)

        store.$terms
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateFilteredTerms(keyword: self.query)
            }
            .store(in: &cancellables)
    }

    func terms(by category: GlossaryCategory?) -> [GlossaryTerm] {
        guard let category else { return filtered }
        return filtered.filter { $0.category == category }
    }

    private func updateFilteredTerms(keyword: String) {
        filtered = store.search(keyword: keyword)
    }
}
