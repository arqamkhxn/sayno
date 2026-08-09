# Phase 5 — Sprint 4: Push Interventions

## 1. Sprint Objective
Integrate Firebase Cloud Messaging (FCM) to transmit real-time alerts to the accountability partner's device whenever settings warning shields are triggered, and dispatch push alerts on release request milestone updates.

---

## 2. Scope

### Included:
* Firebase Cloud Messaging (FCM) integration on both Flutter and Android Native environments.
* Storing device FCM push tokens under `/users/{userId}/tokens` in Firestore.
* Listening to background/foreground push notifications and displaying them via `flutter_local_notifications`.
* Native Android triggers: whenever [SayNoAccessibilityService](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoAccessibilityService.kt) or [SayNoInterventionManager](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoInterventionManager.kt) executes an ejection or clock manipulation warning, dispatch a structured platform channel payload.
* Cloud functions or client-side dispatch handlers notifying the partner instantly when the user attempts a settings bypass.
* Dispatching push notifications to the partner on release milestones:
  - Release Request Initiated.
  - Release Request Canceled by User.
  - Release Request Pending Partner Approval.
  - Grace Window Active (Approved by Partner).

### Explicitly Excluded:
* Local SQLite migrations (completed in Sprint 3).
* Time integrity validation logic (completed in Sprint 3).

---

## 3. Files To Create

### Flutter Files:
* **[notification_service.dart](file:///d:/sayno-main-phase-1/lib/features/protection/application/notification_service.dart)**: Riverpod service managing FCM token retrieval, registrations, and foreground/background message processing.

---

## 4. Files To Modify

### Flutter Code:
* **[main.dart](file:///d:/sayno-main-phase-1/lib/main.dart)**:
  - Initialize Firebase Cloud Messaging handlers during bootstrap.
* **[protection_platform_service.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/protection_platform_service.dart)**:
  - Register callbacks for native bypass scan notifications or clock manipulation triggers.

### Kotlin Code:
* **[MainActivity.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/MainActivity.kt)**:
  - Expose MethodChannel handlers for alerts routing.
* **[SayNoAccessibilityService.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoAccessibilityService.kt)**:
  - Trigger warning channel messages to Flutter when clock drift is flagged or settings bypass scans match `"sayno"`.
* **[SayNoInterventionManager.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoInterventionManager.kt)**:
  - Trigger warning channel messages when app limit blocks or daily limits are reached.

---

## 5. Database Changes
None.

---

## 6. Firebase Changes

### Firestore Collections:
* `/users/{userId}/tokens`:
  - Document fields: `fcmToken` (String), `deviceModel` (String), `updatedAt` (String).

### Cloud Functions / Triggers:
* Configure background trigger logic (via Cloud Functions or client-side HTTP calls) sending FCM payloads:
  - Target: Partner's registered tokens.
  - Payload: Details of the user's bypass attempt or release request status.

---

## 7. Flutter Changes

### Dependency Configuration:
* Add `firebase_messaging` and `flutter_local_notifications` in `pubspec.yaml`.

---

## 8. Native Android Changes
* Update Gradle dependencies to support Firebase Cloud Messaging.

---

## 9. Acceptance Criteria
* **Bypass Alerts**: Tapping Settings bypass controls or changing device clock triggers a push notification to the partner device containing: *"User has attempted to bypass SayNO protection!"*
* **Release Milestone Sync**: Every status shift inside `/release_requests` collection in Firestore dispatches corresponding notifications to the partner.
* **Token Refresh Registry**: Re-installing the app or logging in updates the active FCM token in `/users/{userId}/tokens`.

---

## 10. Manual Testing Checklist

1. **Token Registration Check**:
   - Log in. Open Firestore Console -> verify `/users/{userId}/tokens` contains a valid FCM push token.
2. **Settings Bypass Alert**:
   - Navigate to System Settings -> Apps -> SayNO App Info.
   - Verify the user is ejected (Sprint 2 behavior) AND the partner device receives a push notification alerting them of the bypass attempt.
3. **Clock Manipulation Alert**:
   - Disconnect internet, set clock back 5 minutes, reconnect.
   - Verify that the partner device receives a push notification warning of clock manipulation.
4. **Lifecycle Notification Check**:
   - Select "Request Release" on User Settings.
   - Verify that the partner device receives a notification: *"User has requested protection release."*

---

## 11. Git Commit Plan

1. **`feat(firebase): integrate firebase_messaging and configure FCM dependencies`**
   - Configures dependencies in `pubspec.yaml` and Android Gradle files.
2. **`feat(notification): implement NotificationService for token management and listeners`**
   - Implements local notification triggers and Firestore registry.
3. **`feat(native): trigger platform channel notifications on settings/clock bypasses`**
   - Integrates method alerts inside accessibility service and intervention engine.
4. **`feat(backend): implement cloud notification triggers for release request states`**
   - Connects FCM triggers to Firestore `/release_requests` updates.
