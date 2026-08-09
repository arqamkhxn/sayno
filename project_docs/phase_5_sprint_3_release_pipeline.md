# Phase 5 — Sprint 3: Release Pipeline

## 1. Sprint Objective
Transition deactivation logic to a human-gated pipeline requiring a 24-hour Cooldown, Firestore-based Partner Approval, and a 24-hour Grace Window. Enforce hardware monotonic clocks and validated online NTP integrity checks before any transition.

---

## 2. Scope

### Included:
* Local SQLite table migration adding columns for partner approvals and grace window expirations.
* Firestore `/release_requests` document structures and security validation rules.
* Multi-device workflow branching:
  - **No Partner**: Falls back to local 24h Cooldown -> Deactivation.
  - **Partner Linked**: Enforces 24h Cooldown -> Partner Approval in Firestore -> 24h Grace Window -> Deactivation.
* Firestore real-time listener subscription: `ReleaseController` subscribes to the active release document to capture partner approval state.
* Monotonic offline safety: Cooldown and Grace Window clocks count down via the boot-safe monotonic offset established in **Phase 4**.
* Online-gated transitions: Cooldown completion, Partner Approval transition, and Final Release Authorization require active network, NTP drift check (<30s skew), and hardware integrity validation.
* Explanatory block screen displayed to the user if any integrity validation checks fail.

### Explicitly Excluded:
* FCM push notifications and bypass alerts to the partner's screen (Sprint 4).

---

## 3. Files To Create

### Flutter Files:
* **[verification_error_screen.dart](file:///d:/sayno-main-phase-1/lib/features/settings/presentation/verification_error_screen.dart)**: Screen displaying details when online NTP checks or time integrity delta checks fail during deactivation transitions.

---

## 4. Files To Modify

### Flutter Code:
* **[session_database.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/session_database.dart)**:
  - Increment DB version to `7`.
  - Add SQLite migrations altering the `release_requests` table.
* **[release_request.dart](file:///d:/sayno-main-phase-1/lib/features/settings/domain/release_request.dart)**:
  - Add fields `partnerApprovedAtUtc` (DateTime?) and `graceWindowExpiresAtUtc` (DateTime?).
  - Update mapping methods (`fromMap`, `toMap`, `copyWith`).
* **[sqlite_release_repository.dart](file:///d:/sayno-main-phase-1/lib/features/settings/data/sqlite_release_repository.dart)**:
  - Update SQL parameters mapping the new UTC columns.
* **[release_controller.dart](file:///d:/sayno-main-phase-1/lib/features/settings/application/release_controller.dart)**:
  - Implement conditional partner branching and Firestore listeners.
  - Implement transition guards checking network and NTP offsets.
  - Write telemetry logs for `Release Initiated`, `Release Approved`, `Grace Window Started`, `Release Cancelled`, and `Release Completed`.
* **[release_cooldown_screen.dart](file:///d:/sayno-main-phase-1/lib/features/settings/presentation/release_cooldown_screen.dart)**:
  - Update to show "Pending Partner Approval" state after cooldown.
  - Display "Grace Window Active" circular timer and cancellation buttons during the 24-hour grace phase.

---

## 5. Database Changes

### SQLite Table: `release_requests` (Updates)
* Add Column: `partner_approved_at_utc` (TEXT, Nullable)
* Add Column: `grace_window_expires_at_utc` (TEXT, Nullable)

### Database Migrations:
* Increment SQLite schema version to `7`.
* Implement `onUpgrade` path:
  ```sql
  ALTER TABLE release_requests ADD COLUMN partner_approved_at_utc TEXT;
  ALTER TABLE release_requests ADD COLUMN grace_window_expires_at_utc TEXT;
  ```

---

## 6. Firebase Changes

### Firestore Collections:
* `/release_requests/{requestId}`:
  - Document fields: `userId` (String), `requestedAtUtc` (String), `cooldownDurationSeconds` (Int), `partnerApprovedAtUtc` (String?), `graceWindowExpiresAtUtc` (String?), `status` (String: `cooldown`, `pending_approval`, `grace_window`, `completed`, `canceled`).

### Firestore Security Rules:
* User can create `/release_requests` documents only if authenticated and `userId` matches UID.
* User can update document only to write status = `canceled`.
* Partner can update document only to write `partnerApprovedAtUtc` and update status to `grace_window` (verified against matching email).

---

## 7. Flutter Changes

### Verification Services:
* Update `TimeVerificationService` to throw structured exceptions (`NoNetworkException`, `TimeDriftException`, `IntegrityCompromisedException`).

---

## 8. Native Android Changes
None.

---

## 9. Acceptance Criteria
* **Approval Lockdown**: Cooldown completion transitions state to `pending_approval` in Firestore. settings warning overlays remain active.
* **Grace Window Cancellation**: Partner clicking Approve transitions state to `grace_window`. User has 24 hours to cancel. Cancellation resets status to `canceled` in Firestore and re-locks settings instantly.
* **Integrity Gates**: Deactivating internet or manipulating manual device clocks to bypass the timer triggers the `VerificationErrorScreen` and halts the release authorization.

---

## 10. Manual Testing Checklist

1. **Monotonic Verification (Offline)**:
   - Initiate a mock 1-minute cooldown. Disconnect internet.
   - Wait 1 minute. Verify transition to Partner Approval is blocked, displaying "Network Connection Required".
   - Turn internet on. Verify the app completes transition to `pending_approval`.
2. **Partner Approval & Grace Window**:
   - Approve the request using the partner device.
   - Verify the user device displays "Grace Window Active: 24:00:00 remaining".
   - Go to System Settings -> verify accessibility service remains locked.
3. **Grace Window Expiration (Unlock)**:
   - Wait for mock Grace Window (1 minute) to expire.
   - Verify success screen appears and accessibility shields are deactivated.
4. **Cancellation Flow**:
   - Start Grace Window. Tap "Cancel Request".
   - Verify status transitions to `canceled` and shields re-lock immediately.

---

## 11. Git Commit Plan

1. **`feat(database): alter release_requests table and migrate SQLite to version 7`**
   - Implements SQL schemas and migration paths.
2. **`feat(settings): update ReleaseRequest entity and SQLite mappings`**
   - Incorporates partner columns in models.
3. **`feat(settings): implement multi-step ReleaseController state machine and Firestore listeners`**
   - Integrates Firestore document updates and status branching.
4. **`feat(verification): implement TimeVerificationService integrity gates`**
   - Integrates network, NTP, and monotonic validation logic.
5. **`feat(ui): update ReleaseCooldownScreen and design VerificationErrorScreen`**
   - Connects user flows, clocks, and error prompts.
