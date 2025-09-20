import SwiftUI

struct ExamSheetView: View {
    let languageCode: String
    @Environment(\.dismiss) private var dismiss
    @State private var timeRemaining: Int = 45 * 60

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ProgressView(value: Double(timeRemaining), total: 45 * 60)
                    .tint(.accentColor)
                ContentUnavailableView("Official exam player pending",
                                         systemImage: "hourglass",
                                         description: Text("Language: \(languageCode.uppercased())"))
                Spacer()
            }
            .padding()
            .navigationTitle("官方模拟")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("结束") { dismiss() }
                }
            }
        }
        .onAppear(perform: startTimer)
    }

    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}

#Preview {
    ExamSheetView(languageCode: "de")
}
