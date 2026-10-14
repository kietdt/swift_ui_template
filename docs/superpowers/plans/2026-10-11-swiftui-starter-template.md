# SwiftUI Starter Template — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Biến project Xcode trống `swift_ui_template` thành template clone → rename → build ngay, có sẵn network (refresh token), storage (UserDefaults + Keychain), utils, Domain/Data layer và 3 luồng Onboarding → Login → Dashboard.

**Architecture:** MVVM + Clean Architecture trong 1 app target, chia layer bằng folder (`Core`, `Domain`, `Data`, `Presentation`, `App`). ViewModel là `@Observable`, DI thủ công qua `AppContainer`. Network dùng `URLSession` async/await, gặp 401 thì `TokenRefresher` (actor) refresh một lần rồi retry. Backend mẫu là DummyJSON; mock repository chạy offline.

**Tech Stack:** Swift 6.2 (Xcode 26), SwiftUI, iOS 17+, Observation, Swift Testing, Security framework, OSLog. Không dùng thư viện bên thứ ba.

**Spec:** `docs/superpowers/specs/2026-10-11-swiftui-template-design.md`

---

## Đã kiểm chứng trước khi viết plan

Toàn bộ code trong plan đã được build và chạy trên một bản copy của repo (Xcode 26.6, simulator iPhone 17 / iOS 26.5):
- `Dev`, `Staging`, `Prod` đều build sạch, không warning.
- 90 test case pass.
- Gọi DummyJSON thật: login sai/đúng, `/auth/me`, `/auth/products`, tự refresh khi access token hỏng, báo `.expired` khi refresh token sai.
- `scripts/rename.sh MyApp com.company.myapp` đổi tên xong vẫn build và test pass.

## Quy ước khi thực hiện

- Chạy mọi lệnh từ thư mục gốc repo.
- Đặt biến simulator một lần cho mỗi shell (chọn máy có trong `xcrun simctl list devices available`):

```sh
DEST='platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

- Project dùng *file system synchronized groups*: tạo file trong `swift_ui_template/` hoặc `swift_ui_templateTests/` là tự vào target, **không** sửa `project.pbxproj` (trừ Task 2).
- Concurrency: target bật default isolation `MainActor`. Mọi type dùng ngoài main (DTO, Domain model, repository, network, storage) khai báo `nonisolated` + `Sendable` đúng như code mẫu.
- `MemberImportVisibility` đang bật: file dùng `AppLogger` phải `import OSLog`; file dùng `UIColor`/`UIApplication` phải `import UIKit`.
- Bước "chạy test → FAIL" ở Swift thường là **lỗi compile** của test target (type chưa tồn tại). Vậy là đúng kỳ vọng.
- Mỗi task kết thúc bằng một commit.

## Bản đồ file

| Layer | File chính | Trách nhiệm |
|---|---|---|
| Config | `Configs/*.xcconfig`, `Configs/Info.plist`, `Core/Config/AppEnvironment.swift` | Giá trị theo môi trường Dev/Staging/Prod |
| Core/Utils | `AppLogger`, `Validator`, `String+Trimmed`, `Bundle+AppInfo` | Tiện ích thuần |
| Core/Storage | `PreferenceKey`, `KeyValueStore`, `UserDefaultsStore`, `KeychainStore`, `SystemKeychainStore`, `InMemoryKeychainStore` | Lưu trữ thường và bảo mật |
| Core/Network | `HTTPMethod`, `Endpoint`, `APIError`, `AuthTokens`, `TokenProvider`, `TokenRefresher`, `NetworkLogger`, `APIClient`, `URLSessionAPIClient` | Gọi API, refresh token |
| Domain | `Models/*`, `Errors/DomainError`, `Repositories/*` (protocol), `UseCases/*` | Nghiệp vụ, không biết HTTP |
| Data | `DTOs/*`, `Mappers/*`, `Remote/*Endpoint`, `Local/TokenStore`, `Local/SessionEventBroadcaster`, `Repositories/*`, `Mocks/*` | Hiện thực repository |
| Presentation | `Common/*`, `Onboarding/*`, `Auth/Login/*`, `Dashboard/*` | View + ViewModel |
| App | `MainApp`, `AppContainer`, `AppRouter`, `RootView` | Composition root, điều hướng cấp cao |
| Tests | `swift_ui_templateTests/{Helpers,Core,Domain,Data,Presentation,App}` | Swift Testing |
| Tooling | `.gitignore`, `scripts/rename.sh`, `README.md` | Repo hygiene, đổi tên, tài liệu |

---

### Task 1: Repo hygiene và commit project gốc

**Files:**
- Create: `.gitignore`
- Untrack: `swift_ui_template.xcodeproj/xcuserdata/`

Hiện các file Xcode đang ở trạng thái staged (chưa commit), kể cả `xcuserdata` (dữ liệu cá nhân của Xcode, không nên commit).

- [ ] **Step 1: Tạo `.gitignore`**

`.gitignore`:

```gitignore
# Xcode user state
xcuserdata/
*.xcuserstate
*.xcscmblueprint

# Build output
build/
DerivedData/
*.ipa
*.dSYM.zip
*.dSYM

# macOS
.DS_Store
```

- [ ] **Step 2: Bỏ `xcuserdata` khỏi index và commit project gốc**

```sh
git rm -r -q --cached swift_ui_template.xcodeproj/xcuserdata
git add .gitignore
git status --short
```

Expected: chỉ còn các file `A` của project (pbxproj, workspace, Assets, `ContentView.swift`, `swift_ui_templateApp.swift`) và `.gitignore`; không còn dòng `xcuserdata`.

```sh
git commit -m "chore: import Xcode project and add .gitignore" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Cấu hình project — iOS 17, Swift 6, Dev/Staging/Prod, test target

**Files:**
- Create: `Configs/Base.xcconfig`, `Configs/Dev.xcconfig`, `Configs/Staging.xcconfig`, `Configs/Prod.xcconfig`, `Configs/Info.plist`
- Replace: `swift_ui_template.xcodeproj/project.pbxproj`
- Create: `swift_ui_template.xcodeproj/xcshareddata/xcschemes/{Dev,Staging,Prod}.xcscheme`
- Move: `swift_ui_template/swift_ui_templateApp.swift` → `swift_ui_template/App/MainApp.swift`; `swift_ui_template/Assets.xcassets` → `swift_ui_template/Resources/Assets.xcassets`
- Create: `swift_ui_template/Core/Config/AppEnvironment.swift`
- Test: `swift_ui_templateTests/Core/AppEnvironmentTests.swift`

Thay đổi trong `project.pbxproj` so với bản gốc:
- Configuration `Debug`/`Release` → `Dev` (dựa trên Debug), `Staging` và `Prod` (dựa trên Release), cho project và cả 2 target.
- `IPHONEOS_DEPLOYMENT_TARGET = 17.0`; `SWIFT_VERSION = 6.0`.
- App target: mỗi configuration có `baseConfigurationReference` tới xcconfig tương ứng; bỏ `PRODUCT_BUNDLE_IDENTIFIER` khỏi pbxproj (giờ nằm trong `Base.xcconfig`).
- Thêm group `Configs` (file reference cho 4 xcconfig và `Info.plist`).
- Thêm target `swift_ui_templateTests` (unit-test bundle, hosted trong app, synchronized group `swift_ui_templateTests`, cùng isolation `MainActor`).
- `knownRegions` thêm `vi`.

- [ ] **Step 1: Tạo các file cấu hình môi trường**

`Configs/Base.xcconfig`:

```text
// Settings shared by every environment. Environment files include this one.
// `scripts/rename.sh` rewrites APP_NAME and BASE_BUNDLE_IDENTIFIER.

APP_NAME = Template
BASE_BUNDLE_IDENTIFIER = com.app.opt.swift-ui-template

PRODUCT_BUNDLE_IDENTIFIER = $(BASE_BUNDLE_IDENTIFIER)$(BUNDLE_ID_SUFFIX)
INFOPLIST_FILE = Configs/Info.plist
INFOPLIST_KEY_CFBundleDisplayName = $(APP_DISPLAY_NAME)
```

`Configs/Dev.xcconfig`:

```text
#include "Base.xcconfig"

APP_ENVIRONMENT = dev
APP_DISPLAY_NAME = $(APP_NAME) Dev
BUNDLE_ID_SUFFIX = .dev

// `//` starts a comment in .xcconfig files, so the URL is split with $().
// Replace with this environment's backend.
API_BASE_URL = https:/$()/dummyjson.com
```

`Configs/Staging.xcconfig`:

```text
#include "Base.xcconfig"

APP_ENVIRONMENT = staging
APP_DISPLAY_NAME = $(APP_NAME) Stg
BUNDLE_ID_SUFFIX = .stg

// `//` starts a comment in .xcconfig files, so the URL is split with $().
// Replace with this environment's backend.
API_BASE_URL = https:/$()/dummyjson.com
```

`Configs/Prod.xcconfig`:

```text
#include "Base.xcconfig"

APP_ENVIRONMENT = prod
APP_DISPLAY_NAME = $(APP_NAME)
BUNDLE_ID_SUFFIX =

// `//` starts a comment in .xcconfig files, so the URL is split with $().
// Replace with this environment's backend.
API_BASE_URL = https:/$()/dummyjson.com
```

`Configs/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_BASE_URL</key>
	<string>$(API_BASE_URL)</string>
	<key>APP_ENVIRONMENT</key>
	<string>$(APP_ENVIRONMENT)</string>
</dict>
</plist>
```

- [ ] **Step 2: Thay toàn bộ `project.pbxproj`**

Ghi đè file bằng nội dung sau (giữ nguyên các ID cũ của app target; ID mới bắt đầu bằng `E6206C2x`/`E6206C3x`):

`swift_ui_template.xcodeproj/project.pbxproj`:

```text
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 77;
	objects = {

/* Begin PBXContainerItemProxy section */
		E6206C36307A91470007B334 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = E6206C05307A91460007B334 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = E6206C0C307A91460007B334;
			remoteInfo = swift_ui_template;
		};
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
		E6206C0D307A91460007B334 /* swift_ui_template.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = swift_ui_template.app; sourceTree = BUILT_PRODUCTS_DIR; };
		E6206C21307A91470007B334 /* Base.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Base.xcconfig; sourceTree = "<group>"; };
		E6206C22307A91470007B334 /* Dev.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Dev.xcconfig; sourceTree = "<group>"; };
		E6206C23307A91470007B334 /* Staging.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Staging.xcconfig; sourceTree = "<group>"; };
		E6206C24307A91470007B334 /* Prod.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Prod.xcconfig; sourceTree = "<group>"; };
		E6206C25307A91470007B334 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
		E6206C31307A91470007B334 /* swift_ui_templateTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = swift_ui_templateTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		E6206C0F307A91460007B334 /* swift_ui_template */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = swift_ui_template;
			sourceTree = "<group>";
		};
		E6206C32307A91470007B334 /* swift_ui_templateTests */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = swift_ui_templateTests;
			sourceTree = "<group>";
		};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
		E6206C0A307A91460007B334 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		E6206C34307A91470007B334 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		E6206C04307A91460007B334 = {
			isa = PBXGroup;
			children = (
				E6206C20307A91470007B334 /* Configs */,
				E6206C0F307A91460007B334 /* swift_ui_template */,
				E6206C32307A91470007B334 /* swift_ui_templateTests */,
				E6206C0E307A91460007B334 /* Products */,
			);
			sourceTree = "<group>";
		};
		E6206C0E307A91460007B334 /* Products */ = {
			isa = PBXGroup;
			children = (
				E6206C0D307A91460007B334 /* swift_ui_template.app */,
				E6206C31307A91470007B334 /* swift_ui_templateTests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		};
		E6206C20307A91470007B334 /* Configs */ = {
			isa = PBXGroup;
			children = (
				E6206C21307A91470007B334 /* Base.xcconfig */,
				E6206C22307A91470007B334 /* Dev.xcconfig */,
				E6206C23307A91470007B334 /* Staging.xcconfig */,
				E6206C24307A91470007B334 /* Prod.xcconfig */,
				E6206C25307A91470007B334 /* Info.plist */,
			);
			path = Configs;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		E6206C0C307A91460007B334 /* swift_ui_template */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = E6206C18307A91470007B334 /* Build configuration list for PBXNativeTarget "swift_ui_template" */;
			buildPhases = (
				E6206C09307A91460007B334 /* Sources */,
				E6206C0A307A91460007B334 /* Frameworks */,
				E6206C0B307A91460007B334 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				E6206C0F307A91460007B334 /* swift_ui_template */,
			);
			name = swift_ui_template;
			packageProductDependencies = (
			);
			productName = swift_ui_template;
			productReference = E6206C0D307A91460007B334 /* swift_ui_template.app */;
			productType = "com.apple.product-type.application";
		};
		E6206C30307A91470007B334 /* swift_ui_templateTests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = E6206C38307A91470007B334 /* Build configuration list for PBXNativeTarget "swift_ui_templateTests" */;
			buildPhases = (
				E6206C33307A91470007B334 /* Sources */,
				E6206C34307A91470007B334 /* Frameworks */,
				E6206C35307A91470007B334 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				E6206C37307A91470007B334 /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				E6206C32307A91470007B334 /* swift_ui_templateTests */,
			);
			name = swift_ui_templateTests;
			packageProductDependencies = (
			);
			productName = swift_ui_templateTests;
			productReference = E6206C31307A91470007B334 /* swift_ui_templateTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		E6206C05307A91460007B334 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2660;
				LastUpgradeCheck = 2660;
				TargetAttributes = {
					E6206C0C307A91460007B334 = {
						CreatedOnToolsVersion = 26.6;
					};
					E6206C30307A91470007B334 = {
						CreatedOnToolsVersion = 26.6;
						TestTargetID = E6206C0C307A91460007B334;
					};
				};
			};
			buildConfigurationList = E6206C08307A91460007B334 /* Build configuration list for PBXProject "swift_ui_template" */;
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				vi,
				Base,
			);
			mainGroup = E6206C04307A91460007B334;
			minimizedProjectReferenceProxies = 1;
			preferredProjectObjectVersion = 77;
			productRefGroup = E6206C0E307A91460007B334 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				E6206C0C307A91460007B334 /* swift_ui_template */,
				E6206C30307A91470007B334 /* swift_ui_templateTests */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		E6206C0B307A91460007B334 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		E6206C35307A91470007B334 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		E6206C09307A91460007B334 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		E6206C33307A91470007B334 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		E6206C37307A91470007B334 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = E6206C0C307A91460007B334 /* swift_ui_template */;
			targetProxy = E6206C36307A91470007B334 /* PBXContainerItemProxy */;
		};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
		E6206C16307A91470007B334 /* Dev */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Dev;
		};
		E6206C26307A91470007B334 /* Staging */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				VALIDATE_PRODUCT = YES;
			};
			name = Staging;
		};
		E6206C17307A91470007B334 /* Prod */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				VALIDATE_PRODUCT = YES;
			};
			name = Prod;
		};
		E6206C19307A91470007B334 /* Dev */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = E6206C22307A91470007B334 /* Dev.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_NAME = "$(TARGET_NAME)";
				STRING_CATALOG_GENERATE_SYMBOLS = YES;
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Dev;
		};
		E6206C27307A91470007B334 /* Staging */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = E6206C23307A91470007B334 /* Staging.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_NAME = "$(TARGET_NAME)";
				STRING_CATALOG_GENERATE_SYMBOLS = YES;
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Staging;
		};
		E6206C1A307A91470007B334 /* Prod */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = E6206C24307A91470007B334 /* Prod.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_NAME = "$(TARGET_NAME)";
				STRING_CATALOG_GENERATE_SYMBOLS = YES;
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Prod;
		};
		E6206C39307A91470007B334 /* Dev */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "com.app.opt.swift-ui-template.tests";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/swift_ui_template.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/swift_ui_template";
			};
			name = Dev;
		};
		E6206C3A307A91470007B334 /* Staging */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "com.app.opt.swift-ui-template.tests";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/swift_ui_template.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/swift_ui_template";
			};
			name = Staging;
		};
		E6206C3B307A91470007B334 /* Prod */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "com.app.opt.swift-ui-template.tests";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/swift_ui_template.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/swift_ui_template";
			};
			name = Prod;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		E6206C08307A91460007B334 /* Build configuration list for PBXProject "swift_ui_template" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				E6206C16307A91470007B334 /* Dev */,
				E6206C26307A91470007B334 /* Staging */,
				E6206C17307A91470007B334 /* Prod */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Prod;
		};
		E6206C18307A91470007B334 /* Build configuration list for PBXNativeTarget "swift_ui_template" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				E6206C19307A91470007B334 /* Dev */,
				E6206C27307A91470007B334 /* Staging */,
				E6206C1A307A91470007B334 /* Prod */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Prod;
		};
		E6206C38307A91470007B334 /* Build configuration list for PBXNativeTarget "swift_ui_templateTests" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				E6206C39307A91470007B334 /* Dev */,
				E6206C3A307A91470007B334 /* Staging */,
				E6206C3B307A91470007B334 /* Prod */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Prod;
		};
/* End XCConfigurationList section */
	};
	rootObject = E6206C05307A91460007B334 /* Project object */;
}
```

```sh
plutil -lint swift_ui_template.xcodeproj/project.pbxproj
```

Expected: `swift_ui_template.xcodeproj/project.pbxproj: OK`

- [ ] **Step 3: Tạo 3 shared scheme**

Chạy script sau từ thư mục gốc repo (chỉ chạy một lần, không commit script). Scheme `Dev` chứa test target; cả 3 scheme có launch argument `-UseMockData` ở trạng thái tắt.

```sh
sh <<'SCHEMES'
#!/bin/sh
# Generates the shared Dev / Staging / Prod schemes. Only Dev runs the unit tests.
set -eu
DIR=swift_ui_template.xcodeproj/xcshareddata/xcschemes
mkdir -p "$DIR"
APP_REF='            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "E6206C0C307A91460007B334"
               BuildableName = "swift_ui_template.app"
               BlueprintName = "swift_ui_template"
               ReferencedContainer = "container:swift_ui_template.xcodeproj">
            </BuildableReference>'
for CONFIG in Dev Staging Prod; do
  if [ "$CONFIG" = Dev ]; then
    TESTABLES='         <TestableReference
            skipped = "NO"
            parallelizable = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "E6206C30307A91470007B334"
               BuildableName = "swift_ui_templateTests.xctest"
               BlueprintName = "swift_ui_templateTests"
               ReferencedContainer = "container:swift_ui_template.xcodeproj">
            </BuildableReference>
         </TestableReference>'
  else
    TESTABLES=''
  fi
  cat > "$DIR/$CONFIG.xcscheme" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2660"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES"
      buildArchitectures = "Automatic">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
$APP_REF
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "$CONFIG"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
$TESTABLES
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "$CONFIG"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
$APP_REF
      </BuildableProductRunnable>
      <CommandLineArguments>
         <CommandLineArgument
            argument = "-UseMockData"
            isEnabled = "NO">
         </CommandLineArgument>
      </CommandLineArguments>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "$CONFIG"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
