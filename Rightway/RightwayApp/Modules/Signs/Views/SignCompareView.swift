import SwiftUI

struct SignCompareView: View {
    let signs: [Sign]

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(signs) { sign in
                        VStack(alignment: .leading, spacing: 12) {
                            SignBadge(sign: sign)
                                .frame(width: 100, height: 100)
                            Text(sign.title.zhHans)
                                .font(.headline)
                            Text(sign.summary)
                                .font(.subheadline)
                            Divider()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("德语：\(sign.title.de)")
                                Text("英语：\(sign.title.en)")
                            }
                        }
                        .padding()
                        .frame(width: 220)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
            }
            .navigationTitle("路标对比")
        }
    }
}

#Preview {
    SignCompareView(signs: SampleData.signs)
}
