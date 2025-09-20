import SwiftUI

struct AnalyticsDashboardView: View {
    @StateObject var viewModel: AnalyticsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summary
                chapters
                examForecast
            }
            .padding()
        }
        .navigationTitle("学习数据")
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("近期概览")
                .font(.headline)
            HStack {
                statCard(title: "已练习题目", value: "\(viewModel.progress.totalQuestionsSeen)")
                statCard(title: "正确率", value: String(format: "%.0f%%", viewModel.progress.totalCorrectRatio * 100))
                statCard(title: "SRS 待复习", value: "\(viewModel.progress.srsDueToday)")
            }
        }
    }

    private var chapters: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("章节表现")
                .font(.headline)
            ForEach(viewModel.progress.chapterStats, id: \.chapter) { chapter in
                VStack(alignment: .leading) {
                    Text(chapter.chapter)
                        .font(.subheadline)
                    ProgressView(value: chapter.correctRate)
                        .tint(.green)
                }
            }
        }
    }

    private var examForecast: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("考试预测")
                .font(.headline)
            Label("近 7 天模拟：\(viewModel.progress.examSummary.recentAttempts) 场", systemImage: "calendar")
            Label(String(format: "通过率：%.0f%%", viewModel.progress.examSummary.passRate * 100), systemImage: "checkmark.seal")
            Label(String(format: "预测得分：%.0f", viewModel.progress.examSummary.predictedScore), systemImage: "chart.bar")
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .bold()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private extension UserProgress {
    var totalCorrectRatio: Double {
        guard totalQuestionsSeen > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalQuestionsSeen)
    }
}

#Preview {
    AnalyticsDashboardView(viewModel: AnalyticsViewModel(progressStore: ProgressStore()))
}
