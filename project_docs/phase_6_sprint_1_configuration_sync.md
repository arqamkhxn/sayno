# Phase 6 — Sprint 1: Configuration Sync

## 1. Goal
Establish the database schema, domain models, and platform bridge mapping for the four restriction modes (Utility, Time Limit, Focus, Monk) and sync these configurations securely with Firestore.

---

## 2. Scope

### Included:
* Adding the `restriction_mode` column (TEXT, defaulting to `'time_limit'`) to the local `contract_apps` table.
* Upgrading local SQLite database version to `9`.
* Defining the `RestrictionMode` enum in Flutter (`utility`, `time_limit`, `focus`, `monk`) with safe parsing fallbacks.
* Modifying the SQLite repository to map and preserve the active mode.
* Synchronizing the restriction mode to Firestore under `/users/{userId}/contracts/{contractId}/apps/{packageName}`.
* Rehydrating the local database from Firestore with safe fallback mapping.
* Updating the platform bridge MethodChannel (`setAppLimit`) to send the restriction mode downstream.
* Updating the native Kotlin `SayNoConfigManager` to save/retrieve `mode_packageName` configurations.

### Explicitly Excluded:
* Building overlay layouts and viewport window elements (Sprint 2).
* Accessibility event layout tree parsing and focus checks (Sprint 3).
* Mode enforcement or user ejection gestures (Sprint 4).

---

## 3. Files To Create
None.

---

## 4. Files To Modify

### Flutter Code:
* **[session_database.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/session_database.dart)**:
  - Increment DB version to `9`.
  - Add `restriction_mode TEXT DEFAULT 'time_limit'` column definition to `onCreate` and `onUpgrade` migrations.
* **[sqlite_contract_repository.dart](file:///d:/sayno-main-phase-1/lib/features/contract/data/sqlite_contract_repository.dart)**:
  - Read `restriction_mode` column in `_mapToContractApp` using safe parsing fallback.
  - Insert `'restriction_mode': app.restrictionMode.name` in `createContract` and `rehydrateContract`.
* **[contract_app.dart](file:///d:/sayno-main-phase-1/lib/features/contract/domain/contract_app.dart)**:
  - Add `RestrictionMode` enum.
  - Add `restrictionMode` property and static `parse()` parser fallback.
* **[protection_platform_service.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/protection_platform_service.dart)**:
  - Update `setAppLimit` to accept `restrictionMode` and pass it in MethodChannel arguments.
* **[cloud_sync_service.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/cloud_sync_service.dart)**:
  - Sync `restrictionMode` to Firestore contracts app collections and parse it on download rehydration.

### Kotlin Code:
* **[MainActivity.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/MainActivity.kt)**:
  - Parse the `restrictionMode` argument inside `"setAppLimit"` MethodChannel call.
* **[SayNoConfigManager.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoConfigManager.kt)**:
  - Store and retrieve the restriction mode string alongside the app limit using `mode_` prefix key in `SharedPreferences`.
  - Remove mode keys on `removeAppLimit`.

---

## 5. Database Changes

### SQLite Table: `contract_apps`
* Add Column: `restriction_mode` (TEXT, Not Null, default `'time_limit'`).

### Database Migrations:
* Increment SQLite schema version to `9`.
* Implement incremental migration check to alter the `contract_apps` table to add `restriction_mode` if `oldVersion < 9`.

---

## 6. Flutter Changes
* Define `RestrictionMode` enum in snake_case: `utility`, `time_limit`, `focus`, `monk`.
* Implement parsing routine:
  ```dart
  static RestrictionMode parse(String? value) {
    return RestrictionMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RestrictionMode.time_limit,
    );
  }
  ```

---

## 7. Native Android Changes
* Extend SharedPreferences schema inside `SayNoConfigManager.kt` to persist modes under `mode_packageName`.
* Implement `getRestrictionMode(packageName: String): String`.

---

## 8. Acceptance Criteria
* **Migration Safety**: Upgrading database from v8 to v9 runs successfully without data loss.
* **Backward Compatibility**: Existing contract apps have their restriction mode set to `time_limit`.
* **Sync Integrity**: Setting an app limit on Flutter updates both the limit seconds and the restriction mode string on the native side.
* **Rehydration Fallback**: Firestore files containing null or invalid restriction modes default to `time_limit` safely.

---

## 9. Automated Tests
* Create/update database tests in `test/features/protection/data/limit_repository_test.dart` or `session_database_test.dart` to check migration runs correctly.
* Create unit tests in `test/features/settings/application/cloud_sync_test.dart` confirming that parsing fallbacks function properly.

---

## 10. Manual Testing Checklist
1. **Migration Check**:
   - Run the app on emulator/device. Confirm database initializes successfully.
2. **Settings Registry Verification**:
   - Save an app limit.
   - Access the native SharedPreferences values inside Android File Explorer or via debug log dumps. Verify that the matching keys `limit_com.instagram.android` and `mode_com.instagram.android` are written.

---

## 11. Git Commit Plan
1. **`feat(db): upgrade SQLite schema to version 9 and alter contract_apps`**
2. **`feat(domain): define RestrictionMode enum and safe parsing logic`**
3. **`feat(platform): update platform bridge MethodChannel to sync restriction modes`**
4. **`feat(sync): add cloud sync support and rehydration fallback for restriction modes`**
