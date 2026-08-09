# Phase 5 Discovery Report: Human Accountability

## Objective & Scope
Phase 5 introduces the **Human Accountability** layer (Fortress Mode), shifting the application's bypass resistance from purely automated friction (the Phase 4 24-hour cooldown) to social and external friction. By connecting the user's deactivation vectors to a trusted third party ("Partner"), SayNO introduces interpersonal stakes to deter impulsive habits.

This document analyzes the architectural requirements, flows, dependencies, risks, and Play Store constraints for the proposed accountability features.

---

## Part 1: Feature Analysis

### 1. Partner System
* **Purpose**: Establish a secure, authenticated link between the user (who is subject to protection) and a trusted accountability partner (who monitors and approves requests).
* **User Flow**:
  1. User navigates to the "Accountability" tab in SayNO.
  2. User inputs the partner's email address and sends an invite.
  3. The backend generates a secure invitation link/code.
  4. The partner downloads SayNO (or accesses a lightweight web portal), logs in, and accepts the invitation code.
  5. Once accepted, both profiles show a "Linked" status.
* **Dependencies**:
  - Firebase Authentication (for partner identity verification).
  - Firestore (to store user-partner relationship documents).
  - Cloud Functions (to handle invite generation and validation safely).
* **Edge Cases**:
  - **Self-Linking**: User attempts to link with another email they control.
  - **Partner Unlinking**: The partner deletes their account or unlinks mid-contract.
  - **Multiple Partners**: Handling whether a user can have more than one partner or if the link is strictly 1-to-1.
* **Risks**:
  - Users creating "ghost" partner accounts to self-approve deactivations.
  - Exposure of user data if invitation codes are guessable (needs cryptographically secure random UUIDs).
* **Play Store Considerations**:
  - User and partner accounts must comply with standard account creation and deletion policies. Account deletion must be easy to trigger and must scrub all associated PII (Personally Identifiable Information).

### 2. Partner Approval
* **Purpose**: Require explicit confirmation from the linked partner before a Release Request is finalized or critical settings are modified.
* **User Flow**:
  1. User triggers a Release Request inside SayNO.
  2. The 24-hour cooldown starts. Simultaneously, the partner is notified.
  3. After the 24-hour cooldown expires, the release is placed in a "Pending Partner Approval" state.
  4. The partner logs into their app/portal and reviews the request.
  5. If the partner clicks "Approve," the protection is released. If the partner clicks "Deny," the request is canceled and the app returns to a secured state.
* **Dependencies**:
  - Firebase Cloud Messaging (FCM) for instant push notifications to the partner.
  - Cloud Firestore real-time listeners to sync approval states.
  - A reliable clock source (NTP) to check cooldown expiration.
* **Edge Cases**:
  - **Partner Unresponsiveness**: The partner goes offline, loses their phone, or ignores the request, locking the user indefinitely.
  - **Offline State**: User is offline when the partner approves the request.
* **Risks**:
  - High friction causing user frustration if partners are inactive, which might lead the user to force-uninstall the app using advanced Android debugger tools (ADB).
* **Play Store Considerations**:
  - The app must clearly explain to the user during setup that they are delegating control to a partner and that they might be locked out if the partner is unresponsive.

### 3. OTP Release
* **Purpose**: Provide a secondary, out-of-band unlock mechanism where the partner receives a One-Time Password (OTP) that must be manually entered on the user's device.
* **User Flow**:
  1. The user requires an immediate release or configuration override.
  2. The user's app displays a screen: "Enter Partner OTP to Unlock."
  3. The partner receives a dynamic 6-digit OTP code on their own device (or via SMS/Email).
  4. The partner communicates this code to the user (verbally or via text) only after verifying the legitimacy of the request.
  5. The user enters the code to immediately bypass/deactivate protection.
* **Dependencies**:
  - Backend OTP generation service (Secure Cloud Function).
  - Secure communication channel to deliver OTP to the partner (FCM, SMS gateway, or Email).
* **Edge Cases**:
  - **Brute Forcing**: The user attempts to guess the 6-digit code.
  - **Stale Codes**: OTP expires before the partner can send it to the user.
* **Risks**:
  - If the OTP is sent via SMS, it can be expensive and prone to SIM-swapping or interception if the user has physical access to the partner's messages (e.g., spouses/family members in the same house).
* **Play Store Considerations**:
  - Standard compliance for handling verification tokens. No special permissions required.

### 4. Accountability Flows
* **Purpose**: Keep the partner updated on the user's progress, successes, or failures to build trust and strengthen the social contract.
* **User Flow**:
  1. Weekly/daily digest reports of contract statuses are generated.
  2. If the user achieves a new streak milestone (e.g., 30 days), the partner is notified: "User has maintained their streak for 30 days!"
  3. If the user triggers an intervention or attempts a clock manipulation, the partner is notified immediately: "Trigger detected: User accessed restricted settings."
