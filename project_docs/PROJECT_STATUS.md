# PROJECT STATUS — SAYNO
 
## Current Phase
- **Phase 2 — Silent Guardian (Native Protection & Usage Sync)** (Completed)
 
## Next Target
- **Phase 3 — Contract Engine / Streak Engine**

## Completed Sprints (Phase 2)
- **Sprint 1**: Config Manager
- **Sprint 2**: Native Overlay Manager
- **Sprint 3**: Native Intervention Engine
- **Sprint 4A**: Native Usage Tracking
- **Sprint 4A.1**: Limit Testing UI
- **Sprint 4B**: Midnight Reset & Native Usage Sync
- **Sprint 5A**: Validation Execution
- **Sprint 5B**: Critical & High Severity Bug Fixes
- **Sprint 5C**: Cleanup & Production Preparation
- **Sprint 5D**: Documentation & Closure

## Remaining Known Issues & Risks
1. **Multi-day History Sync**: SQLite continues saving completed sessions on Flutter, but retrieving and aggregating statistics across multiple days is not yet wired to the dashboard.
2. **Active Session Loss on Crash/Hard Kill**: Real-time session duration is tracked in Kotlin memory and written to SharedPreferences on app swap or screen off. An abrupt system reboot or hard service crash would lose the active session's seconds.
3. **Reddit Custom Layout Traverse Intermittency**: The Reddit native app uses highly optimized custom UI layouts (such as custom recycler views). Standard accessibility node tree inspection is not always able to extract text from these components, leading to intermittent keyword detection.
4. **UI Leakage Window on Overlay Dismissal**: The overlay "Close" button removes the native overlay layout before the asynchronous Android HOME/BACK gesture finishes. This creates a brief 50ms-150ms window where the restricted application's content is visible.

## Completed Phases
- **Phase 2E: Intervention Engine**
  - Centralized intervention control via `InterventionNotifier` reacting to keyword scan hits and daily limit reached events.
  - Implemented Android Accessibility service gestures: `performBack()` and `performHome()`.
  - Added support for forcing a native scan of the active window via `triggerRescan()`.
  - Created Riverpod providers for `interventionInProgress`, `interventionReason`, and `interventionAttemptCount`.
  - Enforced safety rules: single intervention execution, state resets on package transitions only when not in progress.
  - Integrated overlay buttons to execute native back/home actions responsively after closing the overlay.
- **Phase 2F: Block Overlay Foundation**
  - Reusable block reason model (`BlockReason`) supporting restricted content and daily limit reached blocks.
  - Riverpod `blockOverlayProvider` and convenient visibility/reason selector providers.
  - Custom full-screen block overlay UI (`BlockOverlay`) with premium minimal styling, safety overlays, and separate callbacks for "Go Back" and "Close" actions.
  - Root widget stack integration in `lib/app.dart` to overlay the block screen over all pages and navigation elements.
  - Visual developer-only test options in the Settings screen labeled clearly under temporary developer tooling.
- **Phase 1: Foundation & UI System**
  - Design system with dark theme and custom widgets.
  - Basic navigation using GoRouter.
  - Dashboard UI mockup.
- **Phase 2A: Accessibility Foundation**
  - Android Accessibility Service initialization.
  - Basic communication interface via MethodChannel.
- **Phase 2B: Foreground App Detection**
  - Registry of monitored applications.
  - Detection of monitored foreground apps.
  - Dashboard integration for displaying the active monitored app.
- **Phase 2C.1: Session Tracking Foundation**
  - In-memory session model (`AppSession`).
  - Detection of session start, end, and duration tracking.
  - Dashboard integration showing live session timers and cumulative session count.
- **Phase 2C.2: Usage Persistence & Daily Totals**
  - Relational persistence of completed sessions locally using SQLite (`sqflite`).
  - Aggregation logic using SQL aggregate queries (`SUM` and `GROUP BY`).
  - Data mapping abstraction using the Repository pattern (`SessionRepository` -> `SessionDatabase`).
  - Separate Riverpod providers for `persistedTodayUsageProvider`, `activeSessionDurationProvider`, and `todayTotalUsageProvider`.
  - Bound the dashboard daily limit card to the dynamic total usage.
- **Phase 2C.3: Usage Accuracy & Lifecycle Tracking**
  - Broadcaster for screen off/on and keyguard lock/unlock states from Android Accessibility Service.
  - Reactive state providers (`isScreenOnProvider`, `isDeviceUnlockedProvider`, and `isProtectionAvailableProvider`).
  - Accurate usage logic ensuring sessions run only when the monitored app is active, screen is on, device is unlocked, and protection is available.
  - Instant session termination and database persistence on lifecycle transitions (screen off, device lock, app backgrounding, protection service disabled).
  - Pessimistic, safe startup verification querying device states from Android before tracking.
- **Phase 2G: Daily Limit Enforcement**
  - Local persistence of app limits inside a new SQLite table `app_limits`.
  - Incremented database schema version to `2` with robust migration queries (`onUpgrade`) preventing data loss.
  - Reactive daily limits async state provider (`appLimitsProvider`) with database CRUD mutations.
  - Real-time limit-reached maps (`isLimitReachedMapProvider` and `isActiveAppLimitReachedProvider`) updating instantly.
  - Visual alert states on active app status card and dynamic data mapping on digital health screen displaying configured limits or "No Limit".
- **Phase 2D.1: Keyword Detection Foundation**
  - Native-side text extraction via recursive `AccessibilityNodeInfo` tree traversal on a curated whitelist of high-risk applications (browsers + messaging).
  - On-device keyword matching using a configurable registry (`keyword_registry.dart`) — no raw text ever sent across the Flutter platform bridge.
  - Debounced scanning (500ms `Handler`) triggered on `TYPE_WINDOW_CONTENT_CHANGED` and `TYPE_WINDOW_STATE_CHANGED` events to prevent battery drain.
  - Structured detection results (`restrictedContentDetected`, `matchedKeywords`, `timestamp`, `packageName`) dispatched to Flutter via the existing `MethodChannel`.
  - Ephemeral `KeywordScanState` domain model with automatic state reset when the user leaves a high-risk application.
  - Riverpod `keywordScanProvider` with convenience selectors: `restrictedContentDetectedProvider`, `matchedKeywordsProvider`, `lastScanTimestampProvider`, `scannedTextAvailableProvider`.
  - New platform channel calls: `updateHighRiskApps` and `updateKeywords` for initialization from Flutter on startup.

## Implemented Features List
- **UI System**: Premium minimalist dark theme dashboard, cards, chips, scaffolds, custom nav bar, stat tiles.
- **Accessibility Service**: Integration with Android's system settings and event listener setup.
- **App Detection**: Foreground monitored app package mapping and native-to-Flutter notification stream.
- **Session Tracking & Persistence**: Dynamic in-memory `AppSession` model, database saving on session termination, SQL aggregate queries for today's overall and per-app usage, and dashboard progress bar integration.
