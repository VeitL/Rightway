import SwiftUI

struct ExamHomeView: View {
    @StateObject var viewModel: ExamViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("模拟考试")
                .font(.largeTitle)
                .bold()

            Picker("Language", selection: $viewModel.selectedLanguageCode) {
                ForEach(viewModel.blueprint.languageCodes, id: \.self) { code in
                    Text(code.uppercased()).tag(code)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Label("时长：\(viewModel.blueprint.durationMinutes) 分钟", systemImage: "clock")
                Label("题量：\(viewModel.blueprint.questionCount) 题", systemImage: "doc.on.doc")
                Label("及格分：\(viewModel.blueprint.passingScore)", systemImage: "checkmark.circle")
            }
            .font(.headline)

            Spacer()

            Button {
                viewModel.startExam()
            } label: {
                Label("开始官方模拟", systemImage: "play.fill")
                    .font(.title3)
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
        }
        .padding()
        .sheet(isPresented: $viewModel.isPresentingExam) {
            ExamSheetView(languageCode: viewModel.selectedLanguageCode)
        }
    }
}

#Preview {
    ExamHomeView(viewModel: ExamViewModel(store: ExamStore()))
}
