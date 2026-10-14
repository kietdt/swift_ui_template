# SwiftUI Starter Template — Design

- Ngày: 2026-10-11
- Trạng thái: Đã duyệt thiết kế, chờ review spec
- Mục tiêu: Biến project Xcode trống `swift_ui_template` thành template có thể clone → rename → build ngay để bắt đầu một dự án iOS mới, có sẵn network, storage, utils, domain/data layer và 3 luồng màn hình Onboarding → Login → Dashboard.

## 1. Bối cảnh hiện tại

- Xcode 26.6, project `objectVersion = 77`, dùng `fileSystemSynchronizedGroups` (file tạo trên disk tự vào target).
- 1 target app `swift_ui_template`, chưa có test target, chưa có Swift Package, repo chưa có commit.
- Build settings: `IPHONEOS_DEPLOYMENT_TARGET = 26.5`, `SWIFT_VERSION = 5.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, bundle ID `com.app.opt.swift-ui-template`.
- `xcuserdata/` đang được stage → cần `.gitignore`.

## 2. Quyết định đã chốt

| Chủ đề | Quyết định |
|---|---|
| iOS tối thiểu | 17.0 |
| Swift | 6.0 language mode, giữ default isolation `MainActor` |
| Thư viện ngoài | Không dùng (zero dependency) |
| Backend mẫu | DummyJSON (`https://dummyjson.com`) + Mock repository chạy offline |
| Kiến trúc | MVVM + Clean Architecture, 1 target, chia layer bằng folder |
| ViewModel | `@Observable`, DI thủ công qua `AppContainer` |
| Môi trường | 3 configuration + 3 scheme: Dev / Staging / Prod qua `.xcconfig` |
| Test | Target `swift_ui_templateTests`, Swift Testing |
| Ngôn ngữ | String Catalog, en (source) + vi |
| Rename | `scripts/rename.sh` |

## 3. Cấu trúc thư mục

```
swift_ui_template/                 (repo root)
├─ .gitignore
├─ README.md
├─ Configs/
│  ├─ Base.xcconfig
│  ├─ Dev.xcconfig
│  ├─ Staging.xcconfig
│  ├─ Prod.xcconfig
│  └─ Info.plist                   (nằm NGOÀI synchronized group)
├─ scripts/
│  └─ rename.sh
├─ swift_ui_template.xcodeproj/
├─ swift_ui_template/              (synchronized group của app target)
│  ├─ App/
│  │  ├─ MainApp.swift             (@main, tên trung lập — không cần đổi khi rename)
│  │  ├─ AppContainer.swift
│  │  ├─ AppRouter.swift
│  │  └─ RootView.swift
│  ├─ Core/
│  │  ├─ Config/       AppEnvironment.swift
│  │  ├─ Network/      HTTPMethod, Endpoint, APIClient, URLSessionAPIClient,
│  │  │                APIError, AuthTokens, TokenProvider, TokenRefresher, NetworkLogger
│  │  ├─ Storage/      KeyValueStore, PreferenceKey, UserDefaultsStore,
│  │  │                KeychainStore, SystemKeychainStore, InMemoryKeychainStore
│  │  └─ Utils/        AppLogger, Validator, extensions
│  ├─ Domain/
│  │  ├─ Models/       User, Product, Page, SessionEvent
│  │  ├─ Errors/       DomainError
│  │  ├─ Repositories/ AuthRepository, ProductRepository, OnboardingRepository
│  │  └─ UseCases/     Login, Logout, GetCurrentUser, GetProducts,
│  │                   GetProductDetail, CompleteOnboarding
│  ├─ Data/
│  │  ├─ DTOs/         LoginRequestDTO, AuthResponseDTO, RefreshRequestDTO,
│  │  │                RefreshResponseDTO, UserDTO, ProductDTO, ProductListDTO,
│  │  │                ErrorResponseDTO
│  │  ├─ Mappers/      DTO → Domain
│  │  ├─ Remote/       AuthEndpoint, ProductEndpoint, AuthRefreshAction
│  │  ├─ Local/        TokenStore (AuthTokens trong Keychain), SessionEventBroadcaster,
│  │  │                LocalOnboardingRepository
│  │  ├─ Repositories/ RemoteAuthRepository, RemoteProductRepository
│  │  └─ Mocks/        MockAuthRepository, MockProductRepository, SampleData
│  ├─ Presentation/
│  │  ├─ Common/       ViewState, Theme, PrimaryButton, AppTextField,
│  │  │                LoadingView, ErrorStateView, EmptyStateView,
│  │  │                DomainError+Message
│  │  ├─ Onboarding/   OnboardingView, OnboardingViewModel, OnboardingPage
│  │  ├─ Auth/Login/   LoginView, LoginViewModel
│  │  └─ Dashboard/
│  │     ├─ DashboardView.swift   (TabView)
│  │     ├─ Home/      HomeView, HomeViewModel, ProductRow
│  │     ├─ ProductDetail/ ProductDetailView, ProductDetailViewModel
│  │     └─ Profile/   ProfileView, ProfileViewModel
│  └─ Resources/
│     ├─ Assets.xcassets
│     └─ Localizable.xcstrings
└─ swift_ui_templateTests/         (synchronized group của test target)
   ├─ Helpers/   URLProtocolStub, StubAPIClient, TestFixtures(+Auth, +Products), Waiting
   ├─ Core/      AppEnvironment, Validator, UserDefaultsStore, InMemoryKeychainStore,
   │             Endpoint, TokenRefresher, NetworkLogger, URLSessionAPIClient (…Tests)
   ├─ Domain/    PageTests, LoginUseCaseTests
   ├─ Data/      TokenStore, SessionEventBroadcaster, Mapper, RemoteAuthRepository,
   │             RemoteProductRepository, LocalOnboardingRepository (…Tests)
   ├─ Presentation/ DomainErrorMessage, Onboarding/Login/Home/ProfileViewModel,
   │             Localization (…Tests)
   └─ App/       AppRouterTests
```