$APP_REF
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "$CONFIG">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "$CONFIG"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
EOF
done
SCHEMES
xmllint --noout swift_ui_template.xcodeproj/xcshareddata/xcschemes/*.xcscheme && echo SCHEMES_OK
```

Expected: `SCHEMES_OK`

- [ ] **Step 4: Di chuyển file app và tạo thư mục test**

```sh
mkdir -p swift_ui_template/App swift_ui_template/Resources swift_ui_template/Core/Config swift_ui_templateTests/Core
git mv swift_ui_template/Assets.xcassets swift_ui_template/Resources/Assets.xcassets
git mv swift_ui_template/swift_ui_templateApp.swift swift_ui_template/App/MainApp.swift
```

Ghi đè `swift_ui_template/App/MainApp.swift` (struct đổi tên thành `MainApp`, tạm thời vẫn hiển thị `ContentView`; Task 23 sẽ thay):

`swift_ui_template/App/MainApp.swift`:

```swift
import SwiftUI

@main
struct MainApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

```sh
xcodebuild -list
```

Expected: Targets `swift_ui_template`, `swift_ui_templateTests`; Build Configurations `Dev`, `Staging`, `Prod`; Schemes `Dev`, `Prod`, `Staging`.

- [ ] **Step 5: Viết test thất bại cho `AppEnvironment`**

`swift_ui_templateTests/Core/AppEnvironmentTests.swift`:

```swift
import Foundation
import Testing
@testable import swift_ui_template

struct AppEnvironmentTests {
    @Test func readsDevValuesFromInfoPlist() {
        let environment = AppEnvironment(bundle: .main, arguments: [])

        #expect(environment.name == "dev")
        #expect(environment.baseURL == URL(string: "https://dummyjson.com"))
        #expect(environment.useMockData == false)
        #expect(environment.isDebug)
    }

    @Test func enablesMockDataFromLaunchArgument() {
        let environment = AppEnvironment(bundle: .main, arguments: ["-UseMockData"])

        #expect(environment.useMockData)
    }
}
```

- [ ] **Step 6: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/AppEnvironmentTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: `error: cannot find 'AppEnvironment' in scope` và `** TEST FAILED **`.

- [ ] **Step 7: Viết `AppEnvironment`**

`swift_ui_template/Core/Config/AppEnvironment.swift`:

```swift
import Foundation

/// Values that differ per build configuration (Dev / Staging / Prod).
/// They come from `Configs/*.xcconfig` through `Configs/Info.plist`.
nonisolated struct AppEnvironment: Sendable {
    let name: String
    let baseURL: URL
    /// `true` when the app is launched with the `-UseMockData` argument.
    let useMockData: Bool

    static let current = AppEnvironment(bundle: .main, arguments: ProcessInfo.processInfo.arguments)

    var isDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    init(name: String, baseURL: URL, useMockData: Bool) {
        self.name = name
        self.baseURL = baseURL
        self.useMockData = useMockData
    }

    init(bundle: Bundle, arguments: [String]) {
        guard
            let urlString = bundle.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
            let url = URL(string: urlString),
            url.scheme != nil
        else {
            fatalError("API_BASE_URL is missing or invalid. Check Configs/*.xcconfig and Configs/Info.plist.")
        }
        self.init(
            name: bundle.object(forInfoDictionaryKey: "APP_ENVIRONMENT") as? String ?? "unknown",
            baseURL: url,
            useMockData: arguments.contains("-UseMockData")
        )
    }
}
```

- [ ] **Step 8: Chạy test, kỳ vọng PASS và kiểm tra Info.plist đã build**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/AppEnvironmentTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 2 test case `passed`, `** TEST SUCCEEDED **`.

```sh
xcodebuild build -scheme Dev -destination "$DEST" -derivedDataPath build/dd -quiet
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" -c "Print :CFBundleDisplayName" -c "Print :API_BASE_URL" -c "Print :APP_ENVIRONMENT" \
  build/dd/Build/Products/Dev-iphonesimulator/swift_ui_template.app/Info.plist
```

Expected (4 dòng): `com.app.opt.swift-ui-template.dev`, `Template Dev`, `https://dummyjson.com`, `dev`. (`build/` đã nằm trong `.gitignore`.)

- [ ] **Step 9: Commit**

```sh
git add Configs \
        swift_ui_template.xcodeproj \
        swift_ui_template \
        swift_ui_templateTests
git commit -m "build: add Dev/Staging/Prod configs, Swift 6, iOS 17 and test target" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Core/Utils: logger, validator, extensions

Tiện ích dùng chung: `AppLogger` (os.Logger theo category), `Validator`, extension `String.trimmed` và `Bundle.appVersion`.

**Files:**
- Create: `swift_ui_template/Core/Utils/AppLogger.swift`
- Create: `swift_ui_template/Core/Utils/Validator.swift`
- Create: `swift_ui_template/Core/Utils/Extensions/String+Trimmed.swift`
- Create: `swift_ui_template/Core/Utils/Extensions/Bundle+AppInfo.swift`
- Test: `swift_ui_templateTests/Core/ValidatorTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Core/ValidatorTests.swift`:

```swift
import Testing
@testable import swift_ui_template

struct ValidatorTests {
    @Test(arguments: ["", "   ", "\n"])
    func blankStringsAreRejected(value: String) {
        #expect(!Validator.isNotBlank(value))
    }

    @Test func nonBlankStringIsAccepted() {
        #expect(Validator.isNotBlank(" emilys "))
    }

    @Test func minLength() {
        #expect(Validator.hasMinLength("123456", 6))
        #expect(!Validator.hasMinLength("12345", 6))
    }

    @Test func email() {
        #expect(Validator.isValidEmail("emily@example.com"))
        #expect(!Validator.isValidEmail("emily@"))
        #expect(!Validator.isValidEmail("not an email"))
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/ValidatorTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: cannot find 'Validator' in scope`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/Core/Utils/AppLogger.swift`:

```swift
import Foundation
import OSLog

/// Central `os.Logger` instances. Filter by category in Console.app or the Xcode console.
nonisolated enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "app"

    static let network = Logger(subsystem: subsystem, category: "network")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let storage = Logger(subsystem: subsystem, category: "storage")
}
```

`swift_ui_template/Core/Utils/Validator.swift`:

```swift
import Foundation

/// Pure input checks shared by use cases and view models.
nonisolated enum Validator {
    static func isNotBlank(_ value: String) -> Bool {
        !value.trimmed.isEmpty
    }

    static func hasMinLength(_ value: String, _ minLength: Int) -> Bool {
        value.count >= minLength
    }

    static func isValidEmail(_ value: String) -> Bool {
        value.wholeMatch(of: /[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/) != nil
    }
}
```

`swift_ui_template/Core/Utils/Extensions/String+Trimmed.swift`:

```swift
import Foundation

nonisolated extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

`swift_ui_template/Core/Utils/Extensions/Bundle+AppInfo.swift`:

```swift
import Foundation

nonisolated extension Bundle {
    var appVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    var buildNumber: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }
}
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/ValidatorTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 6 test case của `ValidatorTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/Core/Utils/AppLogger.swift \
        swift_ui_template/Core/Utils/Extensions/Bundle+AppInfo.swift \
        swift_ui_template/Core/Utils/Extensions/String+Trimmed.swift \
        swift_ui_template/Core/Utils/Validator.swift \
        swift_ui_templateTests/Core/ValidatorTests.swift
git commit -m "feat(core): add logger, validator and small extensions" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Core/Storage: KeyValueStore trên UserDefaults

Lưu dữ liệu không nhạy cảm bằng key có kiểu (`PreferenceKey<Value>`). Kiểu property-list lưu trực tiếp, kiểu `Codable` khác lưu dạng JSON.

**Files:**
- Create: `swift_ui_template/Core/Storage/PreferenceKey.swift`
- Create: `swift_ui_template/Core/Storage/KeyValueStore.swift`
- Create: `swift_ui_template/Core/Storage/UserDefaultsStore.swift`
- Test: `swift_ui_templateTests/Helpers/TestFixtures.swift`
- Test: `swift_ui_templateTests/Core/UserDefaultsStoreTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Helpers/TestFixtures.swift`:

```swift
import Foundation

/// Shared test data. Feature-specific fixtures live in `TestFixtures+*.swift`.
nonisolated enum TestFixtures {
    /// A fresh, empty `UserDefaults` suite so tests never share state.
    static func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "tests-\(UUID().uuidString)")!
    }

    /// Unique host per call, for `URLProtocolStub`.
    static func uniqueHost() -> String {
        "\(UUID().uuidString.lowercased()).test"
    }
}
```

`swift_ui_templateTests/Core/UserDefaultsStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import swift_ui_template

private nonisolated struct Profile: Codable, Equatable, Sendable {
    let name: String
    let age: Int
}

private extension PreferenceKey where Value == Profile {
    static var profile: PreferenceKey<Profile> {
        PreferenceKey(name: "profile", defaultValue: Profile(name: "", age: 0))
    }
}

struct UserDefaultsStoreTests {
    private let store = UserDefaultsStore(defaults: TestFixtures.makeDefaults())

    @Test func returnsDefaultValueWhenUnset() {
        #expect(store.value(for: .hasSeenOnboarding) == false)
    }

    @Test func storesPropertyListValues() {
        store.set(true, for: .hasSeenOnboarding)

        #expect(store.value(for: .hasSeenOnboarding) == true)
    }

    @Test func storesCodableValues() {
        let profile = Profile(name: "Emily", age: 28)

        store.set(profile, for: .profile)

        #expect(store.value(for: .profile) == profile)
    }

    @Test func removeRestoresDefault() {
        store.set(true, for: .hasSeenOnboarding)

        store.remove(.hasSeenOnboarding)

        #expect(store.value(for: .hasSeenOnboarding) == false)
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/UserDefaultsStoreTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: cannot find 'UserDefaultsStore' in scope`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/Core/Storage/PreferenceKey.swift`:

```swift
import Foundation

/// A typed key for `KeyValueStore`. Declare app keys in an extension, for example:
/// `static var hasSeenOnboarding: PreferenceKey<Bool> { .init(name: "hasSeenOnboarding", defaultValue: false) }`
nonisolated struct PreferenceKey<Value: Codable & Sendable>: Sendable {
    let name: String
    let defaultValue: Value
}

nonisolated extension PreferenceKey where Value == Bool {
    static var hasSeenOnboarding: PreferenceKey<Bool> {
        PreferenceKey(name: "hasSeenOnboarding", defaultValue: false)
    }
}
```

`swift_ui_template/Core/Storage/KeyValueStore.swift`:

```swift
import Foundation

/// Non-sensitive key/value storage (feature flags, "seen" markers, user settings).
/// Never store tokens or passwords here — use `KeychainStore`.
nonisolated protocol KeyValueStore: Sendable {
    func value<Value>(for key: PreferenceKey<Value>) -> Value
    func set<Value>(_ value: Value, for key: PreferenceKey<Value>)
    func remove<Value>(_ key: PreferenceKey<Value>)
}
```

`swift_ui_template/Core/Storage/UserDefaultsStore.swift`:

```swift
import Foundation
import OSLog

/// `KeyValueStore` backed by `UserDefaults`.
/// Property-list types are stored as-is; other `Codable` values are stored as JSON `Data`.
nonisolated final class UserDefaultsStore: KeyValueStore, @unchecked Sendable {
    // UserDefaults is thread-safe; @unchecked is needed because it is not marked Sendable.
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func value<Value>(for key: PreferenceKey<Value>) -> Value {
        guard let object = defaults.object(forKey: key.name) else { return key.defaultValue }
        if let value = object as? Value { return value }
        if let data = object as? Data, let value = try? JSONDecoder().decode(Value.self, from: data) {
            return value
        }
        return key.defaultValue
    }

    func set<Value>(_ value: Value, for key: PreferenceKey<Value>) {
        if Self.isPropertyListValue(value) {
            defaults.set(value, forKey: key.name)
        } else if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key.name)
        } else {
            AppLogger.storage.error("Failed to encode value for key \(key.name, privacy: .public)")
        }
    }

    func remove<Value>(_ key: PreferenceKey<Value>) {
        defaults.removeObject(forKey: key.name)
    }

    private static func isPropertyListValue(_ value: Any) -> Bool {
        value is Bool || value is Int || value is Double || value is String || value is Data || value is Date
    }
}
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/UserDefaultsStoreTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 4 test case của `UserDefaultsStoreTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/Core/Storage/KeyValueStore.swift \
        swift_ui_template/Core/Storage/PreferenceKey.swift \
        swift_ui_template/Core/Storage/UserDefaultsStore.swift \
        swift_ui_templateTests/Core/UserDefaultsStoreTests.swift \
        swift_ui_templateTests/Helpers/TestFixtures.swift
git commit -m "feat(core): add typed KeyValueStore backed by UserDefaults" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Core/Storage: KeychainStore

Lưu bí mật (token) trong Keychain. `SystemKeychainStore` dùng Security framework; `InMemoryKeychainStore` cho test, preview và mock mode.

**Files:**
- Create: `swift_ui_template/Core/Storage/KeychainStore.swift`
- Create: `swift_ui_template/Core/Storage/SystemKeychainStore.swift`
- Create: `swift_ui_template/Core/Storage/InMemoryKeychainStore.swift`
- Test: `swift_ui_templateTests/Core/InMemoryKeychainStoreTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Core/InMemoryKeychainStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import swift_ui_template

private nonisolated struct Credentials: Codable, Equatable, Sendable {
    let user: String
    let secret: String
}

struct InMemoryKeychainStoreTests {
    @Test func roundTripsCodableValues() throws {
        let keychain = InMemoryKeychainStore()
        let credentials = Credentials(user: "emilys", secret: "s3cret")

        try keychain.setValue(credentials, for: "credentials")

        #expect(try keychain.value(Credentials.self, for: "credentials") == credentials)
    }

    @Test func missingKeyReturnsNil() throws {
        #expect(try InMemoryKeychainStore().data(for: "missing") == nil)
    }

    @Test func removeDeletesValue() throws {
        let keychain = InMemoryKeychainStore()
        try keychain.set(Data("secret".utf8), for: "key")

        try keychain.remove("key")

        #expect(try keychain.data(for: "key") == nil)
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/InMemoryKeychainStoreTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: cannot find 'InMemoryKeychainStore' in scope`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/Core/Storage/KeychainStore.swift`:

```swift
import Foundation

/// Secure storage for secrets such as auth tokens.
nonisolated protocol KeychainStore: Sendable {
    func data(for key: String) throws -> Data?
    func set(_ data: Data, for key: String) throws
    func remove(_ key: String) throws
}

nonisolated extension KeychainStore {
    func value<Value: Decodable>(_ type: Value.Type, for key: String) throws -> Value? {
        guard let data = try data(for: key) else { return nil }
        return try JSONDecoder().decode(Value.self, from: data)
    }

    func setValue<Value: Encodable>(_ value: Value, for key: String) throws {
        try set(JSONEncoder().encode(value), for: key)
    }
}

nonisolated enum KeychainError: Error, Equatable {
    case unhandled(OSStatus)
}
```

`swift_ui_template/Core/Storage/SystemKeychainStore.swift`:

```swift
import Foundation
import Security

/// `KeychainStore` backed by the iOS Keychain (generic passwords, this device only).
nonisolated struct SystemKeychainStore: KeychainStore {
    let service: String

    func data(for key: String) throws -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess: return result as? Data
        case errSecItemNotFound: return nil
        default: throw KeychainError.unhandled(status)
        }
    }

    func set(_ data: Data, for key: String) throws {
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery(for: key) as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var query = baseQuery(for: key)
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unhandled(addStatus) }
        default:
            throw KeychainError.unhandled(updateStatus)
        }
    }

    func remove(_ key: String) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
```

`swift_ui_template/Core/Storage/InMemoryKeychainStore.swift`:

```swift
import Foundation
import os

/// `KeychainStore` kept in memory. Used by tests, SwiftUI previews and mock mode.
nonisolated final class InMemoryKeychainStore: KeychainStore {
    private let storage: OSAllocatedUnfairLock<[String: Data]>

    init(initial: [String: Data] = [:]) {
        storage = OSAllocatedUnfairLock(initialState: initial)
    }

    func data(for key: String) throws -> Data? {
        storage.withLock { $0[key] }
    }

    func set(_ data: Data, for key: String) throws {
        storage.withLock { $0[key] = data }
    }

    func remove(_ key: String) throws {
        storage.withLock { _ = $0.removeValue(forKey: key) }
    }
}
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/InMemoryKeychainStoreTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 3 test case của `InMemoryKeychainStoreTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/Core/Storage/InMemoryKeychainStore.swift \
        swift_ui_template/Core/Storage/KeychainStore.swift \
        swift_ui_template/Core/Storage/SystemKeychainStore.swift \
        swift_ui_templateTests/Core/InMemoryKeychainStoreTests.swift
git commit -m "feat(core): add KeychainStore with system and in-memory implementations" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Core/Network: Endpoint, HTTPMethod, APIError

Mô tả một API call bằng protocol `Endpoint` và dựng `URLRequest` từ nó.

**Files:**
- Create: `swift_ui_template/Core/Network/HTTPMethod.swift`
- Create: `swift_ui_template/Core/Network/APIError.swift`
- Create: `swift_ui_template/Core/Network/Endpoint.swift`
- Test: `swift_ui_templateTests/Core/EndpointTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Core/EndpointTests.swift`:

```swift
import Foundation
import Testing
@testable import swift_ui_template

private nonisolated struct Body: Codable, Equatable, Sendable {
    let name: String
}

private nonisolated struct TestEndpoint: Endpoint {
    var path = "/items"
    var method = HTTPMethod.get
    var query: [URLQueryItem] = []
    var body: (any Encodable & Sendable)?
    var headers: [String: String] = [:]
}

struct EndpointTests {
    private let baseURL = URL(string: "https://api.example.com")!

    @Test func buildsURLWithPathAndQuery() throws {
        let endpoint = TestEndpoint(query: [URLQueryItem(name: "limit", value: "20")])

        let request = try endpoint.makeRequest(baseURL: baseURL, encoder: JSONEncoder())

        #expect(request.url?.absoluteString == "https://api.example.com/items?limit=20")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test func encodesJSONBody() throws {
        let endpoint = TestEndpoint(method: .post, body: Body(name: "Emily"))

        let request = try endpoint.makeRequest(baseURL: baseURL, encoder: JSONEncoder())

        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(try JSONDecoder().decode(Body.self, from: #require(request.httpBody)) == Body(name: "Emily"))
    }

    @Test func addsCustomHeaders() throws {
        let endpoint = TestEndpoint(headers: ["X-Trace": "abc"])

        let request = try endpoint.makeRequest(baseURL: baseURL, encoder: JSONEncoder())

        #expect(request.value(forHTTPHeaderField: "X-Trace") == "abc")
    }

    @Test func requiresAuthByDefault() {
        #expect(TestEndpoint().requiresAuth)
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/EndpointTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: cannot find type 'Endpoint' in scope`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/Core/Network/HTTPMethod.swift`:

```swift
import Foundation

nonisolated enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
```

`swift_ui_template/Core/Network/APIError.swift`:

```swift
import Foundation

/// Transport-level errors produced by `APIClient`. The Data layer maps them to `DomainError`.
nonisolated enum APIError: Error, Equatable, Sendable {
    case invalidURL
    case noConnection
    case timeout
    /// The session could not be refreshed; the user must log in again.
    case unauthorized
    case http(status: Int, data: Data)
    case decoding(String)
    case unknown(String)
}
```

`swift_ui_template/Core/Network/Endpoint.swift`:

```swift
import Foundation

/// Describes one API call. Each feature declares its endpoints as an enum conforming to this protocol.
nonisolated protocol Endpoint: Sendable {
    var path: String { get }
    var method: HTTPMethod { get }
    var query: [URLQueryItem] { get }
    var body: (any Encodable & Sendable)? { get }
    var headers: [String: String] { get }
    /// When `true`, `APIClient` attaches the access token and refreshes it on 401.
    var requiresAuth: Bool { get }
}

nonisolated extension Endpoint {
    var query: [URLQueryItem] { [] }
    var body: (any Encodable & Sendable)? { nil }
    var headers: [String: String] { [:] }
    var requiresAuth: Bool { true }

    func makeRequest(baseURL: URL, encoder: JSONEncoder) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }
}
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/EndpointTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 4 test case của `EndpointTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/Core/Network/APIError.swift \
        swift_ui_template/Core/Network/Endpoint.swift \
        swift_ui_template/Core/Network/HTTPMethod.swift \
        swift_ui_templateTests/Core/EndpointTests.swift
git commit -m "feat(network): add Endpoint, HTTPMethod and APIError" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Token: AuthTokens, TokenProvider, TokenStore

`TokenStore` (actor) lưu `AuthTokens` trong Keychain và là `TokenProvider` cho network layer.

**Files:**
- Create: `swift_ui_template/Core/Network/AuthTokens.swift`
- Create: `swift_ui_template/Core/Network/TokenProvider.swift`
- Create: `swift_ui_template/Data/Local/TokenStore.swift`
- Test: `swift_ui_templateTests/Helpers/TestFixtures+Auth.swift`
- Test: `swift_ui_templateTests/Data/TokenStoreTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Helpers/TestFixtures+Auth.swift`:

```swift
import Foundation
@testable import swift_ui_template

nonisolated extension TestFixtures {
    static let tokens = AuthTokens(accessToken: "access-1", refreshToken: "refresh-1")
    static let refreshedTokens = AuthTokens(accessToken: "access-2", refreshToken: "refresh-2")

    static let authResponseJSON = Data("""
    {"id":1,"username":"emilys","email":"emily@example.com","firstName":"Emily","lastName":"Johnson",
     "gender":"female","image":"https://dummyjson.com/icon/emilys/128",
     "accessToken":"access-1","refreshToken":"refresh-1"}
    """.utf8)

    static let userJSON = Data("""
    {"id":1,"username":"emilys","email":"emily@example.com","firstName":"Emily","lastName":"Johnson",
     "image":"https://dummyjson.com/icon/emilys/128","age":28}
    """.utf8)

    static let invalidCredentialsJSON = Data(#"{"message":"Invalid credentials"}"#.utf8)
}
```

`swift_ui_templateTests/Data/TokenStoreTests.swift`:

```swift
import Testing
@testable import swift_ui_template

struct TokenStoreTests {
    @Test func isEmptyInitially() async {
        let store = TokenStore(keychain: InMemoryKeychainStore())

        #expect(await store.accessToken() == nil)
        #expect(await store.refreshToken() == nil)
    }

    @Test func savesAndReadsTokens() async {
        let store = TokenStore(keychain: InMemoryKeychainStore())

        await store.save(TestFixtures.tokens)

        #expect(await store.accessToken() == "access-1")
        #expect(await store.refreshToken() == "refresh-1")
    }

    @Test func clearRemovesTokens() async {
        let store = TokenStore(keychain: InMemoryKeychainStore())
        await store.save(TestFixtures.tokens)

        await store.clear()

        #expect(await store.accessToken() == nil)
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/TokenStoreTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: cannot find type 'AuthTokens' in scope`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/Core/Network/AuthTokens.swift`:

```swift
import Foundation

nonisolated struct AuthTokens: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
}
```

`swift_ui_template/Core/Network/TokenProvider.swift`:

```swift
import Foundation

/// Where `APIClient` and `TokenRefresher` read and write the current tokens.
nonisolated protocol TokenProvider: Sendable {
    func accessToken() async -> String?
    func refreshToken() async -> String?
    func save(_ tokens: AuthTokens) async
    func clear() async
}
```

`swift_ui_template/Data/Local/TokenStore.swift`:

```swift
import Foundation
import OSLog

/// Persists `AuthTokens` in the Keychain. The actor serialises reads and writes.
actor TokenStore: TokenProvider {
    private static let key = "auth.tokens"

    private let keychain: any KeychainStore

    init(keychain: any KeychainStore) {
        self.keychain = keychain
    }

    func accessToken() -> String? {
        load()?.accessToken
    }

    func refreshToken() -> String? {
        load()?.refreshToken
    }

    func save(_ tokens: AuthTokens) {
        do {
            try keychain.setValue(tokens, for: Self.key)
        } catch {
            AppLogger.storage.error("Saving tokens failed: \(String(describing: error), privacy: .public)")
        }
    }

    func clear() {
        do {
            try keychain.remove(Self.key)
        } catch {
            AppLogger.storage.error("Clearing tokens failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func load() -> AuthTokens? {
        do {
            return try keychain.value(AuthTokens.self, for: Self.key)
        } catch {
            AppLogger.storage.error("Reading tokens failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/TokenStoreTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 3 test case của `TokenStoreTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/Core/Network/AuthTokens.swift \
        swift_ui_template/Core/Network/TokenProvider.swift \
        swift_ui_template/Data/Local/TokenStore.swift \
        swift_ui_templateTests/Data/TokenStoreTests.swift \
        swift_ui_templateTests/Helpers/TestFixtures+Auth.swift
git commit -m "feat(auth): store auth tokens in the Keychain" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Core/Network: TokenRefresher

Refresh access token đúng một lần cho mọi request bị 401 đồng thời; bỏ qua nếu token đã được refresh; refresh lỗi thì xoá token và báo hết phiên.

**Files:**
- Create: `swift_ui_template/Core/Network/TokenRefresher.swift`
- Test: `swift_ui_templateTests/Core/TokenRefresherTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Core/TokenRefresherTests.swift`:

```swift
import Foundation
import os
import Testing
@testable import swift_ui_template

struct TokenRefresherTests {
    private func makeStore() async -> TokenStore {
        let store = TokenStore(keychain: InMemoryKeychainStore())
        await store.save(TestFixtures.tokens)
        return store
    }

    @Test func savesRefreshedTokens() async throws {
        let store = await makeStore()
        let refresher = TokenRefresher(
            tokenProvider: store,
            refreshAction: { _ in TestFixtures.refreshedTokens },
            onSessionExpired: {}
        )

        try await refresher.refresh(rejectedToken: "access-1")

        #expect(await store.accessToken() == "access-2")
    }

    @Test func concurrentCallsRefreshOnce() async throws {
        let store = await makeStore()
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let refresher = TokenRefresher(
            tokenProvider: store,
            refreshAction: { _ in
                calls.withLock { $0 += 1 }
                try await Task.sleep(for: .milliseconds(100))
                return TestFixtures.refreshedTokens
            },
            onSessionExpired: {}
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask { try await refresher.refresh(rejectedToken: "access-1") }
            }
            try await group.waitForAll()
        }

        #expect(calls.withLock { $0 } == 1)
    }

    @Test func skipsRefreshWhenTokenAlreadyChanged() async throws {
        let store = await makeStore()
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let refresher = TokenRefresher(
            tokenProvider: store,
            refreshAction: { _ in
                calls.withLock { $0 += 1 }
                return TestFixtures.refreshedTokens
            },
            onSessionExpired: {}
        )

        try await refresher.refresh(rejectedToken: "an-older-token")

        #expect(calls.withLock { $0 } == 0)
    }

    @Test func failedRefreshClearsTokensAndExpiresSession() async {
        let store = await makeStore()
        let expired = OSAllocatedUnfairLock(initialState: false)
        let refresher = TokenRefresher(
            tokenProvider: store,
            refreshAction: { _ in throw APIError.http(status: 403, data: Data()) },
            onSessionExpired: { expired.withLock { $0 = true } }
        )

        await #expect(throws: APIError.unauthorized) {
            try await refresher.refresh(rejectedToken: "access-1")
        }
        #expect(await store.accessToken() == nil)
        #expect(expired.withLock { $0 })
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/TokenRefresherTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: cannot find 'TokenRefresher' in scope`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/Core/Network/TokenRefresher.swift`:

```swift
import Foundation
import OSLog

/// Refreshes the access token once, no matter how many requests hit 401 at the same time.
actor TokenRefresher {
    typealias RefreshAction = @Sendable (_ refreshToken: String) async throws -> AuthTokens

    private let tokenProvider: any TokenProvider
    private let refreshAction: RefreshAction
    private let onSessionExpired: @Sendable () async -> Void
    private var inFlight: Task<Void, Error>?

    init(
        tokenProvider: any TokenProvider,
        refreshAction: @escaping RefreshAction,
        onSessionExpired: @escaping @Sendable () async -> Void
    ) {
        self.tokenProvider = tokenProvider
        self.refreshAction = refreshAction
        self.onSessionExpired = onSessionExpired
    }

    /// - Parameter rejectedToken: the access token the server just rejected. If the stored token
    ///   is already different, another request refreshed it and the caller can simply retry.
    func refresh(rejectedToken: String?) async throws {
        if let inFlight { return try await inFlight.value }
        let currentToken = await tokenProvider.accessToken()
        // Re-check after the suspension above: another caller may have started a refresh.
        if let inFlight { return try await inFlight.value }
        if let currentToken, currentToken != rejectedToken { return }

        let task = Task { try await performRefresh() }
        inFlight = task
        defer { inFlight = nil }
        try await task.value
    }

    private func performRefresh() async throws {
        guard let refreshToken = await tokenProvider.refreshToken() else {
            await expireSession()
            throw APIError.unauthorized
        }
        do {
            let tokens = try await refreshAction(refreshToken)
            await tokenProvider.save(tokens)
        } catch {
            AppLogger.auth.error("Token refresh failed: \(String(describing: error), privacy: .public)")
            await expireSession()
            throw APIError.unauthorized
        }
    }

    private func expireSession() async {
        await tokenProvider.clear()
        await onSessionExpired()
    }
}
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/TokenRefresherTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 4 test case của `TokenRefresherTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/Core/Network/TokenRefresher.swift \
        swift_ui_templateTests/Core/TokenRefresherTests.swift
git commit -m "feat(network): add TokenRefresher that coalesces concurrent refreshes" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Core/Network: APIClient trên URLSession

`URLSessionAPIClient`: gắn Bearer, map lỗi, decode ngoài main thread, gặp 401 thì refresh rồi retry đúng một lần. Log request ở DEBUG và che header Authorization.

**Files:**
- Create: `swift_ui_template/Core/Network/NetworkLogger.swift`
- Create: `swift_ui_template/Core/Network/APIClient.swift`
- Create: `swift_ui_template/Core/Network/URLSessionAPIClient.swift`
- Test: `swift_ui_templateTests/Helpers/URLProtocolStub.swift`
- Test: `swift_ui_templateTests/Core/NetworkLoggerTests.swift`
- Test: `swift_ui_templateTests/Core/URLSessionAPIClientTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Helpers/URLProtocolStub.swift`:

```swift
import Foundation
import os

/// Serves canned responses to a `URLSession` without touching the network.
/// Handlers are keyed by host, so give every test its own host and tests can run in parallel.
nonisolated final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (status: Int, body: Data)

    private static let handlers = OSAllocatedUnfairLock<[String: Handler]>(initialState: [:])

    static func makeSession(host: String, handler: @escaping Handler) -> URLSession {
        handlers.withLock { $0[host] = handler }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard
            let url = request.url,
            let host = url.host(),
            let handler = Self.handlers.withLock({ $0[host] })
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (status, body) = try handler(request)
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
```

`swift_ui_templateTests/Core/NetworkLoggerTests.swift`:

```swift
import Foundation
import Testing
@testable import swift_ui_template

struct NetworkLoggerTests {
    @Test func redactsAuthorizationHeader() {
        var request = URLRequest(url: URL(string: "https://api.example.com")!)
        request.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let headers = NetworkLogger.redactedHeaders(of: request)

        #expect(headers["Authorization"] == "<redacted>")
        #expect(headers["Accept"] == "application/json")
    }
}
```

`swift_ui_templateTests/Core/URLSessionAPIClientTests.swift`:

```swift
import Foundation
import os
import Testing
@testable import swift_ui_template

private nonisolated struct Item: Decodable, Equatable, Sendable {
    let id: Int
}

private nonisolated enum TestEndpoint: Endpoint {
    case secured
    case open

    var path: String { "/item" }
    var method: HTTPMethod { .get }
    var requiresAuth: Bool { self == .secured }
}

struct URLSessionAPIClientTests {
    private let host = TestFixtures.uniqueHost()

    private func makeClient(
        tokens: AuthTokens? = TestFixtures.tokens,
        refresher: (TokenStore) -> TokenRefresher? = { _ in nil },
        handler: @escaping URLProtocolStub.Handler
    ) async -> (URLSessionAPIClient, TokenStore) {
        let store = TokenStore(keychain: InMemoryKeychainStore())
        if let tokens { await store.save(tokens) }
        let client = URLSessionAPIClient(
            baseURL: URL(string: "https://\(host)")!,
            session: URLProtocolStub.makeSession(host: host, handler: handler),
            tokenProvider: store,
            refresher: refresher(store)
        )
        return (client, store)
    }

    @Test func decodesSuccessfulResponse() async throws {
        let (client, _) = await makeClient { _ in (200, Data(#"{"id":7}"#.utf8)) }

        let item: Item = try await client.send(TestEndpoint.secured)

        #expect(item == Item(id: 7))
    }

    @Test func attachesBearerTokenWhenRequired() async throws {
        let header = OSAllocatedUnfairLock<String?>(initialState: nil)
        let (client, _) = await makeClient { request in
            header.withLock { $0 = request.value(forHTTPHeaderField: "Authorization") }
            return (200, Data(#"{"id":1}"#.utf8))
        }

        let _: Item = try await client.send(TestEndpoint.secured)

        #expect(header.withLock { $0 } == "Bearer access-1")
    }

    @Test func omitsBearerTokenForOpenEndpoints() async throws {
        let header = OSAllocatedUnfairLock<String?>(initialState: "unset")
        let (client, _) = await makeClient { request in
            header.withLock { $0 = request.value(forHTTPHeaderField: "Authorization") }
            return (200, Data(#"{"id":1}"#.utf8))
        }

        let _: Item = try await client.send(TestEndpoint.open)

        #expect(header.withLock { $0 } == nil)
    }

    @Test func mapsErrorStatusToHTTPError() async {
        let body = Data(#"{"message":"boom"}"#.utf8)
        let (client, _) = await makeClient { _ in (500, body) }

        await #expect(throws: APIError.http(status: 500, data: body)) {
            let _: Item = try await client.send(TestEndpoint.secured)
        }
    }

    @Test func mapsOfflineToNoConnection() async {
        let (client, _) = await makeClient { _ in throw URLError(.notConnectedToInternet) }

        await #expect(throws: APIError.noConnection) {
            let _: Item = try await client.send(TestEndpoint.secured)
        }
    }

    @Test func mapsInvalidJSONToDecodingError() async {
        let (client, _) = await makeClient { _ in (200, Data("not json".utf8)) }

        await #expect {
            let _: Item = try await client.send(TestEndpoint.secured)
        } throws: { error in
            if case APIError.decoding = error { true } else { false }
        }
    }

    @Test func refreshesAndRetriesOnUnauthorized() async throws {
        let (client, store) = await makeClient(
            refresher: { store in
                TokenRefresher(tokenProvider: store, refreshAction: { _ in TestFixtures.refreshedTokens }, onSessionExpired: {})
            },
            handler: { request in
                request.value(forHTTPHeaderField: "Authorization") == "Bearer access-2"
                    ? (200, Data(#"{"id":1}"#.utf8))
                    : (401, Data())
            }
        )

        let item: Item = try await client.send(TestEndpoint.secured)

        #expect(item == Item(id: 1))
        #expect(await store.accessToken() == "access-2")
    }

    @Test func failedRefreshThrowsUnauthorizedAndExpiresSession() async {
        let expired = OSAllocatedUnfairLock(initialState: false)
        let (client, store) = await makeClient(
            refresher: { store in
                TokenRefresher(
                    tokenProvider: store,
                    refreshAction: { _ in throw APIError.http(status: 403, data: Data()) },
                    onSessionExpired: { expired.withLock { $0 = true } }
                )
            },
            handler: { _ in (401, Data()) }
        )

        await #expect(throws: APIError.unauthorized) {
            let _: Item = try await client.send(TestEndpoint.secured)
        }
        #expect(await store.accessToken() == nil)
        #expect(expired.withLock { $0 })
    }

    @Test func unauthorizedWithoutRefresherThrowsUnauthorized() async {
        let (client, _) = await makeClient { _ in (401, Data()) }

        await #expect(throws: APIError.unauthorized) {
            let _: Item = try await client.send(TestEndpoint.secured)
        }
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/NetworkLoggerTests -only-testing:swift_ui_templateTests/URLSessionAPIClientTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: cannot find 'URLSessionAPIClient' in scope`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/Core/Network/NetworkLogger.swift`:

```swift
import Foundation
import OSLog

/// Logs requests and responses in DEBUG builds only. Never logs the Authorization header value.
nonisolated struct NetworkLogger: Sendable {
    func log(request: URLRequest, response: HTTPURLResponse?, data: Data, duration: TimeInterval) {
        #if DEBUG
        let status = response.map { String($0.statusCode) } ?? "-"
        let body = String(decoding: data.prefix(1_000), as: UTF8.self)
        AppLogger.network.debug("""
        \(request.httpMethod ?? "-", privacy: .public) \(request.url?.absoluteString ?? "-", privacy: .public) → \(status, privacy: .public) (\(Int(duration * 1_000))ms)
        headers: \(Self.redactedHeaders(of: request), privacy: .public)
        body: \(body, privacy: .public)
        """)
        #endif
    }

    func log(request: URLRequest, error: URLError) {
        #if DEBUG
        AppLogger.network.error("\(request.httpMethod ?? "-", privacy: .public) \(request.url?.absoluteString ?? "-", privacy: .public) failed: \(error.code.rawValue)")
        #endif
    }

    static func redactedHeaders(of request: URLRequest) -> [String: String] {
        var headers = request.allHTTPHeaderFields ?? [:]
        if headers["Authorization"] != nil {
            headers["Authorization"] = "<redacted>"
        }
        return headers
    }
}
```

`swift_ui_template/Core/Network/APIClient.swift`:

```swift
import Foundation

nonisolated protocol APIClient: Sendable {
    /// Sends the request and decodes the JSON response body into `T`.
    /// - Throws: `APIError`, or `CancellationError` when the task is cancelled.
    func send<T: Decodable & Sendable>(_ endpoint: some Endpoint) async throws -> T
}
```

`swift_ui_template/Core/Network/URLSessionAPIClient.swift`:

```swift
import Foundation

nonisolated final class URLSessionAPIClient: APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: any TokenProvider
    private let refresher: TokenRefresher?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger: NetworkLogger

    /// - Parameter refresher: pass `nil` for a client that must never refresh (e.g. the one that
    ///   performs the refresh call itself).
    init(
        baseURL: URL,
        session: URLSession = .shared,
        tokenProvider: any TokenProvider,
        refresher: TokenRefresher? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        logger: NetworkLogger = NetworkLogger()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.refresher = refresher
        self.encoder = encoder
        self.decoder = decoder
        self.logger = logger
    }

    func send<T: Decodable & Sendable>(_ endpoint: some Endpoint) async throws -> T {
        let data = try await perform(endpoint, allowRefresh: true)
        return try await Self.decode(T.self, from: data, using: decoder)
    }

    private func perform(_ endpoint: some Endpoint, allowRefresh: Bool) async throws -> Data {
        var request = try endpoint.makeRequest(baseURL: baseURL, encoder: encoder)
        var attachedToken: String?
        if endpoint.requiresAuth, let token = await tokenProvider.accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            attachedToken = token
        }

        let (data, response) = try await load(request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        switch status {
        case 200..<300:
            return data
        case 401 where endpoint.requiresAuth:
            guard allowRefresh, let refresher else { throw APIError.unauthorized }
            try await refresher.refresh(rejectedToken: attachedToken)
            return try await perform(endpoint, allowRefresh: false)
        default:
            throw APIError.http(status: status, data: data)
        }
    }

    private func load(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let start = Date()
        do {
            let (data, response) = try await session.data(for: request)
            logger.log(request: request, response: response as? HTTPURLResponse, data: data, duration: Date().timeIntervalSince(start))
            return (data, response)
        } catch let error as URLError {
            logger.log(request: request, error: error)
            switch error.code {
            case .cancelled: throw CancellationError()
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: throw APIError.noConnection
            case .timedOut: throw APIError.timeout
            default: throw APIError.unknown(error.localizedDescription)
            }
        }
    }

    /// Decodes off the main actor so large payloads never block the UI.
    @concurrent
    private static func decode<T: Decodable & Sendable>(_ type: T.Type, from data: Data, using decoder: JSONDecoder) async throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/NetworkLoggerTests -only-testing:swift_ui_templateTests/URLSessionAPIClientTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 1 test case của `NetworkLoggerTests` `passed` và 9 test case của `URLSessionAPIClientTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/Core/Network/APIClient.swift \
        swift_ui_template/Core/Network/NetworkLogger.swift \
        swift_ui_template/Core/Network/URLSessionAPIClient.swift \
        swift_ui_templateTests/Core/NetworkLoggerTests.swift \
        swift_ui_templateTests/Core/URLSessionAPIClientTests.swift \
        swift_ui_templateTests/Helpers/URLProtocolStub.swift
git commit -m "feat(network): add URLSession-based APIClient with refresh-and-retry" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Domain: models, errors, repository protocols

Kiểu dữ liệu của Domain (chỉ `import Foundation`, tất cả `nonisolated` + `Sendable`) và các protocol repository.

**Files:**
- Create: `swift_ui_template/Domain/Models/User.swift`
- Create: `swift_ui_template/Domain/Models/Product.swift`
- Create: `swift_ui_template/Domain/Models/Page.swift`
- Create: `swift_ui_template/Domain/Models/SessionEvent.swift`
- Create: `swift_ui_template/Domain/Errors/DomainError.swift`
- Create: `swift_ui_template/Domain/Repositories/AuthRepository.swift`
- Create: `swift_ui_template/Domain/Repositories/ProductRepository.swift`
- Create: `swift_ui_template/Domain/Repositories/OnboardingRepository.swift`
- Test: `swift_ui_templateTests/Domain/PageTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Domain/PageTests.swift`:

```swift
import Testing
@testable import swift_ui_template

struct PageTests {
    @Test func hasMoreWhileItemsRemain() {
        let page = Page(items: [1, 2], total: 5, skip: 0, limit: 2)

        #expect(page.hasMore)
    }

    @Test func lastPageHasNoMore() {
        let page = Page(items: [41, 42, 43, 44, 45], total: 45, skip: 40, limit: 20)

        #expect(!page.hasMore)
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/PageTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: cannot find 'Page' in scope`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/Domain/Models/User.swift`:

```swift
import Foundation

nonisolated struct User: Identifiable, Equatable, Sendable {
    let id: Int
    let username: String
    let email: String
    let firstName: String
    let lastName: String
    let avatarURL: URL?

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}
```

`swift_ui_template/Domain/Models/Product.swift`:

```swift
import Foundation

nonisolated struct Product: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let description: String
    let price: Double
    let rating: Double
    let thumbnailURL: URL?
    let imageURLs: [URL]
    let category: String
    let brand: String?
}
```

`swift_ui_template/Domain/Models/Page.swift`:

```swift
import Foundation

/// One page of an offset-paginated list.
nonisolated struct Page<Item: Equatable & Sendable>: Equatable, Sendable {
    let items: [Item]
    let total: Int
    let skip: Int
    let limit: Int

    var hasMore: Bool {
        skip + items.count < total
    }
}
```

`swift_ui_template/Domain/Models/SessionEvent.swift`:

```swift
import Foundation

nonisolated enum SessionEvent: Equatable, Sendable {
    case loggedIn
    case loggedOut
    /// The refresh token was rejected; the user must log in again.
    case expired
}
```

`swift_ui_template/Domain/Errors/DomainError.swift`:

```swift
import Foundation

/// The only error type the Presentation layer handles.
nonisolated enum DomainError: Error, Equatable, Sendable {
    enum InputField: Equatable, Sendable {
        case username
        case password
    }

    enum InputReason: Equatable, Sendable {
        case empty
        case tooShort(min: Int)
    }

    case invalidInput(field: InputField, reason: InputReason)
    case invalidCredentials
    case sessionExpired
    case noConnection
    case server(message: String?)
    case unknown
}
```

`swift_ui_template/Domain/Repositories/AuthRepository.swift`:

```swift
import Foundation

nonisolated protocol AuthRepository: Sendable {
    func login(username: String, password: String) async throws -> User
    func currentUser() async throws -> User
    func logout() async
    func isLoggedIn() async -> Bool
    /// A new stream per call; every subscriber receives every event sent after it subscribed.
    func sessionEvents() -> AsyncStream<SessionEvent>
}
```

`swift_ui_template/Domain/Repositories/ProductRepository.swift`:

```swift
import Foundation

nonisolated protocol ProductRepository: Sendable {
    func fetchProducts(skip: Int, limit: Int) async throws -> Page<Product>
    func fetchProduct(id: Int) async throws -> Product
}
```

`swift_ui_template/Domain/Repositories/OnboardingRepository.swift`:

```swift
import Foundation

nonisolated protocol OnboardingRepository: Sendable {
    func hasSeenOnboarding() -> Bool
    func markOnboardingSeen()
}
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/PageTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 2 test case của `PageTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/Domain/Errors/DomainError.swift \
        swift_ui_template/Domain/Models/Page.swift \
        swift_ui_template/Domain/Models/Product.swift \
        swift_ui_template/Domain/Models/SessionEvent.swift \
        swift_ui_template/Domain/Models/User.swift \
        swift_ui_template/Domain/Repositories/AuthRepository.swift \
        swift_ui_template/Domain/Repositories/OnboardingRepository.swift \
        swift_ui_template/Domain/Repositories/ProductRepository.swift \
        swift_ui_templateTests/Domain/PageTests.swift
git commit -m "feat(domain): add models, DomainError and repository protocols" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Data: SessionEventBroadcaster và mock repositories

Phát `SessionEvent` tới mọi subscriber. Mock repository chạy offline, dùng cho preview, test và chế độ `-UseMockData`.

**Files:**
- Create: `swift_ui_template/Data/Local/SessionEventBroadcaster.swift`
- Create: `swift_ui_template/Data/Mocks/SampleData.swift`
- Create: `swift_ui_template/Data/Mocks/MockAuthRepository.swift`
- Create: `swift_ui_template/Data/Mocks/MockProductRepository.swift`
- Test: `swift_ui_templateTests/Data/SessionEventBroadcasterTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Data/SessionEventBroadcasterTests.swift`:

```swift
import Testing
@testable import swift_ui_template

struct SessionEventBroadcasterTests {
    @Test func deliversEventsToEverySubscriber() async {
        let broadcaster = SessionEventBroadcaster()
        let first = broadcaster.stream()
        let second = broadcaster.stream()

        broadcaster.send(.loggedIn)

        var firstIterator = first.makeAsyncIterator()
        var secondIterator = second.makeAsyncIterator()
        #expect(await firstIterator.next() == .loggedIn)
        #expect(await secondIterator.next() == .loggedIn)
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/SessionEventBroadcasterTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: cannot find 'SessionEventBroadcaster' in scope`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/Data/Local/SessionEventBroadcaster.swift`:

```swift
import Foundation
import os

/// Fans out `SessionEvent`s to every active `AsyncStream` subscriber.
nonisolated final class SessionEventBroadcaster: Sendable {
    private let continuations = OSAllocatedUnfairLock<[UUID: AsyncStream<SessionEvent>.Continuation]>(initialState: [:])

    /// Subscribes immediately; events sent after this call are buffered until the caller iterates.
    func stream() -> AsyncStream<SessionEvent> {
        let (stream, continuation) = AsyncStream<SessionEvent>.makeStream()
        let id = UUID()
        continuations.withLock { $0[id] = continuation }
        continuation.onTermination = { [weak self] _ in
            self?.continuations.withLock { _ = $0.removeValue(forKey: id) }
        }
        return stream
    }

    func send(_ event: SessionEvent) {
        let subscribers = continuations.withLock { Array($0.values) }
        for continuation in subscribers {
            continuation.yield(event)
        }
    }
}
```

`swift_ui_template/Data/Mocks/SampleData.swift`:

```swift
import Foundation

/// Fixed data for mock repositories and SwiftUI previews.
nonisolated enum SampleData {
    static let user = User(
        id: 1,
        username: "emilys",
        email: "emily.johnson@x.dummyjson.com",
        firstName: "Emily",
        lastName: "Johnson",
        avatarURL: URL(string: "https://dummyjson.com/icon/emilys/128")
    )

    static func products(count: Int) -> [Product] {
        (0..<count).map { offset in
            let index = offset + 1
            return Product(
                id: index,
                title: "Product \(index)",
                description: "Sample description for product \(index).",
                price: Double(index) * 1.5,
                rating: 4.5,
                thumbnailURL: nil,
                imageURLs: [],
                category: "sample",
                brand: "Sample Brand"
            )
        }
    }
}
```

`swift_ui_template/Data/Mocks/MockAuthRepository.swift`:

```swift
import Foundation
import os

/// Offline `AuthRepository` for previews, tests and `-UseMockData`.
/// Accepts `emilys` / `emilyspass`, like DummyJSON.
nonisolated final class MockAuthRepository: AuthRepository {
    static let validUsername = "emilys"
    static let validPassword = "emilyspass"

    private let loggedIn: OSAllocatedUnfairLock<Bool>
    private let failure: DomainError?
    private let delay: Duration
    private let events = SessionEventBroadcaster()

    /// - Parameter failure: when set, `login` and `currentUser` always throw it.
    init(isLoggedIn: Bool = false, failure: DomainError? = nil, delay: Duration = .milliseconds(500)) {
        loggedIn = OSAllocatedUnfairLock(initialState: isLoggedIn)
        self.failure = failure
        self.delay = delay
    }

    func login(username: String, password: String) async throws -> User {
        try await Task.sleep(for: delay)
        if let failure { throw failure }
        guard username == Self.validUsername, password == Self.validPassword else {
            throw DomainError.invalidCredentials
        }
        loggedIn.withLock { $0 = true }
        events.send(.loggedIn)
        return SampleData.user
    }

    func currentUser() async throws -> User {
        try await Task.sleep(for: delay)
        if let failure { throw failure }
        return SampleData.user
    }

    func logout() async {
        loggedIn.withLock { $0 = false }
        events.send(.loggedOut)
    }

    func isLoggedIn() async -> Bool {
        loggedIn.withLock { $0 }
    }

    func sessionEvents() -> AsyncStream<SessionEvent> {
        events.stream()
    }

    /// Simulates the API rejecting the refresh token.
    func expireSession() {
        loggedIn.withLock { $0 = false }
        events.send(.expired)
    }
}
```

`swift_ui_template/Data/Mocks/MockProductRepository.swift`:

```swift
import Foundation
import os

/// Offline `ProductRepository` that paginates over an in-memory array.
nonisolated final class MockProductRepository: ProductRepository {
    private let products: [Product]
    private let failure: DomainError?
    private let delay: Duration
    private let fetchCount = OSAllocatedUnfairLock(initialState: 0)

    /// Number of `fetchProducts` calls so far (handy in tests).
    var fetchProductsCallCount: Int {
        fetchCount.withLock { $0 }
    }

    init(products: [Product] = SampleData.products(count: 45), failure: DomainError? = nil, delay: Duration = .milliseconds(500)) {
        self.products = products
        self.failure = failure
        self.delay = delay
    }

    func fetchProducts(skip: Int, limit: Int) async throws -> Page<Product> {
        fetchCount.withLock { $0 += 1 }
        try await Task.sleep(for: delay)
        if let failure { throw failure }
        let end = min(skip + limit, products.count)
        let items = skip < end ? Array(products[skip..<end]) : []
        return Page(items: items, total: products.count, skip: skip, limit: limit)
    }

    func fetchProduct(id: Int) async throws -> Product {
        try await Task.sleep(for: delay)
        if let failure { throw failure }
        guard let product = products.first(where: { $0.id == id }) else {
            throw DomainError.server(message: "Product not found")
        }
        return product
    }
}
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/SessionEventBroadcasterTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 1 test case của `SessionEventBroadcasterTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/Data/Local/SessionEventBroadcaster.swift \
        swift_ui_template/Data/Mocks/MockAuthRepository.swift \
        swift_ui_template/Data/Mocks/MockProductRepository.swift \
        swift_ui_template/Data/Mocks/SampleData.swift \
        swift_ui_templateTests/Data/SessionEventBroadcasterTests.swift
git commit -m "feat(data): add session event broadcaster and mock repositories" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Domain: use cases

Use case mỏng, gọi bằng `callAsFunction`. `LoginUseCase` kiểm tra input trước khi gọi repository.

**Files:**
- Create: `swift_ui_template/Domain/UseCases/LoginUseCase.swift`
- Create: `swift_ui_template/Domain/UseCases/LogoutUseCase.swift`
- Create: `swift_ui_template/Domain/UseCases/GetCurrentUserUseCase.swift`
- Create: `swift_ui_template/Domain/UseCases/GetProductsUseCase.swift`
- Create: `swift_ui_template/Domain/UseCases/GetProductDetailUseCase.swift`
- Create: `swift_ui_template/Domain/UseCases/CompleteOnboardingUseCase.swift`
- Test: `swift_ui_templateTests/Domain/LoginUseCaseTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Domain/LoginUseCaseTests.swift`:

```swift
import Testing
@testable import swift_ui_template

struct LoginUseCaseTests {
    private let login = LoginUseCase(repository: MockAuthRepository(delay: .zero))

    @Test func rejectsBlankUsername() async {
        await #expect(throws: DomainError.invalidInput(field: .username, reason: .empty)) {
            try await login(username: "   ", password: "emilyspass")
        }
    }

    @Test func rejectsEmptyPassword() async {
        await #expect(throws: DomainError.invalidInput(field: .password, reason: .empty)) {
            try await login(username: "emilys", password: "")
        }
    }

    @Test func rejectsShortPassword() async {
        await #expect(throws: DomainError.invalidInput(field: .password, reason: .tooShort(min: 6))) {
            try await login(username: "emilys", password: "12345")
        }
    }

    @Test func trimsUsernameBeforeLoggingIn() async throws {
        let user = try await login(username: "  emilys ", password: "emilyspass")

        #expect(user == SampleData.user)
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/LoginUseCaseTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: cannot find 'LoginUseCase' in scope`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/Domain/UseCases/LoginUseCase.swift`:

```swift
import Foundation

nonisolated struct LoginUseCase: Sendable {
    static let minPasswordLength = 6

    let repository: any AuthRepository

    func callAsFunction(username: String, password: String) async throws -> User {
        let username = username.trimmed
        guard Validator.isNotBlank(username) else {
            throw DomainError.invalidInput(field: .username, reason: .empty)
        }
        guard Validator.isNotBlank(password) else {
            throw DomainError.invalidInput(field: .password, reason: .empty)
        }
        guard Validator.hasMinLength(password, Self.minPasswordLength) else {
            throw DomainError.invalidInput(field: .password, reason: .tooShort(min: Self.minPasswordLength))
        }
        return try await repository.login(username: username, password: password)
    }
}
```

`swift_ui_template/Domain/UseCases/LogoutUseCase.swift`:

```swift
import Foundation

nonisolated struct LogoutUseCase: Sendable {
    let repository: any AuthRepository

    func callAsFunction() async {
        await repository.logout()
    }
}
```

`swift_ui_template/Domain/UseCases/GetCurrentUserUseCase.swift`:

```swift
import Foundation

nonisolated struct GetCurrentUserUseCase: Sendable {
    let repository: any AuthRepository

    func callAsFunction() async throws -> User {
        try await repository.currentUser()
    }
}
```

`swift_ui_template/Domain/UseCases/GetProductsUseCase.swift`:

```swift
import Foundation

nonisolated struct GetProductsUseCase: Sendable {
    let repository: any ProductRepository

    func callAsFunction(skip: Int, limit: Int) async throws -> Page<Product> {
        try await repository.fetchProducts(skip: skip, limit: limit)
    }
}
```

`swift_ui_template/Domain/UseCases/GetProductDetailUseCase.swift`:

```swift
import Foundation

nonisolated struct GetProductDetailUseCase: Sendable {
    let repository: any ProductRepository

    func callAsFunction(id: Int) async throws -> Product {
        try await repository.fetchProduct(id: id)
    }
}
```

`swift_ui_template/Domain/UseCases/CompleteOnboardingUseCase.swift`:

```swift
import Foundation

nonisolated struct CompleteOnboardingUseCase: Sendable {
    let repository: any OnboardingRepository

    func callAsFunction() {
        repository.markOnboardingSeen()
    }
}
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/LoginUseCaseTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 4 test case của `LoginUseCaseTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/Domain/UseCases/CompleteOnboardingUseCase.swift \
        swift_ui_template/Domain/UseCases/GetCurrentUserUseCase.swift \
        swift_ui_template/Domain/UseCases/GetProductDetailUseCase.swift \
        swift_ui_template/Domain/UseCases/GetProductsUseCase.swift \
        swift_ui_template/Domain/UseCases/LoginUseCase.swift \
        swift_ui_template/Domain/UseCases/LogoutUseCase.swift \
        swift_ui_templateTests/Domain/LoginUseCaseTests.swift
git commit -m "feat(domain): add use cases with login input validation" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Data: DTOs, mappers, error mapping

DTO khớp response DummyJSON (đã kiểm tra bằng request thật), mapper DTO → Domain và hàm `mapToDomainError`.

**Files:**
- Create: `swift_ui_template/Data/DTOs/AuthDTOs.swift`
- Create: `swift_ui_template/Data/DTOs/UserDTO.swift`
- Create: `swift_ui_template/Data/DTOs/ProductDTOs.swift`
- Create: `swift_ui_template/Data/DTOs/ErrorResponseDTO.swift`
- Create: `swift_ui_template/Data/Mappers/AuthMappers.swift`
- Create: `swift_ui_template/Data/Mappers/ProductMappers.swift`
- Create: `swift_ui_template/Data/Mappers/ErrorMapper.swift`
- Test: `swift_ui_templateTests/Helpers/TestFixtures+Products.swift`
- Test: `swift_ui_templateTests/Data/MapperTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Helpers/TestFixtures+Products.swift`:

```swift
import Foundation

nonisolated extension TestFixtures {
    /// A DummyJSON-shaped product page; product ids are 1-based positions.
    static func productListJSON(skip: Int, limit: Int, total: Int) -> Data {
        let end = min(skip + limit, total)
        let products = (skip < end ? Array(skip..<end) : []).map { index in
            """
            {"id":\(index + 1),"title":"Product \(index + 1)","description":"Description","price":9.99,
             "rating":4.5,"thumbnail":"https://cdn.example.com/\(index + 1).webp","images":[],"category":"beauty"}
            """
        }
        return Data(#"{"products":[\#(products.joined(separator: ","))],"total":\#(total),"skip":\#(skip),"limit":\#(limit)}"#.utf8)
    }
}
```

`swift_ui_templateTests/Data/MapperTests.swift`:

```swift
import Foundation
import Testing
@testable import swift_ui_template

struct MapperTests {
    @Test func mapsUser() throws {
        let dto = try JSONDecoder().decode(UserDTO.self, from: TestFixtures.userJSON)

        let user = dto.toDomain()

        #expect(user.id == 1)
        #expect(user.fullName == "Emily Johnson")
        #expect(user.avatarURL == URL(string: "https://dummyjson.com/icon/emilys/128"))
    }

    @Test func mapsAuthResponseToUserAndTokens() throws {
        let dto = try JSONDecoder().decode(AuthResponseDTO.self, from: TestFixtures.authResponseJSON)

        #expect(dto.toDomainUser().username == "emilys")
        #expect(dto.tokens == TestFixtures.tokens)
    }

    @Test func mapsProductPage() throws {
        let json = TestFixtures.productListJSON(skip: 0, limit: 2, total: 5)
        let dto = try JSONDecoder().decode(ProductListDTO.self, from: json)

        let page = dto.toDomain()

        #expect(page.items.map(\.id) == [1, 2])
        #expect(page.items.first?.thumbnailURL == URL(string: "https://cdn.example.com/1.webp"))
        #expect(page.items.first?.brand == nil)
        #expect(page.hasMore)
    }

    @Test(arguments: [
        (APIError.noConnection, DomainError.noConnection),
        (APIError.timeout, DomainError.noConnection),
        (APIError.unauthorized, DomainError.sessionExpired),
        (APIError.decoding("bad"), DomainError.unknown),
        (APIError.http(status: 500, data: Data(#"{"message":"Server down"}"#.utf8)), DomainError.server(message: "Server down")),
        (APIError.http(status: 500, data: Data()), DomainError.server(message: nil)),
    ])
    func mapsAPIErrorToDomainError(apiError: APIError, expected: DomainError) {
        #expect(apiError.toDomainError() == expected)
    }

    @Test func passesCancellationThrough() {
        #expect(mapToDomainError(CancellationError()) is CancellationError)
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/MapperTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: cannot find type 'UserDTO' in scope`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/Data/DTOs/AuthDTOs.swift`:

```swift
import Foundation

nonisolated struct LoginRequestDTO: Encodable, Sendable {
    let username: String
    let password: String
    let expiresInMins: Int
}

nonisolated struct AuthResponseDTO: Decodable, Sendable {
    let id: Int
    let username: String
    let email: String
    let firstName: String
    let lastName: String
    let image: String?
    let accessToken: String
    let refreshToken: String
}

nonisolated struct RefreshRequestDTO: Encodable, Sendable {
    let refreshToken: String
    let expiresInMins: Int
}

nonisolated struct RefreshResponseDTO: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
}
```

`swift_ui_template/Data/DTOs/UserDTO.swift`:

```swift
import Foundation

nonisolated struct UserDTO: Decodable, Sendable {
    let id: Int
    let username: String
    let email: String
    let firstName: String
    let lastName: String
    let image: String?
}
```

`swift_ui_template/Data/DTOs/ProductDTOs.swift`:

```swift
import Foundation

nonisolated struct ProductDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let description: String
    let price: Double
    let rating: Double
    let thumbnail: String?
    let images: [String]?
    let category: String
    let brand: String?
}

nonisolated struct ProductListDTO: Decodable, Sendable {
    let products: [ProductDTO]
    let total: Int
    let skip: Int
    let limit: Int
}
```

`swift_ui_template/Data/DTOs/ErrorResponseDTO.swift`:

```swift
import Foundation

/// Error body returned by the API, e.g. `{"message":"Invalid credentials"}`.
nonisolated struct ErrorResponseDTO: Decodable, Sendable {
    let message: String
}
```

`swift_ui_template/Data/Mappers/AuthMappers.swift`:

```swift
import Foundation

nonisolated extension UserDTO {
    func toDomain() -> User {
        User(
            id: id,
            username: username,
            email: email,
            firstName: firstName,
            lastName: lastName,
            avatarURL: image.flatMap { URL(string: $0) }
        )
    }
}

nonisolated extension AuthResponseDTO {
    var tokens: AuthTokens {
        AuthTokens(accessToken: accessToken, refreshToken: refreshToken)
    }

    func toDomainUser() -> User {
        User(
            id: id,
            username: username,
            email: email,
            firstName: firstName,
            lastName: lastName,
            avatarURL: image.flatMap { URL(string: $0) }
        )
    }
}

nonisolated extension RefreshResponseDTO {
    var tokens: AuthTokens {
        AuthTokens(accessToken: accessToken, refreshToken: refreshToken)
    }
}
```

`swift_ui_template/Data/Mappers/ProductMappers.swift`:

```swift
import Foundation

nonisolated extension ProductDTO {
    func toDomain() -> Product {
        Product(
            id: id,
            title: title,
            description: description,
            price: price,
            rating: rating,
            thumbnailURL: thumbnail.flatMap { URL(string: $0) },
            imageURLs: (images ?? []).compactMap { URL(string: $0) },
            category: category,
            brand: brand
        )
    }
}

nonisolated extension ProductListDTO {
    func toDomain() -> Page<Product> {
        Page(items: products.map { $0.toDomain() }, total: total, skip: skip, limit: limit)
    }
}
```

`swift_ui_template/Data/Mappers/ErrorMapper.swift`:

```swift
import Foundation

nonisolated extension APIError {
    func toDomainError() -> DomainError {
        switch self {
        case .noConnection, .timeout:
            .noConnection
        case .unauthorized:
            .sessionExpired
        case .http(_, let data):
            .server(message: (try? JSONDecoder().decode(ErrorResponseDTO.self, from: data))?.message)
        case .invalidURL, .decoding, .unknown:
            .unknown
        }
    }
}

/// Converts any error thrown below the Domain layer into a `DomainError`.
/// `CancellationError` passes through so callers can ignore cancelled work.
nonisolated func mapToDomainError(_ error: any Error) -> any Error {
    switch error {
    case let apiError as APIError: apiError.toDomainError()
    case is DomainError, is CancellationError: error
    default: DomainError.unknown
    }
}
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/MapperTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 10 test case của `MapperTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/Data/DTOs/AuthDTOs.swift \
        swift_ui_template/Data/DTOs/ErrorResponseDTO.swift \
        swift_ui_template/Data/DTOs/ProductDTOs.swift \
        swift_ui_template/Data/DTOs/UserDTO.swift \
        swift_ui_template/Data/Mappers/AuthMappers.swift \
        swift_ui_template/Data/Mappers/ErrorMapper.swift \
        swift_ui_template/Data/Mappers/ProductMappers.swift \
        swift_ui_templateTests/Data/MapperTests.swift \
        swift_ui_templateTests/Helpers/TestFixtures+Products.swift
git commit -m "feat(data): add DTOs, domain mappers and error mapping" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Data: auth endpoint và RemoteAuthRepository

Login, `/auth/me`, logout, trạng thái đăng nhập và session events. `AuthRefreshAction` tạo closure refresh token cho `TokenRefresher`.

**Files:**
- Create: `swift_ui_template/Data/Remote/AuthEndpoint.swift`
- Create: `swift_ui_template/Data/Remote/AuthRefreshAction.swift`
- Create: `swift_ui_template/Data/Repositories/RemoteAuthRepository.swift`
- Test: `swift_ui_templateTests/Helpers/StubAPIClient.swift`
- Test: `swift_ui_templateTests/Data/RemoteAuthRepositoryTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Helpers/StubAPIClient.swift`:

```swift
import Foundation
import os
@testable import swift_ui_template

/// `APIClient` that returns queued responses and records the endpoints it was called with.
nonisolated final class StubAPIClient: APIClient {
    private nonisolated struct State: Sendable {
        var responses: [Result<Data, APIError>]
        var paths: [String] = []
    }

    private let state: OSAllocatedUnfairLock<State>

    init(responses: [Result<Data, APIError>]) {
        state = OSAllocatedUnfairLock(initialState: State(responses: responses))
    }

    var requestedPaths: [String] {
        state.withLock { $0.paths }
    }

    func send<T: Decodable & Sendable>(_ endpoint: some Endpoint) async throws -> T {
        let result = state.withLock { state in
            state.paths.append(endpoint.path)
            return state.responses.removeFirst()
        }
        return try JSONDecoder().decode(T.self, from: result.get())
    }
}
```

`swift_ui_templateTests/Data/RemoteAuthRepositoryTests.swift`:

```swift
import Foundation
import Testing
@testable import swift_ui_template

struct RemoteAuthRepositoryTests {
    private let tokenStore = TokenStore(keychain: InMemoryKeychainStore())
    private let events = SessionEventBroadcaster()

    private func makeRepository(_ responses: [Result<Data, APIError>]) -> (RemoteAuthRepository, StubAPIClient) {
        let client = StubAPIClient(responses: responses)
        return (RemoteAuthRepository(apiClient: client, tokenProvider: tokenStore, events: events), client)
    }

    @Test func loginStoresTokensAndEmitsLoggedIn() async throws {
        let (repository, client) = makeRepository([.success(TestFixtures.authResponseJSON)])
        var stream = repository.sessionEvents().makeAsyncIterator()

        let user = try await repository.login(username: "emilys", password: "emilyspass")

        #expect(user.username == "emilys")
        #expect(client.requestedPaths == ["/auth/login"])
        #expect(await tokenStore.accessToken() == "access-1")
        #expect(await repository.isLoggedIn())
        #expect(await stream.next() == .loggedIn)
    }

    @Test func loginWithWrongPasswordThrowsInvalidCredentials() async {
        let (repository, _) = makeRepository([.failure(.http(status: 400, data: TestFixtures.invalidCredentialsJSON))])

        await #expect(throws: DomainError.invalidCredentials) {
            try await repository.login(username: "emilys", password: "wrong-password")
        }
        #expect(await repository.isLoggedIn() == false)
    }

    @Test func currentUserMapsUnauthorizedToSessionExpired() async {
        let (repository, _) = makeRepository([.failure(.unauthorized)])

        await #expect(throws: DomainError.sessionExpired) {
            try await repository.currentUser()
        }
    }

    @Test func currentUserCallsMe() async throws {
        let (repository, client) = makeRepository([.success(TestFixtures.userJSON)])

        let user = try await repository.currentUser()

        #expect(user.email == "emily@example.com")
        #expect(client.requestedPaths == ["/auth/me"])
    }

    @Test func logoutClearsTokensAndEmitsLoggedOut() async {
        let (repository, _) = makeRepository([])
        await tokenStore.save(TestFixtures.tokens)
        var stream = repository.sessionEvents().makeAsyncIterator()

        await repository.logout()

        #expect(await repository.isLoggedIn() == false)
        #expect(await stream.next() == .loggedOut)
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/RemoteAuthRepositoryTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: cannot find 'RemoteAuthRepository' in scope`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/Data/Remote/AuthEndpoint.swift`:

```swift
import Foundation

nonisolated enum AuthEndpoint: Endpoint {
    /// Lifetime requested for new access tokens.
    static let tokenLifetimeMinutes = 30

    case login(LoginRequestDTO)
    case refresh(RefreshRequestDTO)
    case me

    var path: String {
        switch self {
        case .login: "/auth/login"
        case .refresh: "/auth/refresh"
        case .me: "/auth/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .login, .refresh: .post
        case .me: .get
        }
    }

    var body: (any Encodable & Sendable)? {
        switch self {
        case .login(let request): request
        case .refresh(let request): request
        case .me: nil
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .refresh: false
        case .me: true
        }
    }
}
```

`swift_ui_template/Data/Remote/AuthRefreshAction.swift`:

```swift
import Foundation

nonisolated enum AuthRefreshAction {
    /// Builds the closure `TokenRefresher` uses to exchange a refresh token for new tokens.
    /// - Parameter client: a client created **without** a refresher, so a failing refresh never recurses.
    static func make(using client: any APIClient) -> TokenRefresher.RefreshAction {
        { refreshToken in
            let request = RefreshRequestDTO(refreshToken: refreshToken, expiresInMins: AuthEndpoint.tokenLifetimeMinutes)
            let response: RefreshResponseDTO = try await client.send(AuthEndpoint.refresh(request))
            return response.tokens
        }
    }
}
```

`swift_ui_template/Data/Repositories/RemoteAuthRepository.swift`:

```swift
import Foundation
import OSLog

nonisolated struct RemoteAuthRepository: AuthRepository {
    let apiClient: any APIClient
    let tokenProvider: any TokenProvider
    let events: SessionEventBroadcaster

    func login(username: String, password: String) async throws -> User {
        let request = LoginRequestDTO(username: username, password: password, expiresInMins: AuthEndpoint.tokenLifetimeMinutes)
        do {
            let response: AuthResponseDTO = try await apiClient.send(AuthEndpoint.login(request))
            await tokenProvider.save(response.tokens)
            AppLogger.auth.info("Logged in")
            events.send(.loggedIn)
            return response.toDomainUser()
        } catch APIError.http(let status, _) where status == 400 || status == 401 {
            throw DomainError.invalidCredentials
        } catch {
            throw mapToDomainError(error)
        }
    }

    func currentUser() async throws -> User {
        do {
            let user: UserDTO = try await apiClient.send(AuthEndpoint.me)
            return user.toDomain()
        } catch {
            throw mapToDomainError(error)
        }
    }

    func logout() async {
        await tokenProvider.clear()
        AppLogger.auth.info("Logged out")
        events.send(.loggedOut)
    }

    func isLoggedIn() async -> Bool {
        await tokenProvider.accessToken() != nil
    }

    func sessionEvents() -> AsyncStream<SessionEvent> {
        events.stream()
    }
}
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/RemoteAuthRepositoryTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 5 test case của `RemoteAuthRepositoryTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/Data/Remote/AuthEndpoint.swift \
        swift_ui_template/Data/Remote/AuthRefreshAction.swift \
        swift_ui_template/Data/Repositories/RemoteAuthRepository.swift \
        swift_ui_templateTests/Data/RemoteAuthRepositoryTests.swift \
        swift_ui_templateTests/Helpers/StubAPIClient.swift
git commit -m "feat(data): add auth endpoints and RemoteAuthRepository" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: Data: product repository và onboarding repository

Danh sách và chi tiết sản phẩm qua `/auth/products` (cần token, nên Home cũng đi qua luồng refresh). Cờ đã xem onboarding lưu bằng `KeyValueStore`.

**Files:**
- Create: `swift_ui_template/Data/Remote/ProductEndpoint.swift`
- Create: `swift_ui_template/Data/Repositories/RemoteProductRepository.swift`
- Create: `swift_ui_template/Data/Local/LocalOnboardingRepository.swift`
- Test: `swift_ui_templateTests/Data/RemoteProductRepositoryTests.swift`
- Test: `swift_ui_templateTests/Data/LocalOnboardingRepositoryTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Data/RemoteProductRepositoryTests.swift`:

```swift
import Foundation
import os
import Testing
@testable import swift_ui_template

struct RemoteProductRepositoryTests {
    @Test func fetchesAuthenticatedProductPage() async throws {
        let host = TestFixtures.uniqueHost()
        let captured = OSAllocatedUnfairLock<URLRequest?>(initialState: nil)
        let store = TokenStore(keychain: InMemoryKeychainStore())
        await store.save(TestFixtures.tokens)
        let client = URLSessionAPIClient(
            baseURL: URL(string: "https://\(host)")!,
            session: URLProtocolStub.makeSession(host: host) { request in
                captured.withLock { $0 = request }
                return (200, TestFixtures.productListJSON(skip: 20, limit: 20, total: 45))
            },
            tokenProvider: store
        )
        let repository = RemoteProductRepository(apiClient: client)

        let page = try await repository.fetchProducts(skip: 20, limit: 20)

        let request = try #require(captured.withLock { $0 })
        let components = try #require(request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
        #expect(components.path == "/auth/products")
        #expect(components.queryItems?.contains(URLQueryItem(name: "limit", value: "20")) == true)
        #expect(components.queryItems?.contains(URLQueryItem(name: "skip", value: "20")) == true)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access-1")
        #expect(page.items.count == 20)
        #expect(page.hasMore)
    }

    @Test func refreshesExpiredTokenThenReturnsProducts() async throws {
        let host = TestFixtures.uniqueHost()
        let store = TokenStore(keychain: InMemoryKeychainStore())
        await store.save(TestFixtures.tokens)
        let refresher = TokenRefresher(tokenProvider: store, refreshAction: { _ in TestFixtures.refreshedTokens }, onSessionExpired: {})
        let client = URLSessionAPIClient(
            baseURL: URL(string: "https://\(host)")!,
            session: URLProtocolStub.makeSession(host: host) { request in
                request.value(forHTTPHeaderField: "Authorization") == "Bearer access-2"
                    ? (200, TestFixtures.productListJSON(skip: 0, limit: 20, total: 45))
                    : (401, Data(#"{"message":"Invalid/Expired Token!"}"#.utf8))
            },
            tokenProvider: store,
            refresher: refresher
        )
        let repository = RemoteProductRepository(apiClient: client)

        let page = try await repository.fetchProducts(skip: 0, limit: 20)

        #expect(page.items.count == 20)
    }

    @Test func fetchProductCallsDetailPath() async throws {
        let client = StubAPIClient(responses: [.success(Data("""
        {"id":3,"title":"Lipstick","description":"Red","price":12.5,"rating":4.1,"category":"beauty","brand":"Brand"}
        """.utf8))])
        let repository = RemoteProductRepository(apiClient: client)

        let product = try await repository.fetchProduct(id: 3)

        #expect(product.title == "Lipstick")
        #expect(product.imageURLs.isEmpty)
        #expect(client.requestedPaths == ["/auth/products/3"])
    }

    @Test func mapsOfflineToDomainError() async {
        let repository = RemoteProductRepository(apiClient: StubAPIClient(responses: [.failure(.noConnection)]))

        await #expect(throws: DomainError.noConnection) {
            try await repository.fetchProducts(skip: 0, limit: 20)
        }
    }
}
```

`swift_ui_templateTests/Data/LocalOnboardingRepositoryTests.swift`:

```swift
import Testing
@testable import swift_ui_template

struct LocalOnboardingRepositoryTests {
    @Test func remembersOnboardingWasSeen() {
        let repository = LocalOnboardingRepository(store: UserDefaultsStore(defaults: TestFixtures.makeDefaults()))
        #expect(repository.hasSeenOnboarding() == false)

        repository.markOnboardingSeen()

        #expect(repository.hasSeenOnboarding())
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/RemoteProductRepositoryTests -only-testing:swift_ui_templateTests/LocalOnboardingRepositoryTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: cannot find 'RemoteProductRepository' in scope`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/Data/Remote/ProductEndpoint.swift`:

```swift
import Foundation

nonisolated enum ProductEndpoint: Endpoint {
    case list(skip: Int, limit: Int)
    case detail(id: Int)

    // DummyJSON serves the same data under /auth/... when a valid Bearer token is sent.
    var path: String {
        switch self {
        case .list: "/auth/products"
        case .detail(let id): "/auth/products/\(id)"
        }
    }

    var method: HTTPMethod { .get }

    var query: [URLQueryItem] {
        switch self {
        case .list(let skip, let limit):
            [URLQueryItem(name: "limit", value: String(limit)), URLQueryItem(name: "skip", value: String(skip))]
        case .detail:
            []
        }
    }
}
```

`swift_ui_template/Data/Repositories/RemoteProductRepository.swift`:

```swift
import Foundation

nonisolated struct RemoteProductRepository: ProductRepository {
    let apiClient: any APIClient

    func fetchProducts(skip: Int, limit: Int) async throws -> Page<Product> {
        do {
            let response: ProductListDTO = try await apiClient.send(ProductEndpoint.list(skip: skip, limit: limit))
            return response.toDomain()
        } catch {
            throw mapToDomainError(error)
        }
    }

    func fetchProduct(id: Int) async throws -> Product {
        do {
            let response: ProductDTO = try await apiClient.send(ProductEndpoint.detail(id: id))
            return response.toDomain()
        } catch {
            throw mapToDomainError(error)
        }
    }
}
```

`swift_ui_template/Data/Local/LocalOnboardingRepository.swift`:

```swift
import Foundation

nonisolated struct LocalOnboardingRepository: OnboardingRepository {
    let store: any KeyValueStore

    func hasSeenOnboarding() -> Bool {
        store.value(for: .hasSeenOnboarding)
    }

    func markOnboardingSeen() {
        store.set(true, for: .hasSeenOnboarding)
    }
}
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/RemoteProductRepositoryTests -only-testing:swift_ui_templateTests/LocalOnboardingRepositoryTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 4 test case của `RemoteProductRepositoryTests` `passed` và 1 test case của `LocalOnboardingRepositoryTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/Data/Local/LocalOnboardingRepository.swift \
        swift_ui_template/Data/Remote/ProductEndpoint.swift \
        swift_ui_template/Data/Repositories/RemoteProductRepository.swift \
        swift_ui_templateTests/Data/LocalOnboardingRepositoryTests.swift \
        swift_ui_templateTests/Data/RemoteProductRepositoryTests.swift
git commit -m "feat(data): add product and onboarding repositories" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 16: Presentation/Common: ViewState, Theme, thông báo lỗi, components

Phần UI dùng chung cho mọi màn hình.

**Files:**
- Create: `swift_ui_template/Presentation/Common/ViewState.swift`
- Create: `swift_ui_template/Presentation/Common/Theme.swift`
- Create: `swift_ui_template/Presentation/Common/DomainError+Message.swift`
- Create: `swift_ui_template/Presentation/Common/Components/PrimaryButton.swift`
- Create: `swift_ui_template/Presentation/Common/Components/AppTextField.swift`
- Create: `swift_ui_template/Presentation/Common/Components/StateViews.swift`
- Test: `swift_ui_templateTests/Presentation/DomainErrorMessageTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Presentation/DomainErrorMessageTests.swift`:

```swift
import Testing
@testable import swift_ui_template

struct DomainErrorMessageTests {
    @Test func serverMessageIsShownAsIs() {
        #expect(DomainError.server(message: "Maintenance").message == "Maintenance")
    }

    @Test func nonDomainErrorsUseGenericMessage() {
        struct SomeError: Error {}

        #expect(SomeError().userMessage == DomainError.unknown.message)
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/DomainErrorMessageTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: value of type 'DomainError' has no member 'message'`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/Presentation/Common/ViewState.swift`:

```swift
import Foundation

/// Loading state of one screen or section.
enum ViewState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}

extension ViewState: Equatable where Value: Equatable {}
```

`swift_ui_template/Presentation/Common/Theme.swift`:

```swift
import SwiftUI

/// Design tokens. Colors come from the asset catalog and system styles.
enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let s: CGFloat = 8
        static let m: CGFloat = 12
    }
}
```

`swift_ui_template/Presentation/Common/DomainError+Message.swift`:

```swift
import Foundation

extension DomainError {
    /// Localized text shown to the user.
    var message: String {
        switch self {
        case .invalidInput(_, .empty):
            String(localized: "This field is required.")
        case .invalidInput(_, .tooShort(let min)):
            String(localized: "Must be at least \(min) characters.")
        case .invalidCredentials:
            String(localized: "Incorrect username or password.")
        case .sessionExpired:
            String(localized: "Your session has expired. Please log in again.")
        case .noConnection:
            String(localized: "No internet connection. Please try again.")
        case .server(let message?):
            message
        case .server(nil), .unknown:
            String(localized: "Something went wrong. Please try again.")
        }
    }
}

extension Error {
    /// Message for any error reaching the UI; non-domain errors get the generic text.
    var userMessage: String {
        (self as? DomainError ?? .unknown).message
    }
}
```

`swift_ui_template/Presentation/Common/Components/PrimaryButton.swift`:

```swift
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
```

`swift_ui_template/Presentation/Common/Components/AppTextField.swift`:

```swift
import SwiftUI
import UIKit

struct AppTextField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    var isSecure = false
    var error: String?

    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Group {
                    if isSecure && !isRevealed {
                        SecureField(title, text: $text)
                    } else {
                        TextField(title, text: $text)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                if isSecure {
                    Button {
                        isRevealed.toggle()
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                    }
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(isRevealed ? Text("Hide password") : Text("Show password"))
                }
            }
            .padding(Theme.Spacing.m)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Theme.Radius.m))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.m)
                    .stroke(error == nil ? Color.clear : Color.red, lineWidth: 1)
            }

            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.m) {
        AppTextField(title: "Username", text: .constant("emilys"))
        AppTextField(title: "Password", text: .constant(""), isSecure: true, error: "This field is required.")
    }
    .padding()
}
```

`swift_ui_template/Presentation/Common/Components/StateViews.swift`:

```swift
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
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/DomainErrorMessageTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 2 test case của `DomainErrorMessageTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/Presentation/Common/Components/AppTextField.swift \
        swift_ui_template/Presentation/Common/Components/PrimaryButton.swift \
        swift_ui_template/Presentation/Common/Components/StateViews.swift \
        swift_ui_template/Presentation/Common/DomainError+Message.swift \
        swift_ui_template/Presentation/Common/Theme.swift \
        swift_ui_template/Presentation/Common/ViewState.swift \
        swift_ui_templateTests/Presentation/DomainErrorMessageTests.swift
git commit -m "feat(ui): add shared view state, theme, error messages and components" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 17: App: AppRouter

Chọn luồng màn hình cấp cao nhất (`launching` → `onboarding` / `login` / `main`) và theo dõi session events.

**Files:**
- Create: `swift_ui_template/App/AppRouter.swift`
- Test: `swift_ui_templateTests/Helpers/Waiting.swift`
- Test: `swift_ui_templateTests/App/AppRouterTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Helpers/Waiting.swift`:

```swift
import Foundation

/// Polls `condition` until it is true or `timeout` passes. Use for state changed by another task.
func waitUntil(timeout: Duration = .seconds(1), _ condition: () -> Bool) async {
    let deadline = ContinuousClock.now + timeout
    while !condition(), ContinuousClock.now < deadline {
        try? await Task.sleep(for: .milliseconds(5))
    }
}
```

`swift_ui_templateTests/App/AppRouterTests.swift`:

```swift
import Testing
@testable import swift_ui_template

struct AppRouterTests {
    private func makeRouter(seenOnboarding: Bool, auth: MockAuthRepository) -> AppRouter {
        let onboarding = LocalOnboardingRepository(store: UserDefaultsStore(defaults: TestFixtures.makeDefaults()))
        if seenOnboarding { onboarding.markOnboardingSeen() }
        return AppRouter(authRepository: auth, onboardingRepository: onboarding)
    }

    @Test func startsInLaunching() {
        let router = makeRouter(seenOnboarding: false, auth: MockAuthRepository(delay: .zero))

        #expect(router.route == .launching)
    }

    @Test func showsOnboardingFirst() async {
        let router = makeRouter(seenOnboarding: false, auth: MockAuthRepository(isLoggedIn: true, delay: .zero))

        await router.start()

        #expect(router.route == .onboarding)
    }

    @Test func showsMainWhenLoggedIn() async {
        let router = makeRouter(seenOnboarding: true, auth: MockAuthRepository(isLoggedIn: true, delay: .zero))

        await router.start()

        #expect(router.route == .main)
    }

    @Test func showsLoginWhenLoggedOut() async {
        let router = makeRouter(seenOnboarding: true, auth: MockAuthRepository(delay: .zero))

        await router.start()

        #expect(router.route == .login)
    }

    @Test func onboardingFinishedShowsLogin() {
        let router = makeRouter(seenOnboarding: false, auth: MockAuthRepository(delay: .zero))

        router.onboardingFinished()

        #expect(router.route == .login)
    }

    @Test func followsSessionEvents() async throws {
        let auth = MockAuthRepository(delay: .zero)
        let router = makeRouter(seenOnboarding: true, auth: auth)
        await router.start()
        let observation = Task { await router.observeSession() }
        defer { observation.cancel() }

        _ = try await auth.login(username: MockAuthRepository.validUsername, password: MockAuthRepository.validPassword)
        await waitUntil { router.route == .main }
        #expect(router.route == .main)

        auth.expireSession()
        await waitUntil { router.route == .login }
        #expect(router.route == .login)
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/AppRouterTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: cannot find 'AppRouter' in scope`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/App/AppRouter.swift`:

```swift
import Foundation
import Observation

enum AppRoute: Equatable {
    /// Shown for a moment while `start()` reads the stored session.
    case launching
    case onboarding
    case login
    case main
}

/// Decides which top-level flow is on screen.
@Observable
final class AppRouter {
    private(set) var route: AppRoute = .launching

    private let authRepository: any AuthRepository
    private let onboardingRepository: any OnboardingRepository
    // Subscribed in init so no event is missed before `observeSession()` starts iterating.
    private let sessionEvents: AsyncStream<SessionEvent>

    init(authRepository: any AuthRepository, onboardingRepository: any OnboardingRepository) {
        self.authRepository = authRepository
        self.onboardingRepository = onboardingRepository
        sessionEvents = authRepository.sessionEvents()
    }

    func start() async {
        if !onboardingRepository.hasSeenOnboarding() {
            route = .onboarding
        } else if await authRepository.isLoggedIn() {
            route = .main
        } else {
            route = .login
        }
    }

    /// Runs until the calling task is cancelled.
    func observeSession() async {
        for await event in sessionEvents {
            switch event {
            case .loggedIn: route = .main
            case .loggedOut, .expired: route = .login
            }
        }
    }

    func onboardingFinished() {
        route = .login
    }
}
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/AppRouterTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 6 test case của `AppRouterTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/App/AppRouter.swift \
        swift_ui_templateTests/App/AppRouterTests.swift \
        swift_ui_templateTests/Helpers/Waiting.swift
git commit -m "feat(app): add AppRouter driven by session events" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 18: App: AppContainer (composition root)

Nối Data với Presentation: `live()` dùng network thật hoặc mock (`-UseMockData`), `preview()` cho SwiftUI preview. Factory cho ViewModel được thêm dần ở các task sau.

**Files:**
- Create: `swift_ui_template/App/AppContainer.swift`

Không có unit test riêng: `AppContainer` chỉ nối dây; các thành phần nó tạo đã được test ở Task 3–17, và luồng đầy đủ được kiểm tra thủ công ở Task 23.

- [ ] **Step 1: Viết `AppContainer`**

`swift_ui_template/App/AppContainer.swift`:

```swift
import Foundation
import Observation

/// Composition root: the only place that knows concrete Data types.
/// Views read it with `@Environment(AppContainer.self)` and call the `make…` factories.
@Observable
final class AppContainer {
    let environment: AppEnvironment
    let authRepository: any AuthRepository
    let productRepository: any ProductRepository
    let onboardingRepository: any OnboardingRepository

    init(
        environment: AppEnvironment,
        authRepository: any AuthRepository,
        productRepository: any ProductRepository,
        onboardingRepository: any OnboardingRepository
    ) {
        self.environment = environment
        self.authRepository = authRepository
        self.productRepository = productRepository
        self.onboardingRepository = onboardingRepository
    }

    static func live(environment: AppEnvironment = .current) -> AppContainer {
        let onboardingRepository = LocalOnboardingRepository(store: UserDefaultsStore())

        if environment.useMockData {
            return AppContainer(
                environment: environment,
                authRepository: MockAuthRepository(),
                productRepository: MockProductRepository(),
                onboardingRepository: onboardingRepository
            )
        }

        let session = URLSession(configuration: .default)
        let tokenStore = TokenStore(keychain: SystemKeychainStore(service: Bundle.main.bundleIdentifier ?? "app"))
        let events = SessionEventBroadcaster()
        let refreshClient = URLSessionAPIClient(baseURL: environment.baseURL, session: session, tokenProvider: tokenStore)
        let refresher = TokenRefresher(
            tokenProvider: tokenStore,
            refreshAction: AuthRefreshAction.make(using: refreshClient),
            onSessionExpired: { events.send(.expired) }
        )
        let apiClient = URLSessionAPIClient(
            baseURL: environment.baseURL,
            session: session,
            tokenProvider: tokenStore,
            refresher: refresher
        )

        return AppContainer(
            environment: environment,
            authRepository: RemoteAuthRepository(apiClient: apiClient, tokenProvider: tokenStore, events: events),
            productRepository: RemoteProductRepository(apiClient: apiClient),
            onboardingRepository: onboardingRepository
        )
    }

    /// Offline container for SwiftUI previews.
    static func preview(isLoggedIn: Bool = true) -> AppContainer {
        AppContainer(
            environment: AppEnvironment(name: "preview", baseURL: URL(string: "https://example.com")!, useMockData: true),
            authRepository: MockAuthRepository(isLoggedIn: isLoggedIn, delay: .milliseconds(300)),
            productRepository: MockProductRepository(delay: .milliseconds(300)),
            onboardingRepository: LocalOnboardingRepository(store: UserDefaultsStore(defaults: UserDefaults(suiteName: "preview")!))
        )
    }

    // MARK: - Factories

    func makeAppRouter() -> AppRouter {
        AppRouter(authRepository: authRepository, onboardingRepository: onboardingRepository)
    }
}
```

- [ ] **Step 2: Build**

```sh
xcodebuild build -scheme Dev -destination "$DEST" -quiet && echo BUILD_OK
```

Expected: `BUILD_OK`, không có `error:` hay `warning:`.

- [ ] **Step 3: Commit**

```sh
git add swift_ui_template/App/AppContainer.swift
git commit -m "feat(app): add AppContainer composition root" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 19: Feature: Onboarding

3 trang giới thiệu, nút Skip / Next / Get Started; xong thì đánh dấu đã xem và chuyển sang Login.

**Files:**
- Create: `swift_ui_template/Presentation/Onboarding/OnboardingPage.swift`
- Create: `swift_ui_template/Presentation/Onboarding/OnboardingViewModel.swift`
- Create: `swift_ui_template/Presentation/Onboarding/OnboardingView.swift`
- Modify: `swift_ui_template/App/AppContainer.swift` (thêm factory)
- Test: `swift_ui_templateTests/Presentation/OnboardingViewModelTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Presentation/OnboardingViewModelTests.swift`:

```swift
import Testing
@testable import swift_ui_template

struct OnboardingViewModelTests {
    private let repository = LocalOnboardingRepository(store: UserDefaultsStore(defaults: TestFixtures.makeDefaults()))

    @Test func nextAdvancesPage() {
        let viewModel = OnboardingViewModel(completeOnboarding: CompleteOnboardingUseCase(repository: repository), onFinish: {})

        viewModel.next()

        #expect(viewModel.currentIndex == 1)
        #expect(repository.hasSeenOnboarding() == false)
    }

    @Test func nextOnLastPageFinishes() {
        var finished = false
        let viewModel = OnboardingViewModel(completeOnboarding: CompleteOnboardingUseCase(repository: repository), onFinish: { finished = true })
        viewModel.currentIndex = viewModel.pages.count - 1

        viewModel.next()

        #expect(finished)
        #expect(repository.hasSeenOnboarding())
    }

    @Test func skipFinishesImmediately() {
        var finished = false
        let viewModel = OnboardingViewModel(completeOnboarding: CompleteOnboardingUseCase(repository: repository), onFinish: { finished = true })

        viewModel.finish()

        #expect(finished)
        #expect(repository.hasSeenOnboarding())
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/OnboardingViewModelTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: cannot find 'OnboardingViewModel' in scope`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/Presentation/Onboarding/OnboardingPage.swift`:

```swift
import Foundation

struct OnboardingPage: Identifiable {
    let id: Int
    let systemImage: String
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource

    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            systemImage: "sparkles",
            title: "Welcome",
            subtitle: "A clean SwiftUI starting point for your next app."
        ),
        OnboardingPage(
            id: 1,
            systemImage: "network",
            title: "Ready to connect",
            subtitle: "Networking, secure storage and session handling are built in."
        ),
        OnboardingPage(
            id: 2,
            systemImage: "checkmark.seal",
            title: "Built to grow",
            subtitle: "Clear layers make new features easy to add and test."
        ),
    ]
}
```

`swift_ui_template/Presentation/Onboarding/OnboardingViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
final class OnboardingViewModel {
    let pages = OnboardingPage.all
    var currentIndex = 0

    var isLastPage: Bool {
        currentIndex == pages.count - 1
    }

    private let completeOnboarding: CompleteOnboardingUseCase
    private let onFinish: () -> Void

    init(completeOnboarding: CompleteOnboardingUseCase, onFinish: @escaping () -> Void) {
        self.completeOnboarding = completeOnboarding
        self.onFinish = onFinish
    }

    func next() {
        if isLastPage {
            finish()
        } else {
            currentIndex += 1
        }
    }

    func finish() {
        completeOnboarding()
        onFinish()
    }
}
```

`swift_ui_template/Presentation/Onboarding/OnboardingView.swift`:

```swift
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
```

Thêm factory sau vào **cuối** class `AppContainer` trong `swift_ui_template/App/AppContainer.swift` (ngay trước dấu `}` cuối file):

```swift
    func makeOnboardingViewModel(onFinish: @escaping () -> Void) -> OnboardingViewModel {
        OnboardingViewModel(completeOnboarding: CompleteOnboardingUseCase(repository: onboardingRepository), onFinish: onFinish)
    }
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/OnboardingViewModelTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 3 test case của `OnboardingViewModelTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/App/AppContainer.swift \
        swift_ui_template/Presentation/Onboarding/OnboardingPage.swift \
        swift_ui_template/Presentation/Onboarding/OnboardingView.swift \
        swift_ui_template/Presentation/Onboarding/OnboardingViewModel.swift \
        swift_ui_templateTests/Presentation/OnboardingViewModelTests.swift
git commit -m "feat(onboarding): add onboarding flow" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 20: Feature: Login

Form username/password, lỗi validate hiện ngay dưới ô nhập, lỗi server hiện bằng alert. Đăng nhập thành công thì router tự chuyển sang Dashboard nhờ event `.loggedIn`.

**Files:**
- Create: `swift_ui_template/Presentation/Auth/Login/LoginViewModel.swift`
- Create: `swift_ui_template/Presentation/Auth/Login/LoginView.swift`
- Modify: `swift_ui_template/App/AppContainer.swift` (thêm factory)
- Test: `swift_ui_templateTests/Presentation/LoginViewModelTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Presentation/LoginViewModelTests.swift`:

```swift
import Testing
@testable import swift_ui_template

struct LoginViewModelTests {
    private func makeViewModel(
        repository: MockAuthRepository = MockAuthRepository(delay: .zero),
        username: String = "emilys",
        password: String = "emilyspass"
    ) -> LoginViewModel {
        LoginViewModel(login: LoginUseCase(repository: repository), username: username, password: password)
    }

    @Test func blankUsernameShowsInlineError() async {
        let viewModel = makeViewModel(username: "")

        await viewModel.submit()

        #expect(viewModel.usernameError == DomainError.invalidInput(field: .username, reason: .empty).message)
        #expect(viewModel.passwordError == nil)
        #expect(viewModel.alertMessage == nil)
    }

    @Test func shortPasswordShowsInlineError() async {
        let viewModel = makeViewModel(password: "123")

        await viewModel.submit()

        #expect(viewModel.passwordError == DomainError.invalidInput(field: .password, reason: .tooShort(min: 6)).message)
    }

    @Test func wrongPasswordShowsAlert() async {
        let viewModel = makeViewModel(password: "wrong-password")

        await viewModel.submit()

        #expect(viewModel.alertMessage == DomainError.invalidCredentials.message)
        #expect(viewModel.isShowingAlert)
        #expect(viewModel.isLoading == false)
    }

    @Test func successLogsIn() async {
        let repository = MockAuthRepository(delay: .zero)
        let viewModel = makeViewModel(repository: repository)

        await viewModel.submit()

        #expect(await repository.isLoggedIn())
        #expect(viewModel.alertMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test func dismissingAlertClearsMessage() async {
        let viewModel = makeViewModel(repository: MockAuthRepository(failure: .noConnection, delay: .zero))
        await viewModel.submit()

        viewModel.isShowingAlert = false

        #expect(viewModel.alertMessage == nil)
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/LoginViewModelTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: cannot find 'LoginViewModel' in scope`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/Presentation/Auth/Login/LoginViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
final class LoginViewModel {
    var username: String
    var password: String
    private(set) var usernameError: String?
    private(set) var passwordError: String?
    private(set) var isLoading = false
    var alertMessage: String?

    var isShowingAlert: Bool {
        get { alertMessage != nil }
        set { if !newValue { alertMessage = nil } }
    }

    private let login: LoginUseCase

    init(login: LoginUseCase, username: String = "", password: String = "") {
        self.login = login
        self.username = username
        self.password = password
    }

    /// On success the session emits `.loggedIn` and `AppRouter` switches to the dashboard.
    func submit() async {
        guard !isLoading else { return }
        usernameError = nil
        passwordError = nil
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await login(username: username, password: password)
        } catch DomainError.invalidInput(.username, let reason) {
            usernameError = DomainError.invalidInput(field: .username, reason: reason).message
        } catch DomainError.invalidInput(.password, let reason) {
            passwordError = DomainError.invalidInput(field: .password, reason: reason).message
        } catch is CancellationError {
            // The view went away; nothing to show.
        } catch {
            alertMessage = error.userMessage
        }
    }
}
```

`swift_ui_template/Presentation/Auth/Login/LoginView.swift`:

```swift
import SwiftUI

struct LoginView: View {
    @State var viewModel: LoginViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                VStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.tint)
                    Text("Welcome back")
                        .font(.largeTitle.bold())
                    Text("Sign in to continue")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, Theme.Spacing.xl)

                AppTextField(title: "Username", text: $viewModel.username, error: viewModel.usernameError)
                    .textContentType(.username)
                AppTextField(title: "Password", text: $viewModel.password, isSecure: true, error: viewModel.passwordError)
                    .textContentType(.password)

                PrimaryButton(title: "Log In", isLoading: viewModel.isLoading) {
                    Task { await viewModel.submit() }
                }
            }
            .padding(Theme.Spacing.m)
            .disabled(viewModel.isLoading)
        }
        .scrollDismissesKeyboard(.interactively)
        .alert("Login failed", isPresented: $viewModel.isShowingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }
}

#Preview {
    LoginView(viewModel: AppContainer.preview(isLoggedIn: false).makeLoginViewModel())
}
```

Thêm factory sau vào **cuối** class `AppContainer` trong `swift_ui_template/App/AppContainer.swift` (ngay trước dấu `}` cuối file):

```swift
    func makeLoginViewModel() -> LoginViewModel {
        let login = LoginUseCase(repository: authRepository)
        #if DEBUG
        // DummyJSON test account, pre-filled to speed up development.
        return LoginViewModel(login: login, username: "emilys", password: "emilyspass")
        #else
        return LoginViewModel(login: login)
        #endif
    }
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/LoginViewModelTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 5 test case của `LoginViewModelTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/App/AppContainer.swift \
        swift_ui_template/Presentation/Auth/Login/LoginView.swift \
        swift_ui_template/Presentation/Auth/Login/LoginViewModel.swift \
        swift_ui_templateTests/Presentation/LoginViewModelTests.swift
git commit -m "feat(auth): add login screen" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 21: Feature: Home và Product detail

Danh sách sản phẩm phân trang (load thêm khi tới dòng cuối), kéo để refresh, trạng thái loading/error/empty; bấm vào để xem chi tiết.

**Files:**
- Create: `swift_ui_template/Presentation/Dashboard/Home/HomeViewModel.swift`
- Create: `swift_ui_template/Presentation/Dashboard/Home/ProductRow.swift`
- Create: `swift_ui_template/Presentation/Dashboard/ProductDetail/ProductDetailViewModel.swift`
- Create: `swift_ui_template/Presentation/Dashboard/ProductDetail/ProductDetailView.swift`
- Create: `swift_ui_template/Presentation/Dashboard/Home/HomeView.swift`
- Modify: `swift_ui_template/App/AppContainer.swift` (thêm factory)
- Test: `swift_ui_templateTests/Presentation/HomeViewModelTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Presentation/HomeViewModelTests.swift`:

```swift
import Testing
@testable import swift_ui_template

struct HomeViewModelTests {
    private func makeViewModel(_ repository: MockProductRepository) -> HomeViewModel {
        HomeViewModel(getProducts: GetProductsUseCase(repository: repository))
    }

    private func items(_ viewModel: HomeViewModel) -> [Product] {
        if case .loaded(let products) = viewModel.state { products } else { [] }
    }

    @Test func loadShowsFirstPage() async {
        let viewModel = makeViewModel(MockProductRepository(delay: .zero))

        await viewModel.load()

        #expect(items(viewModel).count == HomeViewModel.pageSize)
    }

    @Test func loadMoreAppendsUntilLastPage() async throws {
        let repository = MockProductRepository(products: SampleData.products(count: 45), delay: .zero)
        let viewModel = makeViewModel(repository)
        await viewModel.load()

        await viewModel.loadMoreIfNeeded(current: try #require(items(viewModel).last))
        #expect(items(viewModel).count == 40)

        await viewModel.loadMoreIfNeeded(current: try #require(items(viewModel).last))
        #expect(items(viewModel).count == 45)

        await viewModel.loadMoreIfNeeded(current: try #require(items(viewModel).last))
        #expect(items(viewModel).count == 45)
        #expect(repository.fetchProductsCallCount == 3)
    }

    @Test func loadMoreIgnoresRowsOtherThanLast() async throws {
        let repository = MockProductRepository(delay: .zero)
        let viewModel = makeViewModel(repository)
        await viewModel.load()

        await viewModel.loadMoreIfNeeded(current: try #require(items(viewModel).first))

        #expect(repository.fetchProductsCallCount == 1)
    }

    @Test func refreshResetsToFirstPage() async throws {
        let viewModel = makeViewModel(MockProductRepository(delay: .zero))
        await viewModel.load()
        await viewModel.loadMoreIfNeeded(current: try #require(items(viewModel).last))

        await viewModel.refresh()

        #expect(items(viewModel).count == HomeViewModel.pageSize)
    }

    @Test func failureShowsErrorMessage() async {
        let viewModel = makeViewModel(MockProductRepository(failure: .noConnection, delay: .zero))

        await viewModel.load()

        #expect(viewModel.state == .failed(DomainError.noConnection.message))
    }

    @Test func emptyListIsLoadedEmpty() async {
        let viewModel = makeViewModel(MockProductRepository(products: [], delay: .zero))

        await viewModel.load()

        #expect(viewModel.state == .loaded([]))
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/HomeViewModelTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: cannot find 'HomeViewModel' in scope`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/Presentation/Dashboard/Home/HomeViewModel.swift`:

```swift
import Foundation
import Observation
import OSLog

@Observable
final class HomeViewModel {
    static let pageSize = 20

    private(set) var state: ViewState<[Product]> = .idle
    private(set) var isLoadingMore = false

    private var lastPage: Page<Product>?
    private let getProducts: GetProductsUseCase

    init(getProducts: GetProductsUseCase) {
        self.getProducts = getProducts
    }

    /// First load only; does nothing once data has been requested.
    func load() async {
        guard case .idle = state else { return }
        state = .loading
        await loadFirstPage()
    }

    func refresh() async {
        await loadFirstPage()
    }

    func retry() async {
        state = .loading
        await loadFirstPage()
    }

    /// Call when `product` appears on screen; fetches the next page when it is the last row.
    func loadMoreIfNeeded(current product: Product) async {
        guard
            case .loaded(let products) = state,
            product.id == products.last?.id,
            lastPage?.hasMore == true,
            !isLoadingMore
        else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await getProducts(skip: products.count, limit: Self.pageSize)
            lastPage = page
            state = .loaded(products + page.items)
        } catch {
            // Keep the rows already shown; the next scroll to the bottom retries.
            AppLogger.network.error("Loading more products failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func loadFirstPage() async {
        do {
            let page = try await getProducts(skip: 0, limit: Self.pageSize)
            lastPage = page
            state = .loaded(page.items)
        } catch is CancellationError {
            // Pull-to-refresh was cancelled; keep the current state.
        } catch {
            state = .failed(error.userMessage)
        }
    }
}
```

`swift_ui_template/Presentation/Dashboard/Home/ProductRow.swift`:

```swift
import SwiftUI

struct ProductRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            AsyncImage(url: product.thumbnailURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.15)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s))

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(product.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(product.price, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

#Preview {
    List(SampleData.products(count: 3)) { ProductRow(product: $0) }
}
```

`swift_ui_template/Presentation/Dashboard/ProductDetail/ProductDetailViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
final class ProductDetailViewModel {
    private(set) var state: ViewState<Product> = .idle

    private let productID: Product.ID
    private let getProductDetail: GetProductDetailUseCase

    init(productID: Product.ID, getProductDetail: GetProductDetailUseCase) {
        self.productID = productID
        self.getProductDetail = getProductDetail
    }

    func load() async {
        state = .loading
        do {
            state = .loaded(try await getProductDetail(id: productID))
        } catch is CancellationError {
            // The screen was closed.
        } catch {
            state = .failed(error.userMessage)
        }
    }
}
```

`swift_ui_template/Presentation/Dashboard/ProductDetail/ProductDetailView.swift`:

```swift
import SwiftUI

struct ProductDetailView: View {
    @State var viewModel: ProductDetailViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                LoadingView()
            case .failed(let message):
                ErrorStateView(message: message) {
                    Task { await viewModel.load() }
                }
            case .loaded(let product):
                details(of: product)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private func details(of product: Product) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                if !product.imageURLs.isEmpty {
                    TabView {
                        ForEach(product.imageURLs, id: \.self) { url in
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                ProgressView()
                            }
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(height: 300)
                }

                Text(product.title)
                    .font(.title2.bold())
                if let brand = product.brand {
                    Text(brand)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(product.price, format: .currency(code: "USD"))
                        .font(.title3.bold())
                    Spacer()
                    Label(product.rating.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                        .foregroundStyle(.orange)
                }
                Text(product.description)
            }
            .padding(Theme.Spacing.m)
        }
        .navigationTitle(product.title)
    }
}

#Preview {
    NavigationStack {
        ProductDetailView(viewModel: AppContainer.preview().makeProductDetailViewModel(id: 1))
    }
}
```

`swift_ui_template/Presentation/Dashboard/Home/HomeView.swift`:

```swift
import SwiftUI

struct HomeView: View {
    @Environment(AppContainer.self) private var container
    @State var viewModel: HomeViewModel

    var body: some View {
        content
            .navigationTitle("Home")
            .navigationDestination(for: Product.ID.self) { id in
                ProductDetailView(viewModel: container.makeProductDetailViewModel(id: id))
            }
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView()
        case .failed(let message):
            ErrorStateView(message: message) {
                Task { await viewModel.retry() }
            }
        case .loaded(let products) where products.isEmpty:
            EmptyStateView(message: "No products yet")
        case .loaded(let products):
            List {
                ForEach(products) { product in
                    NavigationLink(value: product.id) {
                        ProductRow(product: product)
                    }
                    .onAppear {
                        Task { await viewModel.loadMoreIfNeeded(current: product) }
                    }
                }
                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
            .listStyle(.plain)
            .refreshable { await viewModel.refresh() }
        }
    }
}

#Preview {
    let container = AppContainer.preview()
    NavigationStack {
        HomeView(viewModel: container.makeHomeViewModel())
    }
    .environment(container)
}
```

Thêm factory sau vào **cuối** class `AppContainer` trong `swift_ui_template/App/AppContainer.swift` (ngay trước dấu `}` cuối file):

```swift
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(getProducts: GetProductsUseCase(repository: productRepository))
    }

    func makeProductDetailViewModel(id: Product.ID) -> ProductDetailViewModel {
        ProductDetailViewModel(productID: id, getProductDetail: GetProductDetailUseCase(repository: productRepository))
    }
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/HomeViewModelTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 6 test case của `HomeViewModelTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/App/AppContainer.swift \
        swift_ui_template/Presentation/Dashboard/Home/HomeView.swift \
        swift_ui_template/Presentation/Dashboard/Home/HomeViewModel.swift \
        swift_ui_template/Presentation/Dashboard/Home/ProductRow.swift \
        swift_ui_template/Presentation/Dashboard/ProductDetail/ProductDetailView.swift \
        swift_ui_template/Presentation/Dashboard/ProductDetail/ProductDetailViewModel.swift \
        swift_ui_templateTests/Presentation/HomeViewModelTests.swift
git commit -m "feat(home): add paginated product list and product detail" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 22: Feature: Profile và Dashboard tabs

Tab Profile: thông tin user từ `/auth/me`, mở Settings để đổi ngôn ngữ, version, môi trường, logout có xác nhận. `DashboardView` gồm 2 tab Home và Profile.

**Files:**
- Create: `swift_ui_template/Presentation/Dashboard/Profile/ProfileViewModel.swift`
- Create: `swift_ui_template/Presentation/Dashboard/Profile/ProfileView.swift`
- Create: `swift_ui_template/Presentation/Dashboard/DashboardView.swift`
- Modify: `swift_ui_template/App/AppContainer.swift` (thêm factory)
- Test: `swift_ui_templateTests/Presentation/ProfileViewModelTests.swift`

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Presentation/ProfileViewModelTests.swift`:

```swift
import Testing
@testable import swift_ui_template

struct ProfileViewModelTests {
    private func makeViewModel(_ repository: MockAuthRepository) -> ProfileViewModel {
        ProfileViewModel(
            getCurrentUser: GetCurrentUserUseCase(repository: repository),
            logout: LogoutUseCase(repository: repository),
            environmentName: "dev",
            appVersion: "1.0 (1)"
        )
    }

    @Test func loadShowsCurrentUser() async {
        let viewModel = makeViewModel(MockAuthRepository(isLoggedIn: true, delay: .zero))

        await viewModel.load()

        #expect(viewModel.state == .loaded(SampleData.user))
    }

    @Test func loadFailureShowsMessage() async {
        let viewModel = makeViewModel(MockAuthRepository(isLoggedIn: true, failure: .noConnection, delay: .zero))

        await viewModel.load()

        #expect(viewModel.state == .failed(DomainError.noConnection.message))
    }

    @Test func logoutEndsSession() async {
        let repository = MockAuthRepository(isLoggedIn: true, delay: .zero)
        let viewModel = makeViewModel(repository)

        await viewModel.logout()

        #expect(await repository.isLoggedIn() == false)
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/ProfileViewModelTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: test target không compile được vì type/thành viên chưa tồn tại (ví dụ `error: cannot find 'ProfileViewModel' in scope`; dòng lỗi đầu tiên có thể nhắc tới type khác trong cùng task), kết thúc bằng `** TEST FAILED **`.

- [ ] **Step 3: Viết code**

`swift_ui_template/Presentation/Dashboard/Profile/ProfileViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
final class ProfileViewModel {
    private(set) var state: ViewState<User> = .idle
    var isConfirmingLogout = false
    let environmentName: String
    let appVersion: String

    private let getCurrentUser: GetCurrentUserUseCase
    private let logoutUseCase: LogoutUseCase

    init(getCurrentUser: GetCurrentUserUseCase, logout: LogoutUseCase, environmentName: String, appVersion: String) {
        self.getCurrentUser = getCurrentUser
        logoutUseCase = logout
        self.environmentName = environmentName
        self.appVersion = appVersion
    }

    /// Loads once; switching tabs back does not refetch.
    func load() async {
        guard case .idle = state else { return }
        await fetchUser()
    }

    func retry() async {
        await fetchUser()
    }

    /// `AppRouter` returns to Login when the `.loggedOut` event arrives.
    func logout() async {
        await logoutUseCase()
    }

    private func fetchUser() async {
        state = .loading
        do {
            state = .loaded(try await getCurrentUser())
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(error.userMessage)
        }
    }
}
```

`swift_ui_template/Presentation/Dashboard/Profile/ProfileView.swift`:

```swift
import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(\.openURL) private var openURL
    @State var viewModel: ProfileViewModel

    var body: some View {
        List {
            Section {
                header
            }

            Section("Settings") {
                Button {
                    // iOS shows a per-app Language picker here when the app has 2+ localizations.
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    LabeledContent("Language") {
                        Image(systemName: "arrow.up.forward.app")
                    }
                }
                .tint(.primary)
                LabeledContent("Version", value: viewModel.appVersion)
                LabeledContent("Environment", value: viewModel.environmentName)
            }

            Section {
                Button("Log Out", role: .destructive) {
                    viewModel.isConfirmingLogout = true
                }
            }
        }
        .navigationTitle("Profile")
        .task { await viewModel.load() }
        .confirmationDialog("Log out of your account?", isPresented: $viewModel.isConfirmingLogout, titleVisibility: .visible) {
            Button("Log Out", role: .destructive) {
                Task { await viewModel.logout() }
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
        case .failed(let message):
            VStack(spacing: Theme.Spacing.s) {
                Text(message)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task { await viewModel.retry() }
                }
            }
            .frame(maxWidth: .infinity)
        case .loaded(let user):
            HStack(spacing: Theme.Spacing.m) {
                AsyncImage(url: user.avatarURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(user.fullName)
                        .font(.headline)
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView(viewModel: AppContainer.preview().makeProfileViewModel())
    }
}
```

`swift_ui_template/Presentation/Dashboard/DashboardView.swift`:

```swift
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
```

Thêm factory sau vào **cuối** class `AppContainer` trong `swift_ui_template/App/AppContainer.swift` (ngay trước dấu `}` cuối file):

```swift
    func makeProfileViewModel() -> ProfileViewModel {
        ProfileViewModel(
            getCurrentUser: GetCurrentUserUseCase(repository: authRepository),
            logout: LogoutUseCase(repository: authRepository),
            environmentName: environment.name,
            appVersion: "\(Bundle.main.appVersion) (\(Bundle.main.buildNumber))"
        )
    }
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/ProfileViewModelTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 3 test case của `ProfileViewModelTests` `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/App/AppContainer.swift \
        swift_ui_template/Presentation/Dashboard/DashboardView.swift \
        swift_ui_template/Presentation/Dashboard/Profile/ProfileView.swift \
        swift_ui_template/Presentation/Dashboard/Profile/ProfileViewModel.swift \
        swift_ui_templateTests/Presentation/ProfileViewModelTests.swift
git commit -m "feat(profile): add profile tab and dashboard" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 23: App wiring — RootView, MainApp, bỏ ContentView

**Files:**
- Create: `swift_ui_template/App/RootView.swift`
- Modify: `swift_ui_template/App/MainApp.swift`
- Delete: `swift_ui_template/ContentView.swift`

- [ ] **Step 1: Viết `RootView`**

`swift_ui_template/App/RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    @Environment(AppContainer.self) private var container
    let router: AppRouter

    var body: some View {
        ZStack {
            switch router.route {
            case .launching:
                Color.clear
            case .onboarding:
                OnboardingView(viewModel: container.makeOnboardingViewModel(onFinish: router.onboardingFinished))
                    .transition(.opacity)
            case .login:
                LoginView(viewModel: container.makeLoginViewModel())
                    .transition(.opacity)
            case .main:
                DashboardView()
                    .transition(.opacity)
            }
        }
        .animation(.default, value: router.route)
        .task {
            await router.start()
            await router.observeSession()
        }
    }
}

#Preview {
    let container = AppContainer.preview(isLoggedIn: false)
    RootView(router: container.makeAppRouter())
        .environment(container)
}
```

- [ ] **Step 2: Thay `MainApp` và xoá `ContentView`**

`swift_ui_template/App/MainApp.swift`:

```swift
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
```

```sh
git rm -q swift_ui_template/ContentView.swift
xcodebuild test -scheme Dev -destination "$DEST" 2>&1 | grep -E "error:|warning:|\*\* TEST"
```

Expected: `** TEST SUCCEEDED **`, không có `error:`/`warning:` (dòng `appintentsmetadataprocessor ... warning: Metadata extraction skipped` của Xcode thì bỏ qua).

- [ ] **Step 3: Chạy thử app trên simulator**

Mở `swift_ui_template.xcodeproj`, chọn scheme **Dev**, Run. Kiểm tra:
1. Lần đầu mở: Onboarding 3 trang; `Skip` hoặc `Get Started` → Login.
2. Login đã điền sẵn `emilys` / `emilyspass` → `Log In` → Dashboard (tab Home hiện danh sách sản phẩm).
3. Kéo xuống để refresh; cuộn tới cuối thì load thêm trang; bấm một sản phẩm → màn chi tiết.
4. Tab Profile: tên, email, avatar; `Version`, `Environment = dev`; `Log Out` → hộp xác nhận → về Login.
5. Đổi password thành `wrongpass` → alert "Incorrect username or password."
6. Tắt app, mở lại sau khi login: vào thẳng Dashboard.
7. *Edit Scheme → Run → Arguments*: bật `-UseMockData`, chạy lại → app hoạt động không cần mạng.

- [ ] **Step 4: Commit**

```sh
git add swift_ui_template/App/RootView.swift swift_ui_template/App/MainApp.swift
git commit -m "feat(app): wire RootView and MainApp to the router and container" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 24: Đa ngôn ngữ (en/vi)

**Files:**
- Create: `swift_ui_template/Resources/Localizable.xcstrings`
- Test: `swift_ui_templateTests/Presentation/LocalizationTests.swift`

`knownRegions` đã có `vi` từ Task 2. Danh sách key dưới đây đúng bằng các chuỗi mà compiler trích ra từ code (kiểm tra bằng file `.stringsdata` khi build).

- [ ] **Step 1: Viết test thất bại**

`swift_ui_templateTests/Presentation/LocalizationTests.swift`:

```swift
import Foundation
import Testing

struct LocalizationTests {
    private func vietnameseBundle() throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: "vi", ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    @Test func appShipsVietnamese() throws {
        let bundle = try vietnameseBundle()

        #expect(bundle.localizedString(forKey: "Log In", value: nil, table: nil) == "Đăng nhập")
    }

    @Test func formatsArguments() throws {
        let bundle = try vietnameseBundle()
        let format = bundle.localizedString(forKey: "Must be at least %lld characters.", value: nil, table: nil)

        #expect(String(format: format, 6) == "Cần ít nhất 6 ký tự.")
    }
}
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/LocalizationTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 2 test case `failed` (`#require` không tìm thấy `vi.lproj`), `** TEST FAILED **`.

- [ ] **Step 3: Tạo String Catalog**

`swift_ui_template/Resources/Localizable.xcstrings`:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "A clean SwiftUI starting point for your next app." : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Điểm khởi đầu gọn gàng cho ứng dụng SwiftUI tiếp theo của bạn."
          }
        }
      }
    },
    "Built to grow" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Sẵn sàng mở rộng"
          }
        }
      }
    },
    "Clear layers make new features easy to add and test." : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Các tầng tách bạch giúp thêm và kiểm thử tính năng mới dễ dàng."
          }
        }
      }
    },
    "Environment" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Môi trường"
          }
        }
      }
    },
    "Get Started" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Bắt đầu"
          }
        }
      }
    },
    "Hide password" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Ẩn mật khẩu"
          }
        }
      }
    },
    "Home" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Trang chủ"
          }
        }
      }
    },
    "Incorrect username or password." : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Tên đăng nhập hoặc mật khẩu không đúng."
          }
        }
      }
    },
    "Language" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Ngôn ngữ"
          }
        }
      }
    },
    "Log In" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Đăng nhập"
          }
        }
      }
    },
    "Log Out" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Đăng xuất"
          }
        }
      }
    },
    "Log out of your account?" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Đăng xuất khỏi tài khoản?"
          }
        }
      }
    },
    "Login failed" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Đăng nhập thất bại"
          }
        }
      }
    },
    "Must be at least %lld characters." : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Cần ít nhất %lld ký tự."
          }
        }
      }
    },
    "Networking, secure storage and session handling are built in." : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Có sẵn gọi mạng, lưu trữ bảo mật và quản lý phiên đăng nhập."
          }
        }
      }
    },
    "Next" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Tiếp"
          }
        }
      }
    },
    "No internet connection. Please try again." : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Không có kết nối mạng. Vui lòng thử lại."
          }
        }
      }
    },
    "No products yet" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Chưa có sản phẩm"
          }
        }
      }
    },
    "OK" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "OK"
          }
        }
      }
    },
    "Password" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Mật khẩu"
          }
        }
      }
    },
    "Profile" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Hồ sơ"
          }
        }
      }
    },
    "Ready to connect" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Sẵn sàng kết nối"
          }
        }
      }
    },
    "Retry" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Thử lại"
          }
        }
      }
    },
    "Settings" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Cài đặt"
          }
        }
      }
    },
    "Show password" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Hiện mật khẩu"
          }
        }
      }
    },
    "Sign in to continue" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Đăng nhập để tiếp tục"
          }
        }
      }
    },
    "Skip" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Bỏ qua"
          }
        }
      }
    },
    "Something went wrong" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Đã có lỗi xảy ra"
          }
        }
      }
    },
    "Something went wrong. Please try again." : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Đã có lỗi xảy ra. Vui lòng thử lại."
          }
        }
      }
    },
    "This field is required." : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Vui lòng nhập trường này."
          }
        }
      }
    },
    "Username" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Tên đăng nhập"
          }
        }
      }
    },
    "Version" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Phiên bản"
          }
        }
      }
    },
    "Welcome" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Chào mừng"
          }
        }
      }
    },
    "Welcome back" : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Chào mừng trở lại"
          }
        }
      }
    },
    "Your session has expired. Please log in again." : {
      "localizations" : {
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."
          }
        }
      }
    }
  },
  "version" : "1.0"
}
```

- [ ] **Step 4: Chạy test, kỳ vọng PASS**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -only-testing:swift_ui_templateTests/LocalizationTests 2>&1 | grep -E "error:|' (passed|failed)|\*\* TEST"
```

Expected: 2 test case `passed`, `** TEST SUCCEEDED **`. Chạy app với simulator để tiếng Việt (hoặc *Edit Scheme → Run → Options → App Language → Vietnamese*) để xem bản dịch.

- [ ] **Step 5: Commit**

```sh
git add swift_ui_template/Resources/Localizable.xcstrings \
        swift_ui_templateTests/Presentation/LocalizationTests.swift
git commit -m "feat(l10n): add English and Vietnamese string catalog" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 25: Rename script và README

**Files:**
- Create: `scripts/rename.sh`
- Create: `README.md`

- [ ] **Step 1: Viết script đổi tên**

`scripts/rename.sh`:

```sh
#!/bin/sh
# Renames the template's project, targets, folders and bundle identifier.
# Run once, right after cloning:  scripts/rename.sh MyApp com.company.myapp
set -eu

OLD_NAME="swift_ui_template"
OLD_BUNDLE_ID="com.app.opt.swift-ui-template"
OLD_BUNDLE_ID_PATTERN='com\.app\.opt\.swift-ui-template'

if [ $# -ne 2 ]; then
  echo "Usage: $0 <NewName> <bundle.identifier>" >&2
  exit 1
fi
NEW_NAME="$1"
NEW_BUNDLE_ID="$2"

case "$NEW_NAME" in
  '' | [0-9_]* | *[!A-Za-z0-9_]*)
    echo "NewName must start with a letter and contain only letters, digits and _." >&2
    exit 1 ;;
esac
case "$NEW_BUNDLE_ID" in
  '' | .* | *. | *..* | *[!A-Za-z0-9.-]*)
    echo "Invalid bundle identifier: $NEW_BUNDLE_ID" >&2
    exit 1 ;;
esac

cd "$(dirname "$0")/.."

if [ ! -d "$OLD_NAME.xcodeproj" ]; then
  echo "$OLD_NAME.xcodeproj not found. Was the project already renamed?" >&2
  exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is not clean. Commit or stash your changes first." >&2
  exit 1
fi

# 1. Rewrite names inside tracked files.
git ls-files | grep -E '\.(pbxproj|xcscheme|xcconfig|swift)$|^README\.md$' | while IFS= read -r file; do
  sed -i '' -e "s/$OLD_BUNDLE_ID_PATTERN/$NEW_BUNDLE_ID/g" -e "s/$OLD_NAME/$NEW_NAME/g" "$file"
done
sed -i '' -e "s/^APP_NAME = .*/APP_NAME = $NEW_NAME/" Configs/Base.xcconfig

