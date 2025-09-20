import SwiftUI

struct QuestionCardView: View {
    let question: Question
    let baseLanguage: QuestionLanguage
    let showChineseTranslation: Bool
    let isFavorite: Bool
    let isBlindSpot: Bool
    let onToggleFavorite: () -> Void
    let onAddNote: () -> Void
    @State private var selectedOption: Question.Option?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            optionsSection
            if showChineseTranslation {
                explanation
            }
            controls
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.easeInOut, value: selectedOption?.id)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(question.localizedStem.text(for: baseLanguage.appLocale))
                    .font(.title3)
                    .bold()
                Spacer()
                if isBlindSpot {
                    Label("盲区题", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            if showChineseTranslation {
                Text(question.localizedStem.zhHans)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(question.options) { option in
                Button {
                    selectedOption = option
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(option.text.text(for: baseLanguage.appLocale))
                            Spacer()
                            if showChineseTranslation, option.isCorrect {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        if showChineseTranslation {
                            Text(option.text.zhHans)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(selectionBackground(for: option))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.explanation.headline)
                .font(.headline)
            Text(question.explanation.body)
                .foregroundStyle(.secondary)
            if !question.explanation.tips.isEmpty {
                Divider()
                ForEach(question.explanation.tips, id: \.self) { tip in
                    Label(tip, systemImage: "lightbulb")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button(action: onToggleFavorite) {
                Label(isFavorite ? "已收藏" : "收藏", systemImage: isFavorite ? "star.fill" : "star")
            }
            Button(action: onAddNote) {
                Label("笔记", systemImage: "square.and.pencil")
            }
        }
        .font(.subheadline)
    }

    private func selectionBackground(for option: Question.Option) -> some View {
        let color: Color
        if selectedOption?.id == option.id {
            color = option.isCorrect ? .green.opacity(0.2) : .red.opacity(0.2)
        } else {
            color = Color.secondary.opacity(0.04)
        }
        return color
    }
}

#Preview {
    let question = SampleData.questions.first!
    QuestionCardView(question: question,
                     baseLanguage: .german,
                     showChineseTranslation: true,
                     isFavorite: true,
                     isBlindSpot: true,
                     onToggleFavorite: {},
                     onAddNote: {})
}
