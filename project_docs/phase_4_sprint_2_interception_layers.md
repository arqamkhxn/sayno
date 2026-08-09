# Phase 4 — Sprint 2: Interception Layers

## 1. Sprint Objective
Secure the application against manual system-settings deactivation. This sprint builds native settings-interception layers (Accessibility & App Info Shields) that render warning overlays and programmatic eject actions when a user attempts to disable accessibility permissions, force-stop, or uninstall SayNO during an active contract.

---

## 2. Scope

### Included:
* Intercepting window transitions matching the system Settings package (`com.android.settings`).
* Accessibility tree node scanning targeted at identifying critical buttons (Force Stop, Uninstall, and Service Toggles) using Android resource IDs.
* Rendering a full-screen, dismiss-resistant warning dialog window using [SayNoOverlayManager](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoOverlayManager.kt) when settings locks are breached.
* Programmatic global gestures (`GLOBAL_ACTION_BACK` or `GLOBAL_ACTION_HOME`) executing settings ejections via [SayNoInterventionManager](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoInterventionManager.kt).
* Intercepting settings checks strictly under the condition that an active Contract is running.

### Explicitly Excluded:
* Time drift NTP and monotonic clock validations (implemented in Sprint 1).
* SQLite release request cooldown state persistence (Sprint 3).
* Partner remote confirmations (Phase 5).

---

## 3. Files To Create
None. (This sprint extends and configures existing native accessibility components).

---

## 4. Files To Modify

### Kotlin Code:
* **[SayNoAccessibilityService.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoAccessibilityService.kt)**:
  * Update `onAccessibilityEvent` to listen for window changes from the package `com.android.settings`.
  * Trigger native layout hierarchy scans when settings windows are active.
* **[SayNoInterventionManager.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoInterventionManager.kt)**:
  * Introduce `startSettingsLockoutIntervention(packageName: String, reason: String)` to coordinate warning overlay displays and programmatic ejections.
* **[MainActivity.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/MainActivity.kt)**:
  * Add MethodChannel handler endpoint `updateActiveContractStatus` to update config flags inside `SayNoConfigManager`.

### Flutter Code:
* **[protection_platform_service.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/protection_platform_service.dart)**:
  * Add MethodChannel invoker:
    ```dart
    Future<void> updateActiveContractStatus(bool isActive);
    ```
* **[contract_controller.dart](file:///d:/sayno-main-phase-1/lib/features/contract/application/contract_controller.dart)**:
  * Update contract start, completion, and failure lifecycle paths to invoke `updateActiveContractStatus` automatically.

---

## 5. Database Changes
None.

---

## 6. Native Android Changes

### Layout Node Scanning:
* Search the node tree for specific target Android resource identifier strings:
  * Force Stop Button: `com.android.settings:id/force_stop_button`
  * Uninstall Button: `com.android.settings:id/uninstall_button` (or `com.google.android.packageinstaller:id/ok_button` for installers)
  * Accessibility Toggle Widget: `com.android.settings:id/switch_widget` or class name `android.widget.Switch` inside accessibility settings folders.
* Perform structural fallback sweeps when matching resource IDs are obfuscated or missing. Localized text label scanning ("Force Stop", "Uninstall") serves strictly as a secondary fallback.

### Window Overlay configurations:
* Layout parameters in [SayNoOverlayManager](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoOverlayManager.kt) configured with window type `WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY`.
* Setup overlays to intercept back gestures and touch events, forcing ejections if the user attempts settings adjustments.

### MethodChannels:
* Endpoint: `updateActiveContractStatus`
  * Arguments: `{'isActive': Boolean}`
  * Logic: Sets a flag in SharedPreferences config indicating whether settings bypass protection must be actively enforced.

---

## 7. Flutter Changes

### Controllers:
* Modify [ContractController](file:///d:/sayno-main-phase-1/lib/features/contract/application/contract_controller.dart) to sync contract status down to native Kotlin when contracts change state.

---

## 8. Acceptance Criteria
* **Locked Settings Protection**: Tapping the "Accessibility" toggle for SayNO or navigation to "App Info" for SayNO while a contract is active is immediately blocked by the warning dialog, followed by a programmatic back out of settings.
* **Localization Compliance**: Settings bypasses remain secure even if the device's system language is modified (e.g. Spanish, German) due to Resource ID parsing overrides.
* **Permitted Access (Contract Terminated)**: Disabling accessibility permissions or uninstalling the app is allowed normally when no contracts are running.

---

## 9. Manual Testing Checklist

1. **Accessibility Shield Test (Active Contract)**:
   * Activate a mock contract in Flutter settings.
   * Open Android System Settings -> Accessibility -> Downloaded Services -> SayNO.
   * Verify the "Protection Active" overlay renders. Tap the toggle -> verify programmatic back-out occurs immediately.
2. **App Info Shield Test (Active Contract)**:
   * Navigate to Android Settings -> Apps -> SayNO.
   * Verify warning overlay is drawn. Try clicking "Force Stop" or "Uninstall" -> verify programmatic ejection occurs instantly.
3. **Localization Bypasses Test**:
   * Change the phone's system language to Spanish.
   * Try accessing SayNO Settings / App Info screens. Verify the layout blocks still occur via resource IDs.
4. **Permitted Configuration Access**:
   * Delete or complete the active contract in the Flutter app.
   * Open Android Settings -> Apps -> SayNO.
   * Click "Force Stop" / toggle off Accessibility. Verify these actions succeed normally without block overlays.

---

## 10. Git Commit Plan

1. **`feat(flutter): sync active contract state to native SharedPreferences`**
   * Implements the `updateActiveContractStatus` bridge in Flutter controllers and MainActivity.kt.
2. **`feat(native): implement layout-node scanning using native Resource IDs`**
   * Incorporates resource ID queries inside `SayNoAccessibilityService` for Settings and App Info target buttons.
3. **`feat(native): build warning overlays and settings ejection gestures`**
   * Configures warning overlays and programmatically sends BACK/HOME commands via intervention managers.