# 2. Rename folders and the project bundle.
git mv "${OLD_NAME}Tests" "${NEW_NAME}Tests"
git mv "$OLD_NAME" "$NEW_NAME"
git mv "$OLD_NAME.xcodeproj" "$NEW_NAME.xcodeproj"

echo "Renamed $OLD_NAME ($OLD_BUNDLE_ID) to $NEW_NAME ($NEW_BUNDLE_ID)."
echo "Next steps:"
echo "  1. xcodebuild test -scheme Dev -destination 'platform=iOS Simulator,name=iPhone 17'"
echo "  2. git add -A && git commit -m \"chore: rename template to $NEW_NAME\""
echo "  3. Open $NEW_NAME.xcodeproj and pick your signing team."
```

```sh
chmod +x scripts/rename.sh && sh -n scripts/rename.sh && echo SYNTAX_OK
```

Expected: `SYNTAX_OK`

- [ ] **Step 2: Viết README**

`README.md`:

````markdown
# SwiftUI Starter Template

Template iOS (SwiftUI, iOS 17+, Swift 6) có sẵn network, lưu trữ an toàn, Clean Architecture và 3 luồng màn hình **Onboarding → Login → Dashboard**. Clone về, đổi tên, build là chạy — không cần thư viện bên thứ ba.

## Yêu cầu

- Xcode 26 trở lên (dự án dùng Swift 6.2: `@concurrent`, default `MainActor` isolation)
- iOS 17.0+

## Bắt đầu dự án mới

```sh
git clone <repo-url> MyApp && cd MyApp
scripts/rename.sh MyApp com.company.myapp      # đổi tên project, target, folder, bundle id
xcodebuild test -scheme Dev -destination 'platform=iOS Simulator,name=iPhone 17'
git add -A && git commit -m "chore: rename template to MyApp"
```

Mở `MyApp.xcodeproj`, chọn signing team, chạy scheme **Dev**.

Tài khoản test (DummyJSON): `emilys` / `emilyspass` — bản Debug điền sẵn.

## Môi trường

| Scheme / Configuration | Bundle ID | Tên app | Ghi chú |
|---|---|---|---|
| Dev | `<bundle id>.dev` | `<App> Dev` | Debug, có unit test |
| Staging | `<bundle id>.stg` | `<App> Stg` | Release |
| Prod | `<bundle id>` | `<App>` | Release |

- Đổi base URL trong `Configs/Dev.xcconfig`, `Staging.xcconfig`, `Prod.xcconfig` (`API_BASE_URL`). Viết `https:/$()/host` vì `//` là comment trong xcconfig.
- Giá trị đi vào `Configs/Info.plist` và được đọc bởi `AppEnvironment.current`.
- Thêm biến mới: khai báo trong xcconfig → thêm key vào `Configs/Info.plist` → đọc trong `AppEnvironment`.
- Chạy offline: bật launch argument `-UseMockData` trong *Edit Scheme → Run → Arguments*.

