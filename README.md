# SwiftUI Starter Template

[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://swift.org)
[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-000000?logo=apple)](https://developer.apple.com/ios/)
[![Xcode 26+](https://img.shields.io/badge/Xcode-26%2B-147EFB?logo=xcode&logoColor=white)](https://developer.apple.com/xcode/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A starting point for iOS apps built with SwiftUI and Swift 6. It comes with networking, secure storage, Clean Architecture and three working flows: **Onboarding → Login → Dashboard**. It has no third-party dependencies.

Clone it, rename it with one script, and build.

## Features

- **Clean Architecture**: App, Core, Domain, Data and Presentation layers, wired together in one composition root (`AppContainer`).
- **Networking**: an `async`/`await` `APIClient` built on `URLSession`, with bearer auth. When several requests get a 401 at the same time, the token is refreshed once and every request is retried.
- **Session handling**: `AppRouter` switches between onboarding, login and the main app when the user logs in, logs out or the session expires.
- **Secure storage**: tokens live in the Keychain. A typed `UserDefaults` wrapper holds non-sensitive preferences.
- **Three environments**: Dev, Staging and Prod schemes. Each has its own bundle ID, display name and API base URL, set in `.xcconfig` files.
- **Offline mode**: the `-UseMockData` launch argument runs the whole app against mock repositories.
- **Sample screens**: onboarding pager, login with input validation, paginated product list with pull-to-refresh, product detail, and a profile tab with logout.
- **Localization**: a String Catalog with English and Vietnamese.
- **Tests**: 80+ Swift Testing tests for networking, storage, mappers, repositories and view models.
- **Debug logging**: requests and responses are logged in Debug builds only, with the `Authorization` header redacted.

## Requirements

- Xcode 26 or later. The project uses Swift 6.2 features such as `@concurrent` and default `MainActor` isolation.
- iOS 17.0 or later.

## Getting started

Click **Use this template** on GitHub to create your own repository and clone it, or clone this one directly:

```sh
git clone https://github.com/kietdt/swift_ui_template.git MyApp && cd MyApp
scripts/rename.sh MyApp com.company.myapp      # renames the project, targets, folders and bundle ID
xcodebuild test -scheme Dev -destination 'platform=iOS Simulator,name=iPhone 17'
git add -A && git commit -m "chore: rename template to MyApp"
```

Then open `MyApp.xcodeproj`, choose your signing team and run the **Dev** scheme.

- `rename.sh` needs a clean working tree. The new name must start with a letter and contain only letters, digits and `_`.
- After renaming, replace this README with one for your app.

The template talks to [DummyJSON](https://dummyjson.com) out of the box. Test account: `emilys` / `emilyspass`. Debug builds fill it in for you.

## Environments

| Scheme / Configuration | Bundle ID | App name | Notes |
|---|---|---|---|
| Dev | `<bundle id>.dev` | `<App> Dev` | Debug, runs unit tests |
| Staging | `<bundle id>.stg` | `<App> Stg` | Release |
| Prod | `<bundle id>` | `<App>` | Release |

- Set the API base URL in `Configs/Dev.xcconfig`, `Staging.xcconfig` and `Prod.xcconfig` (`API_BASE_URL`). Write it as `https:/$()/host`, because `//` starts a comment in `.xcconfig` files.
- The values are copied into `Configs/Info.plist` and read by `AppEnvironment.current`.
- To add a variable: declare it in the `.xcconfig` files, add the key to `Configs/Info.plist`, then read it in `AppEnvironment`.
- To run offline, enable the `-UseMockData` launch argument in *Edit Scheme → Run → Arguments*.

## Architecture

```
Presentation ──▶ Domain ◀── Data ──▶ Core
      ▲                                ▲
      └──────────── App (AppContainer) ┘
```

| Folder | Contents | Depends on |
|---|---|---|
| `App/` | `MainApp`, `AppContainer` (composition root and ViewModel factories), `AppRouter`, `RootView` | everything |
| `Core/` | `Network` (APIClient, token refresh), `Storage` (UserDefaults, Keychain), `Utils`, `Config` | — |
| `Domain/` | Models, `DomainError`, repository protocols, use cases | `Core/Utils` |
| `Data/` | DTOs, mappers, endpoints, repository implementations, mocks | Domain, Core |
| `Presentation/` | Views and `@Observable` ViewModels per feature, shared components in `Common/` | Domain |

Rules:

- ViewModels call **use cases** only, and only ever see `DomainError`. User-facing messages live in `DomainError+Message.swift`.
- Only `AppContainer` knows the concrete Data-layer types.
- Tokens are stored only in the Keychain (`TokenStore`). `UserDefaults` (`KeyValueStore`) is for non-sensitive data.

### Session flow

1. `AppRouter.start()` picks `.onboarding`, `.main` or `.login`.
2. Requests with `requiresAuth` get a `Bearer` header. On a 401, `TokenRefresher` refreshes **once** for all concurrent requests, then they retry.
3. If the refresh fails, tokens are cleared and `SessionEvent.expired` is sent, so `AppRouter` returns to Login. Logout sends `.loggedOut` and login sends `.loggedIn`.

### Concurrency (Swift 6)

- The app target uses default `MainActor` isolation, so Views and ViewModels run on the main actor unless stated otherwise.
- Types used off the main actor (DTOs, domain models, repositories, networking, storage) must be declared `nonisolated` and `Sendable`. A DTO without `nonisolated` causes a compile error when passed to `apiClient.send`.
- `MemberImportVisibility` is enabled: a file that uses `AppLogger` must `import OSLog`, and a file that uses `UIColor` or `UIApplication` must `import UIKit`.

## Adding a feature (example: Orders)

1. **Endpoint**: `Data/Remote/OrderEndpoint.swift` with `nonisolated enum OrderEndpoint: Endpoint`.
2. **DTO and mapper**: `Data/DTOs/OrderDTOs.swift` and `Data/Mappers/OrderMappers.swift` (`toDomain()`).
3. **Domain**: `Domain/Models/Order.swift`, `Domain/Repositories/OrderRepository.swift`, `Domain/UseCases/GetOrdersUseCase.swift`.
4. **Repository**: `Data/Repositories/RemoteOrderRepository.swift` (wrap errors with `mapToDomainError`) and `Data/Mocks/MockOrderRepository.swift`.
5. **ViewModel and View**: `Presentation/Orders/OrdersViewModel.swift` (using `ViewState`) and `OrdersView.swift`.
6. **Register**: add the repository to `AppContainer` (both `live` and `preview`) and a `makeOrdersViewModel()` factory.
7. **Tests**: mapper, repository (`StubAPIClient` or `URLProtocolStub`) and ViewModel (mock repository).
8. **Strings**: add Vietnamese translations for new strings in `Resources/Localizable.xcstrings`.

## Localization

- `Resources/Localizable.xcstrings`: English is the source language, with Vietnamese translations.
- In Views, use string literals (`Text("Log In")`). Outside Views, use `String(localized:)`.
- Users change the language in *Settings → \<App\> → Language*. The Profile tab has a shortcut to that screen.

## Testing

```sh
xcodebuild test -scheme Dev -destination 'platform=iOS Simulator,name=iPhone 17'
```

Tests use Swift Testing and run hosted in the app. Helpers live in `swift_ui_templateTests/Helpers`:

- `URLProtocolStub` fakes a server for `URLSession`. Each test uses its own host, so tests can run in parallel.
- `StubAPIClient` fakes `APIClient` for repository tests.
- `TestFixtures` and `waitUntil`.

## Not included

These are left out on purpose. The table shows where each one would go.

| Feature | Where to add it |
|---|---|
| Sign up, password reset, social login | `Presentation/Auth/`, plus new methods on `AuthRepository` |
| Push notifications, analytics, crash reporting | `App/` (AppDelegate adaptor) plus a service in `Core/` |
| Offline cache | A decorator around the repository in `Data/` |
| In-app language switcher, theme switcher | `KeyValueStore` plus a Settings screen |
| File upload/download, network reachability | Extend `APIClient`; `NWPathMonitor` in `Core/Network` |

## Design notes

The design spec and implementation plan behind this template are in [`docs/superpowers`](docs/superpowers).

## Contributing

Issues and pull requests are welcome. Please run the test suite before opening a pull request.

## License

Released under the [MIT License](LICENSE).