* **Dependencies**:
  - Cloud Scheduler (to trigger weekly/daily cron digests).
  - [SessionRepository](file:///d:/sayno-main-phase-1/lib/features/protection/data/session_repository.dart) data synced to Firestore.
* **Edge Cases**:
  - **Spamming Notifications**: A user trigger-happy with setting adjustments could spam the partner's phone.
  - **Silent Failures**: Notification deliveries fail due to OS-level background restrictions on the partner's device.
* **Risks**:
  - Over-notification may cause the partner to mute notifications, rendering the system ineffective.
* **Play Store Considerations**:
  - Must respect notification channel policies and allow partners to customize notification preferences.

### 5. Contract Override Requests
* **Purpose**: Allow users to propose modifications to an active contract (e.g., raising daily limits, removing an app from restriction) without violating the contract system, provided the partner approves.
* **User Flow**:
  1. User attempts to edit an active contract in the UI.
  2. Instead of a direct edit, the UI transitions to "Request Contract Modification."
  3. User inputs the proposed changes (e.g., "Change Daily Limit on App X from 30m to 45m").
  4. Request is sent to the partner. Cooldown (e.g., 12 hours) is initiated.
  5. Partner reviews and approves/denies the override.
* **Dependencies**:
  - [ContractController](file:///d:/sayno-main-phase-1/lib/features/contract/application/contract_controller.dart) and Firestore schema supporting draft/pending contract overrides.
* **Edge Cases**:
  - Multiple overlapping override requests.
  - Override request is approved *after* the contract has already expired.
* **Risks**:
  - Users exploiting overrides to slowly dilute their restrictions, undermining their long-term recovery goals.
* **Play Store Considerations**:
  - None. This is internal app logic.

### 6. Emergency Access Requests
* **Purpose**: Provide a fail-safe bypass for genuine emergencies (e.g., needing to access an app immediately when the partner is unreachable), balanced by heavy penalties or high social costs to deter abuse.
* **User Flow**:
  1. User clicks "Emergency Bypass" on a blocked screen.
  2. App displays warning: "Emergency access will disable protection for 1 hour. This action will notify your partner immediately and deduct 100 streak credits / reset your contract streak."
  3. If user accepts, protection is temporarily disabled.
  4. Partner is notified instantly of the emergency override activation.
* **Dependencies**:
  - Local database transaction updating streak stats.
  - FCM / Twilio integration for high-priority alerts.
* **Edge Cases**:
  - User triggers emergency access during an offline state (local penalty must still occur immediately).
  - Repeated triggers of emergency access (needs escalating penalties or lockout timers).
* **Risks**:
  - User abusing emergency access when experiencing an intense impulse, rationalizing the credit/streak penalty.
* **Play Store Considerations**:
  - Must not restrict access to critical dialer, emergency services (911/112), or system settings required for device safety.

### 7. Partner Notifications
* **Purpose**: Reliable delivery of high-priority security and progress updates to the partner.
* **User Flow**:
  1. Native trigger occurs (e.g., Clock Drift detected in Kotlin [SayNoLimitManager](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoLimitManager.kt)).
  2. Flutter is notified and writes a log to Firestore.
  3. Firestore Trigger (Cloud Function) fires.
  4. Push notification is sent via FCM to the partner's device registration token.
* **Dependencies**:
  - Firebase Cloud Messaging (FCM).
  - Cloud Functions.
* **Edge Cases**:
  - Device lacks internet access (notification must queue and fire as soon as connection is restored).
  - Partner has disabled notifications for the app.
* **Risks**:
  - Delivery delays in push notifications (FCM can sometimes experience delay under battery saver modes).
* **Play Store Considerations**:
  - Must declare appropriate notification categories. Since these are not marketing notifications, they are permitted.

### 8. Cloud Sync Requirements
* **Purpose**: Synchronize configuration, active contracts, and protection status to the cloud to prevent local data deletion bypasses (e.g. "Clear Storage" or "Reinstall App" cheats).
* **User Flow**:
  1. App automatically syncs config data on change.
  2. If the user clears local storage and re-authenticates, the app fetches the active contract and protection state from Firestore.
  3. The local shields are immediately reactivated on the device.
* **Dependencies**:
  - Firestore offline persistence enabled.
  - Auth token integration.
* **Edge Cases**:
  - **Conflicts**: User makes changes offline on two different devices.
  - **No Internet**: User clears data while offline and stays offline to prevent sync (shield must default to locked if local metadata is missing/incomplete).
* **Risks**:
  - Sync latency might allow a temporary window of unprotected access before the cloud state is fetched during re-installation.
* **Play Store Considerations**:
  - Clear Privacy Policy detailing that app state is synced to the cloud to preserve contract integrity.

### 9. Firebase Requirements
* **Purpose**: Structural backend architecture to support real-time data sync, secure calculations, notifications, and partner relationship mappings.
* **Architecture**:
  - **Firestore Schema**:
    - `/users/{userId}`: Streak credits, settings, active contract reference.
    - `/partnerships/{partnershipId}`: Fields: `userId`, `partnerId`, `status` (pending/active), `createdAt`.
    - `/release_requests/{requestId}`: Fields: `userId`, `requestedAt`, `cooldownExpiresAt`, `status` (pending_cooldown, pending_approval, approved, denied).
  - **Firestore Security Rules**:
    - Users can only read/write their own records.
    - Linked partners can read the user's contract state but cannot write to it directly.
    - Updates to release requests are restricted via server-side checks.
  - **Cloud Functions**:
    - `sendPartnerInvite`: Validates email, creates partnership record, sends notification.
    - `validateReleaseRequest`: Validates NTP timestamp and monotonic elapsed limits before marking a release request as completed or authorizing deactivation.
* **Dependencies**:
  - Firebase suite.
* **Risks**:
  - Cloud database costs if queries are not optimized (e.g., excessive checking/polling instead of listeners).

### 10. Abuse Prevention
* **Purpose**: Close technical and social loop-holes that users might exploit to bypass the accountability layer.
* **Measures**:
  - **Identity Verification**: Prevent linking with secondary emails under the same IP/Device identifier.
  - **Offline Lockdown**: If the app loses internet connection for more than 48 hours during a pending Release Request, freeze the countdown until connection is restored and verified by NTP.
  - **App Re-installation Loophole**: If the app is uninstalled/reinstalled, it must immediately download active contract states from Firestore upon login. Until login completes, the app defaults to a restricted overlay state if an active contract was previously synced.
* **Dependencies**:
  - Device ID tracking (Android ID / hardware identifier) to recognize re-installations of the same physical device.
* **Risks**:
  - User changing Google Play accounts to bypass cloud sync (device hardware identifiers must be linked to the device record in Firestore).
* **Play Store Considerations**:
  - Google Play rules restrict the tracking of persistent hardware identifiers (like IMEI). We must use a resettable App Set ID or Firebase Installation ID.

---

## Part 2: Strategic Discovery Questions

### Q1: What should Phase 5 actually contain?
Phase 5 should focus strictly on **the core human accountability protocol** (creating the relationship and gatekeeping the deactivation flow). It must contain:
1. **The Partner System**: Registration, secure invite link generation, and partner connection mapping.
2. **Cloud Sync of Active Contracts**: Syncing contract states to Firestore so clearing app storage does not delete the active contracts.
3. **Partner-Gated Release Request Flow**: Updating the Phase 4 Release Request System to require partner approval via FCM notification once the 24-hour cooldown expires.
4. **Basic Partner Notifications**: FCM alerts sent to the partner when a Release Request is initiated, canceled, or successfully completed.
5. **Abuse Prevention Basics**: Freeze timers on prolonged offline state; block self-linking.

### Q2: What should NOT be in Phase 5?
Phase 5 should exclude complex, high-overhead features that can distract from validating the core partner-gating mechanism:
1. **SMS Gateway Notification**: Native SMS triggers should be avoided due to severe Google Play permission restrictions (`SEND_SMS` is prohibited for non-SMS apps) and transactional cost overheads.
2. **Emergency Access Requests**: Providing a self-override window (even with heavy penalties) complicates the initial launch and introduces a fallback loop that is highly susceptible to rationalized abuse.
3. **Multiple Partners / Team Accountability**: Keep the system strictly 1-to-1 to minimize UI and database complexity.

### Q3: Which features belong in a later phase?
The following features should be deferred to a subsequent phase (e.g., Phase 6: Extended Accountability):
1. **OTP Release**: Out-of-band numeric PIN unlocks can be built once the basic app-to-app partner link is stable.
2. **Contract Override Requests**: Proposing modifications to contracts mid-flight creates state synchronization challenges and should be deferred until standard contract enforcement is field-tested.
3. **Emergency Access Requests**: Implement only after the baseline contract system has proven stable and users request a panic button.
4. **Advanced Accountability Digests**: Detailed habit reporting, usage graphs, and weekly digests for the partner.

### Q4: What is the core philosophy of "Fortress Mode"?
The core philosophy of **Fortress Mode** is:
> **"Social Friction is Stronger than Technical Restrictions."**

While Phase 4 focuses on local system rules and device security (The Vault Layer), Fortress Mode shifts the locus of control externally. It recognizes that:
1. Impulsive urges are temporary, high-emotion states.
2. An automated lock can feel like a mechanical puzzle to be solved or hacked.
3. A human relationship introduces empathy, shame, and commitments that cannot be hacked or bypassed. By forcing the user to wait 24 hours and then face their chosen accountability partner to explain their decision, we change the equation from a technical bypass challenge to an interpersonal conversation.
