import Combine
import Foundation

/// Defines the high-level navigation targets that back the TabView layout.
enum AppRoute: Hashable, CaseIterable {
    case learning
    case exam
    case drivingPractice
    case signs
    case notes
    case analytics

    var localizedTitleKey: String {
        switch self {
        case .learning: return "tab.learning"
        case .exam: return "tab.exam"
        case .drivingPractice: return "tab.practice"
        case .signs: return "tab.signs"
        case .notes: return "tab.notes"
        case .analytics: return "tab.analytics"
        }
    }
}

/// Shared router object so feature modules can drive navigation or deeplinks later on.
final class AppRouter: ObservableObject {
    @Published var tabSelection: AppRoute = .learning

    func open(_ route: AppRoute) {
        tabSelection = route
    }
}