Chiều phụ thuộc: `Presentation → Domain ← Data → Core`. `Presentation` và `Domain` có thể dùng `Core/Utils` (hàm thuần: Validator, Logger). Chỉ `App/AppContainer` được biết cả `Data` và `Presentation`.

## 4. Nền tảng project

### 4.1 Build settings
- `IPHONEOS_DEPLOYMENT_TARGET = 17.0`.
- `SWIFT_VERSION = 6.0`; giữ `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` và `SWIFT_APPROACHABLE_CONCURRENCY = YES`.
- Code UI/ViewModel ngầm định `@MainActor`. Code network, storage, DTO, Domain model khai báo `nonisolated` + `Sendable`. `URLSessionAPIClient.send` đánh dấu `@concurrent` để decode ngoài main thread.

### 4.2 Môi trường
- Thay 2 configuration `Debug`/`Release` bằng `Dev` (dựa trên Debug: `-Onone`, `DEBUG` flag), `Staging` và `Prod` (dựa trên Release). Áp dụng cho cả project và 2 target.
- Mỗi configuration của app target dùng `baseConfigurationReference` tới xcconfig tương ứng; các xcconfig `#include "Base.xcconfig"`.
- Biến trong xcconfig:
  - `API_BASE_URL` (viết `https:/$()/dummyjson.com` để tránh `//` bị hiểu là comment)
  - `APP_ENVIRONMENT` = `dev` | `staging` | `prod`
  - `APP_NAME = Template` (trong `Base.xcconfig`); `APP_DISPLAY_NAME` = `$(APP_NAME) Dev` | `$(APP_NAME) Stg` | `$(APP_NAME)`
  - `BUNDLE_ID_SUFFIX` = `.dev` | `.stg` | (rỗng); `PRODUCT_BUNDLE_IDENTIFIER = com.app.opt.swift-ui-template$(BUNDLE_ID_SUFFIX)`