## Kiến trúc

```
Presentation ──▶ Domain ◀── Data ──▶ Core
      ▲                                ▲
      └──────────── App (AppContainer) ┘
```

| Thư mục | Vai trò | Được phụ thuộc vào |
|---|---|---|
| `App/` | `MainApp`, `AppContainer` (composition root, factory ViewModel), `AppRouter`, `RootView` | tất cả |
| `Core/` | `Network` (APIClient, refresh token), `Storage` (UserDefaults, Keychain), `Utils`, `Config` | — |
| `Domain/` | Model, `DomainError`, repository protocol, use case | Core/Utils |
| `Data/` | DTO, mapper, endpoint, repository implementation, mock | Domain, Core |
| `Presentation/` | View + `@Observable` ViewModel theo feature, `Common/` component | Domain |

Quy tắc:
- ViewModel chỉ gọi **use case**, chỉ thấy `DomainError` (message localized ở `DomainError+Message.swift`).
- Chỉ `AppContainer` biết kiểu cụ thể của Data layer.
- Token chỉ nằm trong Keychain (`TokenStore`); `UserDefaults` chỉ cho dữ liệu không nhạy cảm (`KeyValueStore`).

### Luồng phiên đăng nhập

1. `AppRouter.start()` chọn `.onboarding` / `.main` / `.login`.
2. Request có `requiresAuth` được gắn `Bearer`. Gặp 401 → `TokenRefresher` refresh **một lần** cho mọi request đồng thời → retry.
3. Refresh thất bại → xoá token → phát `SessionEvent.expired` → `AppRouter` về Login. Logout phát `.loggedOut`, login phát `.loggedIn`.

