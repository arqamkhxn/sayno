# CHANGELOG — AI DEVELOPMENTS

## [2026-06-20] - Sprint 5D: Documentation & Closure

### Created Files
- [phase_2_closure_report.md (Workspace)](file:///d:/sayno-main-phase-1/project_docs/phase_2_closure_report.md)
- [phase_2_closure_report.md (Artifact)](file:///C:/Users/mdmus/.gemini/antigravity-ide/brain/3a363d01-1372-4078-8e7c-08c4c90a023f/phase_2_closure_report.md)

### Modified Files
- [MASTER_ARCHITECTURE.md](file:///d:/sayno-main-phase-1/project_docs/MASTER_ARCHITECTURE.md)
- [PROJECT_STATUS.md](file:///d:/sayno-main-phase-1/project_docs/PROJECT_STATUS.md)
- [CHANGELOG_AI.md](file:///d:/sayno-main-phase-1/project_docs/CHANGELOG_AI.md)

### Major Features Added
- **Finalized Phase 2 Documentation**: Documented the native-first protection architecture and native-to-Flutter sync model in the master architecture.
- **Project Status Update**: Marked Phase 2 as completed and listed remaining known limitations.
- **Closure Report & Readiness Review**: Produced a complete release readiness assessment and blocker verdict.

## [2026-06-20] - Sprint 5C: Cleanup & Production Preparation

### Deleted Files
- [app_limit.dart](file:///d:/sayno-main-phase-1/lib/features/protection/domain/app_limit.dart)

### Modified Files
- [MainActivity.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/MainActivity.kt)
- [SayNoAccessibilityService.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoAccessibilityService.kt)
- [SayNoLimitManager.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoLimitManager.kt)
- [SayNoInterventionManager.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoInterventionManager.kt)
- [SayNoOverlayManager.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoOverlayManager.kt)
- [settings_screen.dart](file:///d:/sayno-main-phase-1/lib/features/settings/presentation/settings_screen.dart)
- [app_detection_controller.dart](file:///d:/sayno-main-phase-1/lib/features/protection/application/app_detection_controller.dart)
- [block_overlay_controller.dart](file:///d:/sayno-main-phase-1/lib/features/protection/application/block_overlay_controller.dart)
- [intervention_controller.dart](file:///d:/sayno-main-phase-1/lib/features/protection/application/intervention_controller.dart)
- [keyword_controller.dart](file:///d:/sayno-main-phase-1/lib/features/protection/application/keyword_controller.dart)
- [protection_platform_service.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/protection_platform_service.dart)
- [intervention_controller_test.dart](file:///d:/sayno-main-phase-1/test/features/protection/application/intervention_controller_test.dart)

### Major Features Added
- **Developer UI Removal**: Removed all manual testing controls and developer testing views from the Settings screen.
- **Diagnostic Log Cleanup**: Removed all debug (`Log.d`), performance (`SAYNO_PERF`), lifecycle (`SAYNO_LIFECYCLE`), and limit (`SAYNO_LIMIT`) logs from Kotlin, and removed all `SAYNO_FLUTTER` console print statements from Flutter code. Retained critical error (`Log.e`) and clock-drift warnings (`Log.w`).
- **Unused Code Removal**: Deleted the unused `AppLimit` domain model class and removed unused companion variable definitions. Confirmed zero errors and warnings in analyzer.

## [2026-06-20] - Sprint 5B: Critical & High Severity Bug Fixes

### Created Files
- [task.md](file:///C:/Users/mdmus/.gemini/antigravity-ide/brain/3a363d01-1372-4078-8e7c-08c4c90a023f/task.md)
- [implementation_plan.md](file:///C:/Users/mdmus/.gemini/antigravity-ide/brain/3a363d01-1372-4078-8e7c-08c4c90a023f/implementation_plan.md)
- [walkthrough.md](file:///C:/Users/mdmus/.gemini/antigravity-ide/brain/3a363d01-1372-4078-8e7c-08c4c90a023f/walkthrough.md)

### Modified Files
- [MainActivity.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/MainActivity.kt)
- [SayNoAccessibilityService.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoAccessibilityService.kt)
- [SayNoLimitManager.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoLimitManager.kt)

### Major Features Added
- **Accessibility OFF → ON Recovery (BUG-003)**: Added auto-reattachment of `MethodChannel` listener on Accessibility Service connection if `MainActivity` is alive. Verified native protection continues running independently when UI is closed.
- **Double Counting Resolution (BUG-004)**: Updated native usage queries to exclude current session tracking duration, leaving Flutter as the single source of truth for counting live session seconds.
- **Midnight Reset Cheat Protection**: Implemented chronological checks to ignore backward date modifications.
- **Starvation Protection**: Designed a throttled-debounce content scanner in accessibility events that bypasses debounce and triggers an immediate scan if continuous scrolling/typing runs for 1 second.

## [2026-06-20] - Sprint 5A: Validation Execution

### Created Files
- [validation_report.md](file:///C:/Users/mdmus/.gemini/antigravity-ide/brain/3a363d01-1372-4078-8e7c-08c4c90a023f/validation_report.md)

### Major Features Added
- **Phase 2 Audit**: Executed manual and automated verification across limits, keyword detection, app switching, screen off/on, lock/unlock, accessibility service restarts, and reboots. Identified BUG-003, BUG-004, date-change bypass, and scrolling starvation issues.

## [2026-06-17] - Phase 2E: Intervention Engine

### Created Files
- [intervention_state.dart](file:///d:/sayno-main-phase-1/lib/features/protection/domain/intervention_state.dart)
- [intervention_controller.dart](file:///d:/sayno-main-phase-1/lib/features/protection/application/intervention_controller.dart)
- [intervention_controller_test.dart](file:///d:/sayno-main-phase-1/test/features/protection/application/intervention_controller_test.dart)

### Modified Files
- [SayNoAccessibilityService.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoAccessibilityService.kt)
- [MainActivity.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/MainActivity.kt)
- [protection_platform_service.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/protection_platform_service.dart)
- [block_overlay_controller.dart](file:///d:/sayno-main-phase-1/lib/features/protection/application/block_overlay_controller.dart)
- [block_overlay_controller_test.dart](file:///d:/sayno-main-phase-1/test/features/protection/application/block_overlay_controller_test.dart)
- [app.dart](file:///d:/sayno-main-phase-1/lib/app.dart)
- [MASTER_ARCHITECTURE.md](file:///d:/sayno-main-phase-1/project_docs/MASTER_ARCHITECTURE.md)
- [PROJECT_STATUS.md](file:///d:/sayno-main-phase-1/project_docs/PROJECT_STATUS.md)

### Major Features Added
- **Centralized Intervention Controller**: Created `InterventionNotifier` to coordinate reactions to keyword scan hits and daily limit exceeded triggers.
- **Android accessibility actions**: Bound method channel handlers (`performBack`, `performHome`, `triggerRescan`) to Android accessibility global gestures.
- **Wired Block Overlay Actions**: Modified overlay callbacks to dismiss the overlay first and then perform native Back or Home gestures, keeping the interface highly responsive.
- **Timeout and safety rules**: Implemented a maximum of 2 Back attempts with a 750ms scan delay, a 1500ms timeout for scanning, single intervention concurrency constraint, and resetting state on app transitions only when not active.
- **Comprehensive test suite**: Created 8 new unit tests verifying the full flow under successful backouts, failed actions, fallback home actions, daily limits, and concurrency safety.

## [2026-06-17] - Phase 2F: Block Overlay Foundation

### Created Files
- [block_reason.dart](file:///d:/sayno-main-phase-1/lib/features/protection/domain/block_reason.dart)
- [block_overlay_controller.dart](file:///d:/sayno-main-phase-1/lib/features/protection/application/block_overlay_controller.dart)
- [block_overlay.dart](file:///d:/sayno-main-phase-1/lib/features/protection/presentation/block_overlay.dart)
- [block_overlay_controller_test.dart](file:///d:/sayno-main-phase-1/test/features/protection/application/block_overlay_controller_test.dart)
- [block_overlay_test.dart](file:///d:/sayno-main-phase-1/test/features/protection/presentation/block_overlay_test.dart)

### Modified Files
- [app.dart](file:///d:/sayno-main-phase-1/lib/app.dart)
- [settings_screen.dart](file:///d:/sayno-main-phase-1/lib/features/settings/presentation/settings_screen.dart)
- [MASTER_ARCHITECTURE.md](file:///d:/sayno-main-phase-1/project_docs/MASTER_ARCHITECTURE.md)
- [PROJECT_STATUS.md](file:///d:/sayno-main-phase-1/project_docs/PROJECT_STATUS.md)

### Major Features Added
- **Reusable Block Reason Model**: Declared `BlockReason` enum supporting `restrictedContent` and `dailyLimitReached` along with custom calm title and non-aggressive message text extensions.
- **Riverpod Overlay State Controller**: Built `BlockOverlayNotifier` exposing `isVisible` and `reason` state selectors, alongside separate `handleGoBack()` and `handleClose()` action callbacks.
- **Premium Minimal Overlay UI**: Implemented `BlockOverlay` rendering a near-black, centered lock icon screen with primary/secondary buttons.
- **Root Shell Integration**: Wrapped the MaterialApp's router in a builder `Stack` ensuring the overlay sits at the absolute root of GoRouter and covers navigation bars.
- **Labeled Developer Options**: Created a dedicated, temporary "Developer Tooling (Temporary)" section in Settings screen with two manual testing buttons.

### Breaking Changes
- None

## [2026-06-17] - Phase 2D.1: Keyword Detection Foundation

### Created Files
- [keyword_registry.dart](file:///d:/sayno-main-phase-1/lib/features/protection/domain/keyword_registry.dart)
- [keyword_scan_state.dart](file:///d:/sayno-main-phase-1/lib/features/protection/domain/keyword_scan_state.dart)
- [keyword_controller.dart](file:///d:/sayno-main-phase-1/lib/features/protection/application/keyword_controller.dart)
- [keyword_controller_test.dart](file:///d:/sayno-main-phase-1/test/features/protection/application/keyword_controller_test.dart)

### Modified Files
- [sayno_accessibility_service.xml](file:///d:/sayno-main-phase-1/android/app/src/main/res/xml/sayno_accessibility_service.xml)
- [SayNoAccessibilityService.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoAccessibilityService.kt)
- [MainActivity.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/MainActivity.kt)
- [protection_platform_service.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/protection_platform_service.dart)
- [app_detection_controller.dart](file:///d:/sayno-main-phase-1/lib/features/protection/application/app_detection_controller.dart)
- [monitored_apps.dart](file:///d:/sayno-main-phase-1/lib/features/protection/domain/monitored_apps.dart)
- [MASTER_ARCHITECTURE.md](file:///d:/sayno-main-phase-1/project_docs/MASTER_ARCHITECTURE.md)
- [PROJECT_STATUS.md](file:///d:/sayno-main-phase-1/project_docs/PROJECT_STATUS.md)

### Major Features Added
- **Accessibility Service Config**: Enabled `canRetrieveWindowContent=true` and added `typeWindowContentChanged` to the service XML to allow node tree access and receive real-time content change events.
- **Native Keyword Registry**: Configurable keyword list is pushed from Flutter to Kotlin at startup via `updateKeywords` channel call. Matching happens entirely on-device \u2014 raw scanned text never crosses the bridge.
- **High-Risk App Whitelist**: Introduced `highRiskPackages` (browsers, Telegram, Reddit, TeraBox) in both Dart (`monitored_apps.dart`) and Kotlin (`SayNoAccessibilityService`). Only these apps trigger node traversal.
- **Debounced Node Traversal**: Recursive `extractText()` function walks the `AccessibilityNodeInfo` tree, collecting visible text and content descriptions. Triggered by a `Handler`-based 500ms debounce on `TYPE_WINDOW_CONTENT_CHANGED` events. Child nodes are recycled to prevent memory leaks.
- **Native-Side Matching**: After traversal, all keyword matching is performed in Kotlin. Only the structured result (`restrictedContentDetected`, `matchedKeywords`, `timestamp`, `packageName`) is dispatched to Flutter.
- **Ephemeral State Model**: `KeywordScanState` (never persisted) holds scan results in memory. Resets automatically via `resetState()` when the foreground app is no longer in `highRiskPackages`.
- **Riverpod Integration**: `keywordScanProvider` + four convenience selectors wired into `app_detection_controller.dart` via the existing accessibility event switch.
- **New Platform Channels**: `updateHighRiskApps` and `updateKeywords` added to both `ProtectionPlatformService` and `MainActivity`.

### Breaking Changes
- None

## [2026-06-17] - Phase 2G: Daily Limit Enforcement

### Created Files
- [app_limit.dart](file:///d:/sayno-main-phase-1/lib/features/protection/domain/app_limit.dart)
- [limit_repository.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/limit_repository.dart)
- [limit_controller.dart](file:///d:/sayno-main-phase-1/lib/features/protection/application/limit_controller.dart)
- [limit_repository_test.dart](file:///d:/sayno-main-phase-1/test/features/protection/data/limit_repository_test.dart)
- [limit_controller_test.dart](file:///d:/sayno-main-phase-1/test/features/protection/application/limit_controller_test.dart)

### Modified Files
- [session_database.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/session_database.dart)
- [dashboard_screen.dart](file:///d:/sayno-main-phase-1/lib/features/dashboard/presentation/dashboard_screen.dart)
- [health_screen.dart](file:///d:/sayno-main-phase-1/lib/features/health/presentation/health_screen.dart)
- [app_usage_tile.dart](file:///d:/sayno-main-phase-1/lib/features/health/presentation/widgets/app_usage_tile.dart)
- [MASTER_ARCHITECTURE.md](file:///d:/sayno-main-phase-1/project_docs/MASTER_ARCHITECTURE.md)
- [PROJECT_STATUS.md](file:///d:/sayno-main-phase-1/project_docs/PROJECT_STATUS.md)

### Major Features Added
- **SQLite Database Version Upgrade**: Migrated database version from `1` to `2`. Implemented dynamic schema table additions (`app_limits`) inside `onUpgrade` to preserve historical usage statistics.
- **Repository Interface & CRUD**: Built `LimitRepository` to perform CRUD queries on the SQLite `app_limits` table.
- **Reactive State Providers**: Defined asynchronous `appLimitsProvider` to manage limits state and expose `setLimit` and `removeLimit` triggers.
- **Real-Time Limit Evaluation**: Engineered `isLimitReachedMapProvider` and `isActiveAppLimitReachedProvider` evaluating reached/exceeded limits instantly by listening to real-time usage streams.
- **Visual Alert States**: Upgraded the active app status card to turn alarm red and flash "LIMIT REACHED" when the active monitored app crosses its daily limit.
- **Dynamic Digital Health Mapping**: Replaced the static Health mockup page with dynamic loading, automatically retrieving today's actual accumulated app usages and configured limits, rendering "No Limit" when not set.

### Breaking Changes
- None

## [2026-06-17] - Phase 2C.3: Usage Accuracy & Lifecycle Tracking

### Created Files
- None

### Modified Files
- [SayNoAccessibilityService.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoAccessibilityService.kt)
- [MainActivity.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/MainActivity.kt)
- [protection_platform_service.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/protection_platform_service.dart)
- [app_detection_controller.dart](file:///d:/sayno-main-phase-1/lib/features/protection/application/app_detection_controller.dart)
- [session_controller.dart](file:///d:/sayno-main-phase-1/lib/features/protection/application/session_controller.dart)
- [app_session.dart](file:///d:/sayno-main-phase-1/lib/features/protection/domain/app_session.dart)
- [session_database.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/session_database.dart)
- [pubspec.yaml](file:///d:/sayno-main-phase-1/pubspec.yaml)
- [session_controller_test.dart](file:///d:/sayno-main-phase-1/test/features/protection/application/session_controller_test.dart)
- [session_database_test.dart](file:///d:/sayno-main-phase-1/test/features/protection/data/session_database_test.dart)

### Major Features Added
- **Android Device State Listeners**: Implemented dynamic `BroadcastReceiver` in the accessibility service to capture `ACTION_SCREEN_OFF`, `ACTION_SCREEN_ON`, and `ACTION_USER_PRESENT` events, and propagate them as json events to Flutter.
- **Pessimistic Safe Startup Initialization**: Programmed `isScreenOn` and `isDeviceLocked` native-side helpers. On Flutter startup, we query actual Android values asynchronously before starting tracking, avoiding optimistic/assumed defaults.
- **Reactive State Providers**: Implemented `isScreenOnProvider`, `isDeviceUnlockedProvider`, and `isProtectionAvailableProvider` inside the application layer.
- **Instant Terminate and Save Rules**: Programmed `ActiveSessionNotifier` to watch these providers. If screen turns off, device locks, monitored app exits, or protection is disabled, the session is terminated and saved immediately.
- **Test Coverage & Zero-Spam Filtering**: Added test coverage for all lifecycle transition rules. Filtered out `< 1s` sessions from database writes to prevent rapid state spams.

### Breaking Changes
- None

## [2026-06-17] - Phase 2C.2: Usage Persistence & Daily Totals

### Created Files
- [session_database.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/session_database.dart)
- [session_repository.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/session_repository.dart)
- [session_database_test.dart](file:///d:/sayno-main-phase-1/test/features/protection/data/session_database_test.dart)

### Modified Files
- [pubspec.yaml](file:///d:/sayno-main-phase-1/pubspec.yaml)
- [session_controller.dart](file:///d:/sayno-main-phase-1/lib/features/protection/application/session_controller.dart)
- [dashboard_screen.dart](file:///d:/sayno-main-phase-1/lib/features/dashboard/presentation/dashboard_screen.dart)
- [session_controller_test.dart](file:///d:/sayno-main-phase-1/test/features/protection/application/session_controller_test.dart)

### Major Features Added
- **SQLite Database Persistence**: Added database layer using `sqflite` to save completed monitored app sessions.
- **Data Abstraction (Repository Pattern)**: Implemented `SessionRepository` to abstract raw SQLite table queries from the controller layer.
- **SQL Aggregate Queries**: Implemented aggregate queries (`SUM(duration_seconds)` and `GROUP BY package_name`) directly on SQLite to calculate today's total and per-app usage.
- **Reactive Riverpod Providers**: Added separated providers: `persistedTodayUsageProvider`, `activeSessionDurationProvider`, `todayTotalUsageProvider`, `persistedTodayAppUsageProvider`, and `todayAppUsageProvider` to dynamically stream totals in real-time.
- **Dashboard Progress Integration**: Bound the dashboard daily limit progress bar to show today's dynamic total usage instead of hardcoded numbers.

### Breaking Changes
- None

## [2026-06-17] - Phase 2C.1: Session Tracking Foundation

### Created Files
- [app_session.dart](file:///d:/sayno-main-phase-1/lib/features/protection/domain/app_session.dart)
- [session_controller.dart](file:///d:/sayno-main-phase-1/lib/features/protection/application/session_controller.dart)
- [session_controller_test.dart](file:///d:/sayno-main-phase-1/test/features/protection/application/session_controller_test.dart)

### Modified Files
- [dashboard_screen.dart](file:///d:/sayno-main-phase-1/lib/features/dashboard/presentation/dashboard_screen.dart)

### Major Features Added
- **Transient Session Tracking**: Added in-memory tracking of monitored app sessions using the `AppSession` model.
- **Active Session Duration**: Integrated a periodic timer that updates the duration of the current session every second and displays it dynamically on the dashboard active app card.
- **Cumulative Session Counter**: Added an in-memory counter that tracks and increments the total number of sessions started during the current app run, linked to the dashboard's "Sessions" tile.
- **Clock Mockability**: Added a mockable clock provider helper `getSystemTime` to ensure tests run accurately inside a virtualized time environment (`fakeAsync`).

### Breaking Changes
- None