- `Configs/Info.plist` chứa `API_BASE_URL = $(API_BASE_URL)` và `APP_ENVIRONMENT = $(APP_ENVIRONMENT)`. Target dùng `INFOPLIST_FILE = Configs/Info.plist` và vẫn giữ `GENERATE_INFOPLIST_FILE = YES` (Xcode merge). `INFOPLIST_KEY_CFBundleDisplayName = $(APP_DISPLAY_NAME)`.
- 3 shared scheme `Dev`, `Staging`, `Prod` (Run/Test/Archive dùng configuration cùng tên; scheme `Dev` có launch argument `-UseMockData` ở trạng thái tắt sẵn). Xoá scheme mặc định `swift_ui_template`.
- Cả 3 môi trường tạm trỏ về DummyJSON, có comment hướng dẫn thay.

### 4.3 Khác
- `.gitignore`: `xcuserdata/`, `DerivedData/`, `.DS_Store`, `*.xcuserstate`, `build/`. Bỏ `xcuserdata` khỏi index.
- `knownRegions` của project thêm `vi`.
- Đổi `swift_ui_templateApp.swift` → `App/MainApp.swift` (struct `MainApp`); xoá `ContentView.swift` (thay bằng `RootView`). `Assets.xcassets` chuyển vào `Resources/`.

## 5. Core

### 5.1 Network
- `HTTPMethod`: `get`, `post`, `put`, `patch`, `delete`.
- `Endpoint` (protocol, `Sendable`): `path: String`, `method: HTTPMethod`, `query: [URLQueryItem]` (mặc định rỗng), `body: (any Encodable & Sendable)?` (mặc định nil), `headers: [String: String]` (mặc định rỗng), `requiresAuth: Bool` (mặc định `true`). Extension `makeRequest(baseURL:encoder:) throws -> URLRequest`.
- `APIClient` (protocol): `func send<T: Decodable & Sendable>(_ endpoint: some Endpoint) async throws -> T`. (Chưa có biến thể không trả body — thêm khi có endpoint cần.)
- `TokenProvider` (protocol, `Sendable`): `accessToken() async -> String?`, `refreshToken() async -> String?`, `save(_ tokens: AuthTokens) async`, `clear() async`. `TokenStore` (Data/Local) conform. `AuthTokens` nằm ở Core/Network vì APIClient cần dùng.
- `URLSessionAPIClient`: khởi tạo với `baseURL`, `session: URLSession`, `tokenProvider`, `refresher: TokenRefresher`, `decoder`, `encoder`, `logger`.
  1. Build request; nếu `requiresAuth` và có token thì gắn `Authorization: Bearer <token>`.
  2. Gửi request, map `URLError` (`.notConnectedToInternet`, `.networkConnectionLost` → `noConnection`; `.timedOut` → `timeout`; khác → `unknown`).
  3. 200–299 → decode `T` (lỗi → `decoding`). 401 với endpoint `requiresAuth` → gọi `refresher.refresh(rejectedToken:)` (token vừa bị từ chối; nếu token đã được request khác refresh thì bỏ qua) rồi retry đúng 1 lần; nếu vẫn 401 → `unauthorized`. Các status khác → `http(status:data:)`.
- `TokenRefresher` (`actor`): giữ `Task<Void, Error>?` đang chạy để nhiều request 401 đồng thời chỉ refresh 1 lần. Refresh bằng closure được inject `(String) async throws -> AuthTokens` (để Core không phụ thuộc endpoint cụ thể; `AppContainer` truyền closure gọi `AuthEndpoint.refresh`). Thành công → lưu token mới. Thất bại hoặc không có refresh token → `tokenProvider.clear()`, phát `SessionEvent.expired` qua `onSessionExpired` callback, ném `APIError.unauthorized`.
- `APIError`: `invalidURL`, `noConnection`, `timeout`, `unauthorized`, `http(status: Int, data: Data)`, `decoding(String)`, `unknown(String)`. `Equatable`, `Sendable`.
- `NetworkLogger`: dùng `AppLogger.network`, chỉ log trong `#if DEBUG`; log method, URL, status, thời gian, body cắt ngắn; thay giá trị header `Authorization` bằng `<redacted>`.

