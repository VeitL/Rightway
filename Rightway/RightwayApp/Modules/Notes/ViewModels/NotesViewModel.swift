import Combine
import Foundation

@MainActor
final class NotesViewModel: ObservableObject {
    @Published private(set) var notes: [UserNote]

    private let store: NotesStore
    private var cancellables = Set<AnyCancellable>()

    init(store: NotesStore) {
        self.store = store
        self.notes = store.notes

        store.$notes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.notes = $0 }
            .store(in: &cancellables)
    }

    func add(note: UserNote) {
        store.add(note: note)
    }

    func notes(for category: NoteCategory) -> [UserNote] {
        notes.filter { $0.category == category }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