### Concurrency (Swift 6)

- Target dùng default isolation `MainActor`: View, ViewModel mặc định chạy trên main.
- Type dùng ngoài main (DTO, Domain model, repository, network, storage) phải khai báo `nonisolated` và `Sendable`. Thiếu `nonisolated` ở DTO sẽ gây lỗi khi gọi `apiClient.send`.
- Dự án bật `MemberImportVisibility`: file nào dùng `AppLogger` phải `import OSLog`; file dùng `UIColor`/`UIApplication` phải `import UIKit`.

## Thêm một feature mới (ví dụ: Orders)

1. **Endpoint** — `Data/Remote/OrderEndpoint.swift`: `nonisolated enum OrderEndpoint: Endpoint`.
2. **DTO + mapper** — `Data/DTOs/OrderDTOs.swift`, `Data/Mappers/OrderMappers.swift` (`toDomain()`).
3. **Domain** — `Domain/Models/Order.swift`, `Domain/Repositories/OrderRepository.swift`, `Domain/UseCases/GetOrdersUseCase.swift`.
4. **Repository** — `Data/Repositories/RemoteOrderRepository.swift` (bọc lỗi bằng `mapToDomainError`) + `Data/Mocks/MockOrderRepository.swift`.
5. **ViewModel + View** — `Presentation/Orders/OrdersViewModel.swift` (`ViewState`), `OrdersView.swift`.
6. **Đăng ký** — thêm repository vào `AppContainer` (`live` và `preview`) và factory `makeOrdersViewModel()`.
7. **Test** — mapper, repository (`StubAPIClient` hoặc `URLProtocolStub`), ViewModel (mock repository).
8. **Text** — thêm bản dịch tiếng Việt cho chuỗi mới trong `Resources/Localizable.xcstrings`.

