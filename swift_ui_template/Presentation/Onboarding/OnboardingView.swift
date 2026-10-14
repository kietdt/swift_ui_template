import SwiftUI

struct OnboardingView: View {
    @State var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack {
                Spacer()
                Button("Skip") { viewModel.finish() }
                    .opacity(viewModel.isLastPage ? 0 : 1)
            }
            .padding(.horizontal, Theme.Spacing.m)

            TabView(selection: $viewModel.currentIndex) {
                ForEach(viewModel.pages) { page in
                    VStack(spacing: Theme.Spacing.l) {
                        Image(systemName: page.systemImage)
                            .font(.system(size: 80))
                            .foregroundStyle(.tint)
                        Text(page.title)
                            .font(.largeTitle.bold())
                        Text(page.subtitle)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(Theme.Spacing.xl)
                    .tag(page.id)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            PrimaryButton(title: viewModel.isLastPage ? "Get Started" : "Next") {
                withAnimation { viewModel.next() }
            }
            .padding(Theme.Spacing.m)
        }
    }
}

#Preview {
    OnboardingView(viewModel: AppContainer.preview().makeOnboardingViewModel {})
}
