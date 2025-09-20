import Combine
import Foundation

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published private(set) var progress: UserProgress

    private let progressStore: ProgressStore
    private var cancellables = Set<AnyCancellable>()

    init(progressStore: ProgressStore) {
        self.progressStore = progressStore
        self.progress = progressStore.progress

        progressStore.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.progress = $0 }
            .store(in: &cancellables)
    }
}