### 5.2 Storage
- `PreferenceKey<Value: Codable & Sendable>`: `name: String`, `defaultValue: Value`. Khai báo key tập trung: `extension PreferenceKey where Value == Bool { static var hasSeenOnboarding: PreferenceKey<Bool> { ... } }` (generic type không có static stored property).
- `KeyValueStore` (protocol): `value<V>(for key: PreferenceKey<V>) -> V`, `set<V>(_ value: V, for key: PreferenceKey<V>)`, `remove(_ key:)`. Hỗ trợ kiểu property-list (Bool, Int, Double, String, Data, Date) và `Codable` qua JSON.
- `UserDefaultsStore`: implement bằng `UserDefaults` được inject (test dùng `UserDefaults(suiteName: UUID().uuidString)`).
- `KeychainStore` (protocol): `data(for key: String) throws -> Data?`, `set(_ data: Data, for key: String) throws`, `remove(_ key: String) throws`; extension cho `Codable`.
- `SystemKeychainStore(service: String)` (`AppContainer` truyền `Bundle.main.bundleIdentifier`, nên mỗi môi trường có keychain riêng và không cần đổi khi rename): `kSecClassGenericPassword`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; lỗi `OSStatus` → `KeychainError.unhandled(OSStatus)`.
- `InMemoryKeychainStore`: dùng cho test, Preview, mock mode.
- Quy tắc: token chỉ nằm trong Keychain.

### 5.3 Utils
- `AppLogger`: các `os.Logger` tĩnh `network`, `auth`, `storage` với subsystem = bundle ID (thêm category khi cần).
- `Validator`: `isNotBlank`, `hasMinLength(_:)`, `isValidEmail` — trả `Bool`, hàm thuần.
- Extensions: chỉ thêm khi có chỗ dùng thật (ví dụ `Bundle.appVersion`, `String.trimmed`).

### 5.4 Config
- `AppEnvironment` (`nonisolated struct`, `Sendable`): `name`, `baseURL: URL`, `useMockData: Bool`, `isDebug: Bool`. `static let current` đọc `Bundle.main.infoDictionary` và `ProcessInfo.processInfo.arguments.contains("-UseMockData")`. Thiếu/sai `API_BASE_URL` → `fatalError` với message rõ ràng (lỗi cấu hình, phát hiện ngay lần chạy đầu).

## 6. Domain

Chỉ `import Foundation`. Model là `nonisolated struct: Sendable, Equatable, Identifiable` (khi có id).

- `User`: `id: Int`, `username`, `email`, `firstName`, `lastName`, `avatarURL: URL?`; computed `fullName`.
- `Product`: `id: Int`, `title`, `description`, `price: Double` (hiển thị bằng `.currency(code:)`; đổi sang `Decimal` nếu dự án cần tính tiền chính xác), `rating: Double`, `thumbnailURL: URL?`, `imageURLs: [URL]`, `category`, `brand: String?`.
- `Page<Item: Sendable & Equatable>`: `items`, `total`, `skip`, `limit`; computed `hasMore = skip + items.count < total`.
- `SessionEvent`: `loggedIn`, `loggedOut`, `expired`.
- `DomainError` (`Error, Equatable, Sendable`): `invalidInput(field: InputField, reason: InputReason)`, `invalidCredentials`, `sessionExpired`, `noConnection`, `server(message: String?)`, `unknown`. `InputField`: `username`, `password`; `InputReason`: `empty`, `tooShort(min: Int)`.

Repository protocols (`Sendable`):
- `AuthRepository`: `login(username:password:) async throws -> User`, `currentUser() async throws -> User`, `logout() async`, `isLoggedIn() async -> Bool`, `sessionEvents() -> AsyncStream<SessionEvent>`.
- `ProductRepository`: `fetchProducts(skip:limit:) async throws -> Page<Product>`, `fetchProduct(id:) async throws -> Product`.
- `OnboardingRepository`: `hasSeenOnboarding() -> Bool`, `markOnboardingSeen()`.

UseCases (struct, `callAsFunction`):
- `LoginUseCase`: trim username; username rỗng → `invalidInput(.username, .empty)`; password rỗng → `invalidInput(.password, .empty)`; password < 6 ký tự → `invalidInput(.password, .tooShort(min: 6))`; hợp lệ → `repository.login`.
- `LogoutUseCase`, `GetCurrentUserUseCase`, `GetProductsUseCase(skip:limit:)`, `GetProductDetailUseCase(id:)`, `CompleteOnboardingUseCase`: chuyển tiếp tới repository.

