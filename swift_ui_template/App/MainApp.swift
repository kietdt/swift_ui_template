import SwiftUI

@main
struct MainApp: App {
    @State private var container: AppContainer
    @State private var router: AppRouter

    init() {
        let container = AppContainer.live()
        _container = State(initialValue: container)
        _router = State(initialValue: container.makeAppRouter())
    }

    var body: some Scene {
        WindowGroup {
            RootView(router: router)
                .environment(container)
        }
    }
}