## Đa ngôn ngữ

- `Resources/Localizable.xcstrings`: tiếng Anh là ngôn ngữ nguồn, có bản dịch tiếng Việt.
- Trong View dùng literal (`Text("Log In")`); ngoài View dùng `String(localized:)`.
- Người dùng đổi ngôn ngữ trong *Settings → <App> → Language* (Profile có nút mở nhanh).

## Test

```sh
xcodebuild test -scheme Dev -destination 'platform=iOS Simulator,name=iPhone 17'
```

Swift Testing, hosted trong app. Helper ở `swift_ui_templateTests/Helpers`:
- `URLProtocolStub` — giả lập server cho `URLSession` (mỗi test một host riêng, chạy song song an toàn).
- `StubAPIClient` — giả lập `APIClient` cho test repository.
- `TestFixtures`, `waitUntil`.

## Cố ý chưa làm

| Tính năng | Gợi ý chỗ thêm |
|---|---|
| Đăng ký, quên mật khẩu, social login | `Presentation/Auth/`, thêm hàm vào `AuthRepository` |
| Push notification, analytics, crash reporting | `App/` (AppDelegate adaptor) + service trong `Core/` |
| Cache offline | Decorator cho repository trong `Data/` |
| Đổi ngôn ngữ trong app, theme switcher | `KeyValueStore` + màn Settings riêng |
| Upload/download file, theo dõi mạng | Mở rộng `APIClient`, `NWPathMonitor` trong `Core/Network` |
````