## 7. Data

- DTOs khớp response DummyJSON đã kiểm tra:
  - `POST /auth/login` body `{username, password, expiresInMins}` → `{id, username, email, firstName, lastName, gender, image, accessToken, refreshToken}`; sai mật khẩu → 400 `{"message":"Invalid credentials"}`.
  - `POST /auth/refresh` body `{refreshToken, expiresInMins}` → `{accessToken, refreshToken}`; refresh token sai → 403.
  - `GET /auth/me` (Bearer) → user; token sai/hết hạn → 401.
  - `GET /auth/products?limit=&skip=` (Bearer) → `{products, total, skip, limit}`; `GET /auth/products/{id}` (Bearer) → product; không có token hoặc token sai/hết hạn → 401. Dùng bản `/auth/...` thay vì `/products` công khai để màn Home cũng đi qua luồng refresh token.
  - Lỗi chung: `ErrorResponseDTO { message: String }`.
- `AuthEndpoint`: `.login(LoginRequestDTO)` (`requiresAuth = false`), `.refresh(RefreshRequestDTO)` (`requiresAuth = false`), `.me`. `ProductEndpoint`: `.list(skip:limit:)` → `/auth/products`, `.detail(id:)` → `/auth/products/{id}` (đều `requiresAuth = true`). `expiresInMins` mặc định 30.
- Mappers: `UserDTO.toDomain()`, `AuthResponseDTO.toDomainUser()` + `.tokens`, `ProductDTO.toDomain()`, `ProductListDTO.toDomain() -> Page<Product>`. URL không hợp lệ → `nil`.
- `TokenStore` (`actor`, conform `TokenProvider`): lưu `AuthTokens` (Codable) vào `KeychainStore` với key `auth.tokens`.
- `APIError → DomainError` (một hàm `mapToDomainError` dùng chung trong Data):
  - `noConnection`, `timeout` → `noConnection`
  - `unauthorized` → `sessionExpired`
  - `http(400|401, _)` ở login → `invalidCredentials`
  - `http(_, data)` khác → `server(message: ErrorResponseDTO?.message)`
  - còn lại → `unknown`
- `RemoteAuthRepository(apiClient, tokenStore)`: login → lưu token, phát `.loggedIn`; logout → xoá token, phát `.loggedOut`; `isLoggedIn` = có access token. `sessionEvents()` trả `AsyncStream` (broadcast tới mọi subscriber). `TokenRefresher.onSessionExpired` được nối để phát `.expired` qua repository này.
- `RemoteProductRepository(apiClient)`.
- `LocalOnboardingRepository(store: KeyValueStore)`.
- Mocks: `MockAuthRepository` (tài khoản hợp lệ `emilys`/`emilyspass`, delay 0.5s, có thể cấu hình lỗi), `MockProductRepository` (sinh dữ liệu từ `SampleData`, phân trang thật trên mảng 45 phần tử, có thể cấu hình lỗi). Dùng cho Preview, test ViewModel và chế độ `-UseMockData`.

## 8. Presentation

### 8.1 App
- `AppContainer` (`@Observable final class`): tạo theo `AppEnvironment`; giữ `APIClient`, stores, repositories (real hoặc mock), use cases; có factory `makeOnboardingViewModel()`, `makeLoginViewModel()`, `makeHomeViewModel()`, `makeProductDetailViewModel(id:)`, `makeProfileViewModel()`. `static func preview()` dùng mock + UserDefaults suite riêng. `makeLoginViewModel()` điền sẵn `emilys`/`emilyspass` trong `#if DEBUG`. Inject bằng `.environment(container)`.
- `AppRouter` (`@Observable`): `route: AppRoute` (`.launching`, `.onboarding`, `.login`, `.main`); khởi tạo ở `.launching` (hiện nền trống, vài ms) vì `isLoggedIn()` là async (TokenStore là actor).
  - `start() async`: `!hasSeenOnboarding` → `.onboarding`; `isLoggedIn` → `.main`; còn lại → `.login`.
  - `observeSession()`: `for await event in authRepository.sessionEvents()` — `.loggedIn` → `.main`; `.loggedOut`/`.expired` → `.login`.
  - `onboardingFinished()` → `.login`.
