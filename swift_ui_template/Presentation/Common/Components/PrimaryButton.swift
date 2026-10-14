import SwiftUI

struct PrimaryButton: View {
    let title: LocalizedStringKey
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: Theme.Radius.m))
        .controlSize(.large)
        .disabled(isLoading)
    }
}

#Preview {
    VStack {
        PrimaryButton(title: "Next") {}
        PrimaryButton(title: "Next", isLoading: true) {}
    }
    .padding()
}