- [ ] **Step 3: Commit (script cần working tree sạch nên commit trước khi thử)**

```sh
git add scripts/rename.sh README.md
git commit -m "docs: add README and project rename script" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 4: Thử rename trên một bản clone tạm**

```sh
TMP=$(mktemp -d) && git clone -q . "$TMP/app" && cd "$TMP/app"
scripts/rename.sh 9bad com.x.y; echo "exit=$?"
scripts/rename.sh MyApp com.company.myapp
grep -rn -e swift_ui_template -e swift-ui-template --include='*.swift' --include='*.pbxproj' --include='*.xcscheme' --include='*.xcconfig' --include='README.md' . ; echo "leftovers=$?"
xcodebuild test -scheme Dev -destination "$DEST" -derivedDataPath "$TMP/dd" 2>&1 | grep -E "error:|\*\* TEST"
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" -c "Print :CFBundleDisplayName" "$TMP/dd/Build/Products/Dev-iphonesimulator/MyApp.app/Info.plist"
cd - >/dev/null && rm -rf "$TMP"
```

Expected:
- Lần gọi `9bad` in `NewName must start with a letter ...` và `exit=1`.
- Lần gọi `MyApp` in `Renamed swift_ui_template ... to MyApp ...`.
- `leftovers=1` (grep không tìm thấy tên cũ).
- `** TEST SUCCEEDED **`, rồi `com.company.myapp.dev` và `MyApp Dev`.

---

### Task 26: Kiểm tra cuối

**Files:** không đổi (chỉ kiểm tra).

- [ ] **Step 1: Chạy toàn bộ test**

```sh
xcodebuild test -scheme Dev -destination "$DEST" -derivedDataPath build/dd > build/test.log 2>&1; grep -E "\*\* TEST" build/test.log
grep -c "' passed on" build/test.log; grep -c "' failed on" build/test.log
```

Expected: `** TEST SUCCEEDED **`, `90`, `0` (lệnh `grep -c` cuối trả exit code 1 khi đếm được 0 — bình thường).

- [ ] **Step 2: Build Staging và Prod, kiểm tra Info.plist**

```sh
for s in Staging Prod; do
  xcodebuild build -scheme $s -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd -quiet && echo "$s BUILD_OK"
  /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" -c "Print :CFBundleDisplayName" -c "Print :APP_ENVIRONMENT" \
    build/dd/Build/Products/$s-iphonesimulator/swift_ui_template.app/Info.plist
done
```

Expected:
- `Staging BUILD_OK`, `com.app.opt.swift-ui-template.stg`, `Template Stg`, `staging`
- `Prod BUILD_OK`, `com.app.opt.swift-ui-template`, `Template`, `prod`

- [ ] **Step 3: Working tree sạch**

```sh
git status --short
```

Expected: không có dòng nào (thư mục `build/` đã bị ignore). Nếu Xcode tự sửa `Localizable.xcstrings` khi build trong IDE (ví dụ thêm `extractionState`), xem diff và commit nếu hợp lý.
