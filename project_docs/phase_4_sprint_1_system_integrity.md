# Phase 4 — Sprint 1: System Integrity

## 1. Sprint Objective
Establish the foundational system-level protection mechanisms for SayNO. This sprint secures the app against clock manipulation (Time Drift Shield) and ensures that protection configurations are restored instantly whenever the device restarts (Boot Recovery).

---

## 2. Scope

### Included:
* Periodic Kotlin-side background loop to capture monotonic uptime (`SystemClock.elapsedRealtime()`) and map it to wall-clock time in SharedPreferences.
* Android `BroadcastReceiver` listening to boot events (`BOOT_COMPLETED` and `LOCKED_BOOT_COMPLETED` for Direct Boot compatibility).
* Calculating continuous monotonic uptime offsets across power cycles to prevent reboot-induced false manipulation locks.
* Flutter client implementation querying NTP servers periodically and on app launch.
* MethodChannel bridge to propagate the verified NTP timestamp down to native Kotlin memory.
* High-severity native time manipulation detection blocking restricted apps if wall-clock travel is identified.

### Explicitly Excluded:
* UI Overlays for Settings blocks (Accessibility/App Info shields) (Sprint 2).
* Release Request state machine SQLite persistence and 24-hour cooldown logic (Sprint 3).
* Cloud database synchronization with Firebase (Phase 5).

---

## 3. Files To Create

### Kotlin Files:
* **[BootReceiver.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/BootReceiver.kt)**: Native broadcast receiver that wakes up on boot events to query config managers and verify service initialization status.

### Flutter Files:
* **[time_verification_service.dart](file:///d:/sayno-main-phase-1/lib/features/protection/application/time_verification_service.dart)**: Riverpod service querying a public NTP pool (e.g., `pool.ntp.org`) or using standard HTTP time APIs, caching the delta, and syncing it to the platform bridge.

---

## 4. Files To Modify

### Android Configuration:
* **[AndroidManifest.xml](file:///d:/sayno-main-phase-1/android/app/src/main/AndroidManifest.xml)**: Register the boot receiver and request permissions:
  * `android.permission.RECEIVE_BOOT_COMPLETED`

### Kotlin Code:
* **[MainActivity.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/MainActivity.kt)**: Add the MethodChannel handler endpoint `updateVerifiedTime` to receive network-verified time baselines from Flutter.
* **[SayNoLimitManager.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoLimitManager.kt)**:
  * Add a background `Handler` loop (running every 10 seconds while tracking is active) to persist `SystemClock.elapsedRealtime()` and current time to `SharedPreferences`.
  * Incorporate drift logic matching the offset differences.
* **[SayNoConfigManager.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoConfigManager.kt)**:
  * Expose shared preference helper getters/setters for monotonic offsets.

### Flutter Code:
* **[protection_platform_service.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/protection_platform_service.dart)**: Expose method channel interface:
  ```dart
  Future<void> updateVerifiedTime(int epochSeconds);
  ```
* **[main.dart](file:///d:/sayno-main-phase-1/lib/main.dart)**: Trigger an initial `TimeVerificationService` NTP sync within `main()` before launching the main app widget.

---

## 5. Database Changes
None. (Local SQLite tables are deferred to Sprint 3).

---

## 6. Native Android Changes

### Receivers:
* `BootReceiver` registered to capture:
  * `android.intent.action.BOOT_COMPLETED`
  * `android.intent.action.QUICKBOOT_POWERON`
  * `android.intent.action.LOCKED_BOOT_COMPLETED`

### SharedPreferences (`sayno_monotonic_offset`):
* Key: `accumulated_monotonic_time` (Long): Cumulative hardware uptime duration across all reboot lifecycles.
* Key: `last_wall_clock_timestamp` (Long): Wall clock timestamp written on last checkpoint.
* Key: `monotonic_offset_base` (Long): Dynamic baseline used to calculate running offset.

### MethodChannels (`sayno/protection`):
* Endpoint: `updateVerifiedTime`
  * Arguments: `{'epochSeconds': Int}`
  * Logic: Sets verified NTP base offset in memory inside native environment.

---

## 7. Flutter Changes

### Riverpod Providers:
* `timeVerificationServiceProvider`: Exposes `TimeVerificationService` instance.

### App Initializer:
* Update `main.dart` to wait on `timeVerificationServiceProvider.notifier.syncTime()` before executing `runApp()`.

---

## 8. Acceptance Criteria
* **Reboot Survival**: Power cycling a device starts the `BootReceiver` and re-initializes configuration constraints instantly.
* **Monotonic Reboot Offset Integrity**: Rebooting the device does NOT reset the offset calculations or trigger false clock manipulation locks.
* **Clock Rollback Block**: Changing the manual system clock backward by >30 seconds when offline compared to the monotonic offset immediately registers clock manipulation.
* **NTP Drift Correction**: Connecting to network validates drift and aligns system offsets correctly.

---

## 9. Manual Testing Checklist

1. **Reboot Verification**:
   * Open monitored app, verify tracking starts.
   * Restart device.
   * After boot completes, check if service configuration is restored automatically. Verify no time manipulation alarm is raised.
2. **Clock Rollback (Offline)**:
   * Turn off Wi-Fi/Mobile Data on a physical device.
   * Manually roll system clock back by 5 minutes.
   * Open the app. Verify that the time manipulation block overlay is triggered immediately.
3. **Clock Fast-Forward (Offline)**:
   * Turn off Wi-Fi/Mobile data.
   * Roll system clock forward by 2 hours.
   * Open the app. Verify that the time manipulation block overlay is triggered immediately.
4. **Online Recovery**:
   * Turn Wi-Fi/Mobile data back on.
   * Re-open the app. Verify that NTP sync executes, verified time delta reconciles, and normal tracking resumes.

---

## 10. Git Commit Plan

1. **`feat(native): register BootReceiver and request boot completed permissions`**
   * Configures permissions in `AndroidManifest.xml` and implements basic logging `BootReceiver.kt`.
2. **`feat(native): implement Kotlin-side monotonic offset persistence across reboots`**
   * Implements SharedPreferences logging inside `SayNoLimitManager.kt` and offset recovery logic.
3. **`feat(flutter): introduce TimeVerificationService and NTP sync MethodChannel`**
   * Implements NTP queries on Flutter, updates `MainActivity.kt` and `protection_platform_service.dart`.
4. **`feat(native): implement Time Drift manipulation check and lock constraints`**
   * Connects the reconstructed monotonic offset comparisons inside native limit check loops.
