# Phase 4 — Sprint 3: Release Lifecycle

## 1. Sprint Objective
Implement the 24-hour deactivation cooldown pipeline (Release Request System) and track exit telemetry (Release Analytics). This sprint builds the local state machine that acts as the single gateway for disabling the settings warning shields, allowing deactivation and uninstallation only after the verified cooldown period has fully elapsed.

---

## 2. Scope

### Included:
* Local SQLite table persistence inside [SessionDatabase](file:///d:/sayno-main-phase-1/lib/features/protection/data/session_database.dart) to store release requests.
* Domain models and Riverpod controller architectures managing cooldown states and local countdown timers.
* MethodChannel endpoint syncing the release status (cooldown active vs. release authorized) down to native SharedPreferences.
* Settings screen UI elements providing a "Request Release" action, warning prompts, a running countdown clock, and a "Cancel Request" bypass.
* Preserving settings shield enforcement during the active cooldown, and automatically unlocking access once the countdown completes.
* Local event logging for analytics (Release Initiated, Cancelled, Completed).

### Explicitly Excluded:
* Cloud database synchronization to Firestore (Phase 5).
* Accountability partner invitation and confirmation layers (Phase 5).
* Remote OTP bypass codes (Phase 6).

---

## 3. Files To Create

### Flutter Files:
* **[release_request.dart](file:///d:/sayno-main-phase-1/lib/features/settings/domain/release_request.dart)**: Domain model containing request ID, request UTC timestamp, cooldown duration, and release status enums.
* **[release_repository.dart](file:///d:/sayno-main-phase-1/lib/features/settings/data/release_repository.dart)**: Interface specifying persistence operations for release requests.
* **[sqlite_release_repository.dart](file:///d:/sayno-main-phase-1/lib/features/settings/data/sqlite_release_repository.dart)**: SQLite implementation of `ReleaseRepository` retrieving and updating local release status.
* **[release_controller.dart](file:///d:/sayno-main-phase-1/lib/features/settings/application/release_controller.dart)**: Riverpod StateNotifier tracking the current release countdown, managing tick events, and validating clock integrity via Sprint 1 time services.
* **[release_cooldown_screen.dart](file:///d:/sayno-main-phase-1/lib/features/settings/presentation/release_cooldown_screen.dart)**: Full-screen UI containing a running countdown clock, explanations of active restrictions, and a prominent "Cancel Request" button.

---

## 4. Files To Modify

### Flutter Code:
* **[session_database.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/session_database.dart)**:
  * Increment DB version to `5`.
  * Add the `release_requests` schema creation within the configuration callback.
* **[protection_platform_service.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/protection_platform_service.dart)**:
  * Introduce MethodChannel invoker:
    ```dart
    Future<void> updateReleaseAuthorization(bool isAuthorized);
    ```
* **[app_router.dart](file:///d:/sayno-main-phase-1/lib/navigation/app_router.dart)**:
  * Register the route path `/release-cooldown` mapped to `ReleaseCooldownScreen`.
* **[settings_screen.dart](file:///d:/sayno-main-phase-1/lib/features/settings/presentation/settings_screen.dart)**:
  * Integrate the entry point for triggering a Release Request. Redirect to the countdown screen if a cooldown is active.

### Kotlin Code:
* **[MainActivity.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/MainActivity.kt)**:
  * Introduce MethodChannel handler endpoint `updateReleaseAuthorization` to update native flags inside SharedPreferences configurations.
* **[SayNoAccessibilityService.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoAccessibilityService.kt)**:
  * Check the native `isReleaseAuthorized` SharedPreferences flag before triggering settings lockouts. If authorized, skip intercepts.

---

## 5. Database Changes

### SQLite Table: `release_requests`
* Column: `id` (INTEGER, Primary Key, Auto-increment)
* Column: `requested_at_utc` (TEXT, Not Null): ISO-8601 UTC timestamp.
* Column: `cooldown_duration_seconds` (INTEGER, Not Null): Total cooldown window (e.g., 86400).
* Column: `status` (TEXT, Not Null): Cooldown state indicator (`cooldown`, `completed`, `canceled`).

### Database Migrations:
* Increment SQLite schema to version `5`.
* Implement incremental `onUpgrade` path from version `4` generating the `release_requests` table.

---

## 6. Native Android Changes

### MethodChannels:
* Endpoint: `updateReleaseAuthorization`
  * Arguments: `{'isAuthorized': Boolean}`
  * Logic: Persists the release authorization status inside SharedPreferences (`sayno_config`).

### Settings Lockout Integration:
* Update `SayNoAccessibilityService`:
  ```kotlin
  val isAuthorized = sharedPrefs.getBoolean("is_release_authorized", false)
  if (isAuthorized) {
      // Release cooldown finished: permit settings modification
      return
  }
  ```

---

## 7. Flutter Changes

### Riverpod Providers:
* `releaseRepositoryProvider`: Exposes repository instance.
* `releaseControllerProvider`: Exposes the countdown state machine.

### UI Screens:
* Add visual feedback tiles on `SettingsScreen` showing "Release Cooldown in Progress: HH:MM:SS remaining".
* Build `ReleaseCooldownScreen` with progress circle bars.

---

## 8. Acceptance Criteria
* **Release Cooldown Enforcement**: Initiating a release inserts a record in `release_requests` and transitions the app into a 24-hour countdown state. Settings screens remain protected.
* **Release Cancellation**: Clicking "Cancel Request" immediately updates the local database state to `canceled`, disables the timer, and re-engages settings warning overlays.
* **Release Expiration & Unlocking**: Once the countdown expires and is validated against NTP and monotonic baselines, the app invokes `updateReleaseAuthorization(true)`. The user is now permitted to modify accessibility permissions normally and uninstall the app.
* **Analytics Verification**: Triggers for Release Initiated, Cancelled, and Completed generate structured local log records.

---

## 9. Manual Testing Checklist

1. **Initiate Release Cooldown**:
   * Open Flutter app settings, tap "Request Release". Confirm warning prompt.
   * Verify redirect to `ReleaseCooldownScreen`. Confirm the countdown timer ticks down.
   * Open system settings -> try to disable accessibility for SayNO. Verify the settings lock remains fully active.
2. **Cancellation Path**:
   * On `ReleaseCooldownScreen`, tap "Cancel Request".
   * Verify redirect back to Settings.
   * Open system settings. Verify settings locks remain active (cooldown was cancelled).
3. **Expiration Path (Mocked Cooldown)**:
   * To test expiration without waiting 24 hours: temporarily configure a 1-minute mock cooldown duration.
   * Request a release. Wait 1 minute.
   * Once the countdown hits 00:00:00, verify the screen changes to "Release Authorized".
   * Open system settings -> disable Accessibility toggle. Verify the action succeeds without warning overlays or ejections.

---

## 10. Git Commit Plan

1. **`feat(database): define release_requests table and database version 5 migrations`**
   * Configures version upgrades in `session_database.dart`.
2. **`feat(settings): create release request models and repository layers`**
   * Builds the domain entity and SQLite storage handlers.
3. **`feat(settings): implement ReleaseController and MethodChannel notifications`**
   * Builds Riverpod countdown state controllers and connects `updateReleaseAuthorization` to native SharedPreferences.
4. **`feat(ui): implement ReleaseCooldownScreen and settings integrations`**
   * Configures visual screens, routes, and cancellation bindings.
5. **`feat(analytics): implement release events telemetry logging`**
   * Records tracking entries for release life states.
