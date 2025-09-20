import SwiftUI

struct SignsHomeView: View {
    @StateObject var viewModel: SignsViewModel
    @State private var isPresentingCompare = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("搜索编号或关键词", text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)

                List(viewModel.filteredSigns) { sign in
                    Button {
                        viewModel.toggleSelection(for: sign)
                    } label: {
                        SignRow(sign: sign, isSelected: viewModel.selectedSigns.contains(sign))
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)

                Button {
                    isPresentingCompare = true
                } label: {
                    Label("比较所选路标", systemImage: "rectangle.3.offgrid")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedSigns.count < 2)
            }
            .padding()
            .navigationTitle("路标百科")
            .sheet(isPresented: $isPresentingCompare) {
                SignCompareView(signs: viewModel.selectedSigns)
            }
        }
    }
}

private struct SignRow: View {
    let sign: Sign
    let isSelected: Bool

    var body: some View {
        HStack {
            SignBadge(sign: sign)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(sign.catalogNumber) · \(sign.title.zhHans)")
                    .font(.headline)
                Text(sign.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}

struct SignBadge: View {
    let sign: Sign

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.thinMaterial)
                .frame(width: 64, height: 64)
            Text(sign.catalogNumber)
                .font(.headline)
        }
    }
}

#Preview {
    SignsHomeView(viewModel: SignsViewModel(signStore: SignStore()))
}
