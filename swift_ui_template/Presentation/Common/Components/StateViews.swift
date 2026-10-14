import SwiftUI

struct LoadingView: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry", action: retry)
                .buttonStyle(.bordered)
        }
    }
}

struct EmptyStateView: View {
    let message: LocalizedStringKey

    var body: some View {
        ContentUnavailableView(message, systemImage: "tray")
    }
}

#Preview("Error") {
    ErrorStateView(message: "No internet connection. Please try again.") {}
}

#Preview("Empty") {
    EmptyStateView(message: "No products yet")
}
