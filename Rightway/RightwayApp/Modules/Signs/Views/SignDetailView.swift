import SwiftUI

struct SignDetailView: View {
    let sign: Sign

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SignBadge(sign: sign)
                    .frame(maxWidth: .infinity)
                Text(sign.title.zhHans)
                    .font(.title)
                    .bold()
                Text(sign.summary)
                    .font(.body)
                relatedQuestions
            }
            .padding()
        }
        .navigationTitle(sign.catalogNumber)
    }

    private var relatedQuestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("关联题目")
                .font(.headline)
            ForEach(sign.relatedQuestions, id: \.self) { item in
                Label(item, systemImage: "list.number")
            }
        }
    }
}

#Preview {
    SignDetailView(sign: SampleData.signs.first!)
}