- `RootView`: `switch router.route` + `.transition(.opacity)`; `.task { await router.start(); await router.observeSession() }`.

### 8.2 Common
- `ViewState<Value>`: `idle`, `loading`, `loaded(Value)`, `failed(String)`.
- `Theme`: `Spacing` (xs 4, s 8, m 16, l 24, xl 32), `Radius` (s 8, m 12), màu từ Assets (`AccentColor`, dùng màu hệ thống cho phần còn lại).
- Components: `PrimaryButton(title, isLoading, action)`, `AppTextField(title, text, isSecure, error)`, `LoadingView`, `ErrorStateView(message, retry)`, `EmptyStateView(message)`.
- `DomainError+Message.swift`: `var message: String` dùng `String(localized:)`.

### 8.3 Onboarding
- 3 trang (`OnboardingPage`: SF Symbol, title, subtitle) trong `TabView(selection:)` `.tabViewStyle(.page)`.
- Nút Skip (góc trên), Next; trang cuối đổi thành "Get Started". Cả Skip và Get Started gọi `CompleteOnboardingUseCase` rồi `router.onboardingFinished()`.

### 8.4 Login
- `LoginViewModel`: `username`, `password`, `usernameError: String?`, `passwordError: String?`, `isLoading`, `alertMessage: String?`. `submit()` gọi `LoginUseCase`; `invalidInput` → lỗi inline theo field; lỗi khác → `alertMessage`. Thành công không cần điều hướng thủ công — `.loggedIn` event đưa router sang `.main`.
- `LoginView`: tiêu đề, `AppTextField` username, password (toggle hiện/ẩn), `PrimaryButton`; disable form khi loading; `.alert` cho lỗi (binding qua `isShowingAlert`).

### 8.5 Dashboard
- `DashboardView`: `TabView` 2 tab (Home: `house`, Profile: `person`), mỗi tab có `NavigationStack` riêng.
- `HomeViewModel`: `state: ViewState<[Product]>`, `isLoadingMore`, `pageSize = 20`. `load()` (lần đầu), `refresh()` (pull-to-refresh, reset), `loadMoreIfNeeded(current: Product)` (khi item cuối xuất hiện và `hasMore`, không gọi trùng). Lỗi khi load more không xoá danh sách đã có.
- `HomeView`: `List` các `ProductRow` (`AsyncImage` thumbnail, title, price), `.refreshable`, spinner cuối list khi load more, `LoadingView`/`ErrorStateView`/`EmptyStateView` theo state; `NavigationLink(value: product.id)` + `.navigationDestination(for: Int.self)` → `ProductDetailView`.
- `ProductDetailViewModel` + `ProductDetailView`: ảnh (`TabView` page các `imageURLs`), title, brand, price, rating, description; state loading/error/retry.
- `ProfileViewModel`: `state: ViewState<User>`, `load()`, `logout()` (gọi `LogoutUseCase`; router tự về `.login` qua event).
- `ProfileView`: avatar (`AsyncImage`), họ tên, email; section Settings: "Language" (mở `UIApplication.openSettingsURLString` — dùng ngôn ngữ theo app của iOS), "Version" (`Bundle.appVersion` + build), "Environment" (`AppEnvironment.current.name`); nút Logout đỏ với `confirmationDialog`.

## 9. Đa ngôn ngữ
- `Resources/Localizable.xcstrings`, source language en, bản dịch vi cho toàn bộ text UI và message lỗi.
- View dùng literal `Text("Login")` (LocalizedStringKey); ViewModel/không phải View dùng `String(localized:)`.
- Không đổi ngôn ngữ trong app; người dùng đổi qua Settings của iOS (hiển thị khi app có ≥ 2 localization).

## 10. Error handling (tổng hợp)
`URLError/HTTP` → `APIError` (Core) → `DomainError` (Data) → message localized (Presentation). ViewModel không bao giờ thấy `APIError` hay status code. Hết phiên ở bất kỳ request nào → `TokenRefresher` xoá token + phát `.expired` → router về Login.

