import Foundation

@MainActor
final class SignsViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var signs: [Sign]
    @Published var selectedSigns: [Sign] = []

    private let signStore: SignStore

    init(signStore: SignStore) {
        self.signStore = signStore
        self.signs = signStore.signs
    }

    var filteredSigns: [Sign] {
        guard !query.isEmpty else { return signs }
        return signs.filter { sign in
            sign.catalogNumber.contains(query) ||
            sign.title.de.localizedCaseInsensitiveContains(query) ||
            sign.title.zhHans.localizedCaseInsensitiveContains(query)
        }
    }

    func toggleSelection(for sign: Sign) {
        if let index = selectedSigns.firstIndex(of: sign) {
            selectedSigns.remove(at: index)
        } else if selectedSigns.count < 3 {
            selectedSigns.append(sign)
        }
    }
}
