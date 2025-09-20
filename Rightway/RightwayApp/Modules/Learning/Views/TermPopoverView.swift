import SwiftUI

struct TermPopoverView: View {
    let term: GlossaryTerm

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(term.term)
                .font(.title2)
                .bold()
            Label(term.category.displayName, systemImage: "bookmark")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Divider()
            Text(term.zhDefinition)
                .font(.body)
            if !term.examples.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("例句")
                        .font(.subheadline)
                        .bold()
                    ForEach(term.examples, id: \.self) { example in
                        Text("• \(example)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if !term.relatedQuestionIDs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("关联题目")
                        .font(.subheadline)
                        .bold()
                    Text(term.relatedQuestionIDs.joined(separator: ", "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: 360)
    }
}

#Preview {
    TermPopoverView(term: GlossaryTerm(term: "Vorfahrt",
                                       category: .terminology,
                                       zhDefinition: "优先通行权。表示某个方向的车辆拥有优先通过交叉口的权利。",
                                       examples: ["Du musst die Vorfahrt achten."],
                                       relatedQuestionIDs: ["1.1.02-001"]))
}