## 11. Test (Swift Testing, target `swift_ui_templateTests`, hosted trong app)
- Helpers: `URLProtocolStub` (handler theo host — mỗi test một host nên chạy song song an toàn), `StubAPIClient` (trả response xếp hàng, ghi lại path), `TestFixtures` (+Auth, +Products: JSON mẫu, `makeDefaults()` tạo UserDefaults suite riêng), `waitUntil`.
- `URLSessionAPIClientTests`: decode thành công; gắn Bearer khi `requiresAuth`; không gắn khi `requiresAuth = false`; 4xx/5xx → `http`; `URLError.notConnectedToInternet` → `noConnection`; JSON sai → `decoding`; 401 → refresh → retry thành công; refresh thất bại → `unauthorized` + token bị xoá + callback expired được gọi.
- `TokenRefresherTests`: lưu token mới; 5 lời gọi `refresh()` đồng thời → closure refresh chạy đúng 1 lần; token đã đổi thì không refresh; refresh lỗi → xoá token + expired.
- `AppEnvironmentTests`, `ValidatorTests`, `UserDefaultsStoreTests`, `InMemoryKeychainStoreTests`, `EndpointTests`, `NetworkLoggerTests`, `PageTests`, `SessionEventBroadcasterTests`, `LoginUseCaseTests`, `MapperTests` (gồm map `APIError → DomainError`), `LocalOnboardingRepositoryTests`, `DomainErrorMessageTests`, `OnboardingViewModelTests`, `ProfileViewModelTests`, `LocalizationTests` (bundle có `vi.lproj` và bản dịch).
- `TokenStoreTests` (với `InMemoryKeychainStore`): save/load/clear.
- `RemoteAuthRepositoryTests`: login lưu token + phát `.loggedIn`; login 400 → `invalidCredentials`; logout xoá token + phát `.loggedOut`.
- `RemoteProductRepositoryTests`: gọi đúng path `/auth/products` kèm `limit`/`skip`; map trang đúng, `hasMore`; 401 → refresh → retry trả về danh sách.
- `LoginViewModelTests`: username rỗng → lỗi inline; sai mật khẩu → `alertMessage`; thành công → `isLoading` về false, không có lỗi.
- `HomeViewModelTests`: load lần đầu; load more nối trang; không load more khi `hasMore == false`; refresh reset danh sách.
- `AppRouterTests`: route ban đầu là `.launching`; 3 nhánh route sau `start()`; nhận `.expired` → `.login`.
- Tiêu chí hoàn thành: `xcodebuild test -scheme Dev -destination 'platform=iOS Simulator,name=<iPhone có sẵn>'` pass (dùng simulator iPhone bất kỳ đã cài, chọn qua `xcrun simctl list devices available`); build được cả 3 scheme.

## 12. Rename script
`scripts/rename.sh <NewName> <com.company.bundleid>`:
1. Kiểm tra working tree sạch và tham số hợp lệ (`NewName` chỉ gồm chữ, số, `_`).
2. `git mv` folder `swift_ui_template/`, `swift_ui_templateTests/`, `swift_ui_template.xcodeproj/`.
3. `sed` (tương thích BSD/macOS) thay `swift_ui_template` → `NewName` và `com.app.opt.swift-ui-template` → bundle id mới trong `project.pbxproj`, `*.xcscheme`, `*.xcconfig`, `*.swift`, `README.md`; đặt `APP_NAME = NewName` trong `Base.xcconfig`.
4. In hướng dẫn: mở project, chạy `xcodebuild build -scheme Dev`.

## 13. README
Mô tả kiến trúc + sơ đồ phụ thuộc, cách clone → rename → chạy, tài khoản test DummyJSON, cách bật `-UseMockData`, cách thêm feature mới (Endpoint → DTO → Mapper → Repository → UseCase → ViewModel → View → đăng ký trong `AppContainer`), cách thêm môi trường/base URL, các phần cố ý chưa làm.

## 14. Ngoài phạm vi (YAGNI)
Đăng ký, quên mật khẩu, social login, push notification, analytics/crash reporting, cache offline, đổi ngôn ngữ trong app, upload/download file, network monitor, Settings tab riêng, theme switcher. README ghi chỗ nên thêm từng phần.
