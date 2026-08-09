# Phase 5 — Sprint 2: Cloud Sync

## 1. Sprint Objective
Secure SayNO from local data tampering (such as uninstallation or clearing app storage) by syncing active contracts to Firestore and executing pessimistic rehydration loops on startup.

---

## 2. Scope

### Included:
* Syncing active contracts, contract apps, and daily progress checklists to Firestore `/users/{userId}/contracts`.
* Bidirectional synchronization routines: whenever a contract is created, completed, or a daily checklist updates, the change is written immediately to Firestore.
* Pessimistic rehydration: upon app bootstrap/login, query Firestore to verify if an active contract exists.
* State recovery: if Firestore contains an active contract but the local database is empty (due to storage clear or reinstallation), download the schema, rehydrate SQLite tables, and invoke native shields.
* Offline resilience: fallback to local database constraints if network is unavailable during launch.

### Explicitly Excluded:
* Human-gated Release Cooldown multi-step pipeline (Sprint 3).
* Push notifications and FCM alerts (Sprint 4).

---

## 3. Files To Create

### Flutter Files:
* **[cloud_sync_service.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/cloud_sync_service.dart)**: Riverpod service managing the synchronization of local SQLite contracts, apps, and days to Firestore.

---

## 4. Files To Modify

### Flutter Code:
* **[contract_controller.dart](file:///d:/sayno-main-phase-1/lib/features/contract/application/contract_controller.dart)**:
  - Trigger `CloudSyncService.syncContract()` on contract creation and completion.
  - Trigger sync on daily credit/streak checkins.
* **[protection_controller.dart](file:///d:/sayno-main-phase-1/lib/features/protection/application/protection_controller.dart)**:
  - Check active contract status during initialization. If a user is authenticated, consult `CloudSyncService` to query Firestore before resolving protection status.
* **[main.dart](file:///d:/sayno-main-phase-1/lib/main.dart)**:
  - Integrate auth state listener executing rehydration routines on user logins.

---

## 5. Database Changes
None. (SQLite schemas remain unchanged).

---

## 6. Firebase Changes

### Firestore Collections:
* `/users/{userId}/contracts`:
  - Document fields: `durationDays` (Int), `startTimestampUtc` (String), `endTimestampUtc` (String), `completedAtUtc` (String?), `status` (String), `longestStreak` (Int), `currentStreak` (Int).
  - Subcollection `/users/{userId}/contracts/{contractId}/apps`:
    - Document fields: `packageName` (String), `dailyLimitSeconds` (Int), `totalCreditsSeconds` (Int), `remainingCreditsSeconds` (Int).
  - Subcollection `/users/{userId}/contracts/{contractId}/days`:
    - Document fields: `dateUtc` (String), `status` (String), `creditsDeducted` (Int).

### Firestore Security Rules:
* Restrict reads and writes under `/users/{userId}/contracts` (and its subcollections) to users authenticated with a UID matching the path's `{userId}`.

---

## 7. Flutter Changes

### Riverpod Providers:
* `cloudSyncServiceProvider`: Exposes `CloudSyncService` instance.

### State Controller Sync:
* Update `ContractController` and `ProtectionController` to depend on `cloudSyncServiceProvider`.

---

## 8. Native Android Changes
None. (Relies on the MethodChannel `updateActiveContractStatus` invoke chain updated in Sprint 1).

---

## 9. Acceptance Criteria
* **Cloud Persistence**: Creating a contract inserts corresponding documents and subcollections in Firestore.
* **Re-activation Lockout**: Clearing local app storage and logging back in successfully downloads the active contract, inserts it back into local SQLite tables, and activates native settings warning overlays.
* **Offline Cache Defaults**: Launching the app offline re-engages locks based on the local SQLite cache without waiting for Firestore queries.

---

## 10. Manual Testing Checklist

1. **Verify Contract Upload**:
   - Create a 7-day contract with monitored apps.
   - Verify Firestore database shows the contract document and its associated `/apps` and `/days` subcollections populated correctly.
2. **Uninstall / Storage Tampering Test**:
   - Go to System Settings -> Apps -> SayNO -> storage -> Clear Data.
   - Re-open SayNO. Log back in with the same email.
   - **Expected Result**: The app shows a brief loading screen, detects the active contract in Firestore, restores local SQLite tables, and triggers native accessibility locks immediately.
3. **Offline Launch**:
   - Disconnect internet, close the app, and re-open it.
   - **Expected Result**: Accessibility shields remain active using the cached SQLite contract status.

---

## 11. Git Commit Plan

1. **`feat(firestore): set up Firestore subcollections and security rules for contracts`**
   - Configures database pathways and read/write security gates.
2. **`feat(sync): implement CloudSyncService for bidirectional contract sync`**
   - Implements Firestore database uploads and SQLite rehydration routines.
3. **`feat(contract): trigger sync on creation, checkins, and completion`**
   - Integrates `CloudSyncService` into `ContractController.dart`.
4. **`feat(protection): enforce pessimistic rehydration locks on app bootstrap`**
   - Integrates startup re-activation checks in `main.dart` / `ProtectionController`.
