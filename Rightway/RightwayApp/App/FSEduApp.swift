import SwiftUI

@main
struct FSEduApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var appContext = AppContext()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(router)
                .environmentObject(appContext)
        }
    }
}

/// Container view that wires up tab navigation for the major feature areas described in the PRD.
private struct RootView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var appContext: AppContext

    var body: some View {
        TabView(selection: $router.tabSelection) {
            LearnHomeView(viewModel: makeLearningViewModel(), glossaryStore: appContext.glossaryStore)
                .tabItem { Label("Learn", systemImage: "book.closed") }
                .tag(AppRoute.learning)

            ExamHomeView(viewModel: ExamViewModel(store: appContext.examStore))
                .tabItem { Label("Exam", systemImage: "checkmark.seal") }
                .tag(AppRoute.exam)

            DrivingPracticeHomeView(viewModel: makeDrivingPracticeViewModel())
                .tabItem { Label("Practice", systemImage: "car.fill") }
                .tag(AppRoute.drivingPractice)

            SignsHomeView(viewModel: SignsViewModel(signStore: appContext.signStore))
                .tabItem { Label("Signs", systemImage: "signpost.right") }
                .tag(AppRoute.signs)

            NotesView(viewModel: NotesViewModel(store: appContext.notesStore))
                .tabItem { Label("Notes", systemImage: "note.text") }
                .tag(AppRoute.notes)

            AnalyticsDashboardView(viewModel: AnalyticsViewModel(progressStore: appContext.progressStore))
                .tabItem { Label("Analytics", systemImage: "chart.bar.xaxis") }
                .tag(AppRoute.analytics)
        }
        .onAppear(perform: appContext.bootstrap)
    }

    private func makeDrivingPracticeViewModel() -> DrivingPracticeViewModel {
        DrivingPracticeViewModel(sessionStore: appContext.drivingSessionStore,
                                 notesStore: appContext.notesStore,
                                 locationService: appContext.locationService,
                                 audioService: appContext.audioRecordingService)
    }

    private func makeLearningViewModel() -> LearningViewModel {
        LearningViewModel(questionStore: appContext.questionStore,
                          notesStore: appContext.notesStore,
                          srsEngine: appContext.srsEngine,
                          preferences: appContext.userPreferences)
    }
}
