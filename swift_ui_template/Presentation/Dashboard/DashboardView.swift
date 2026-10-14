import SwiftUI

struct DashboardView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(viewModel: container.makeHomeViewModel())
            }
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                ProfileView(viewModel: container.makeProfileViewModel())
            }
            .tabItem { Label("Profile", systemImage: "person") }
        }
    }
}

#Preview {
    DashboardView()
        .environment(AppContainer.preview())
}
