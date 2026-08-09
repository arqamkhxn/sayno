# Phase 5 — Sprint 1: Partnership Foundation

## 1. Sprint Objective
Establish the core Firebase authentication and data infrastructure, configure Firestore security rules, and implement the interpersonal linking loop (invitation, verification token validation, and linked relationship states).

---

## 2. Scope

### Included:
* Firebase Authentication initialization and basic login state tracking.
* Firestore collection mapping for:
  - `/users/{userId}`: Profiles for users and partners.
  - `/partnerships/{partnershipId}`: Association state (`userId`, `partnerId`, `relationStatus`).
* Firestore Security Rules locking down read/write access based on active UIDs.
* Local SQLite database migrations setting up the offline `partnerships` table.
* Invite Partner logic (generating pending partnership documents with an 8-character verification token in Firestore).
* Link Verification loop (partner logs in, enters validation token, updates document status to `active`).
* Preventing self-linking loops where the user invites their own email or links on an identical device.
* Graceful fallback: If Firebase is not initialized, accountability setup is disabled with a warning page.

### Explicitly Excluded:
* Cloud synchronization of active contracts and streaks (Sprint 2).
* Human-gated multi-step Release Request state machine (Sprint 3).
* Push notifications and FCM intervention alerts (Sprint 4).

---

## 3. Files To Create

### Flutter Files:
* **[partnership.dart](file:///d:/sayno-main-phase-1/lib/features/settings/domain/partnership.dart)**: Domain model mapping local and remote partnership states, including `partnerUid`.
* **[partnership_repository.dart](file:///d:/sayno-main-phase-1/lib/features/settings/data/partnership_repository.dart)**: Abstract repository interface managing Firestore and SQLite relationship links.
* **[sqlite_partnership_repository.dart](file:///d:/sayno-main-phase-1/lib/features/settings/data/sqlite_partnership_repository.dart)**: SQLite repository concrete implementation persisting linked status offline.
* **[partner_controller.dart](file:///d:/sayno-main-phase-1/lib/features/settings/application/partner_controller.dart)**: Riverpod controller implementing `invitePartner(String email)` and `acceptInvitation(String token)`.
* **[partner_setup_screen.dart](file:///d:/sayno-main-phase-1/lib/features/settings/presentation/partner_setup_screen.dart)**: UI containing email invitation input, validation token entry loops, and active partner status cards. Displays an unavailable state card if Firebase fails to load.

---

## 4. Files To Modify

### Flutter Code:
* **[session_database.dart](file:///d:/sayno-main-phase-1/lib/features/protection/data/session_database.dart)**:
  - Increment DB version to `6`.
  - Add local `partnerships` table setup (including `partner_uid`) to `onCreate` and `onUpgrade` migration paths.
* **[app_router.dart](file:///d:/sayno-main-phase-1/lib/navigation/app_router.dart)**:
  - Register GoRoute `/partner-setup` mapped to `PartnerSetupScreen`.
* **[settings_screen.dart](file:///d:/sayno-main-phase-1/lib/features/settings/presentation/settings_screen.dart)**:
  - Link the "Accountability Partner" tile to redirect users to `/partner-setup`.
* **[pubspec.yaml](file:///d:/sayno-main-phase-1/pubspec.yaml)**:
  - Add `firebase_auth` dependency alongside core/firestore.

---

## 5. Database Changes

### SQLite Table: `partnerships`
* Column: `id` (INTEGER, Primary Key, Auto-increment)
* Column: `partner_email` (TEXT, Not Null)
* Column: `partner_uid` (TEXT, Nullable)
* Column: `status` (TEXT, Not Null): Linking state indicator (`pending`, `active`).

### Database Migrations:
* Increment SQLite schema version to `6`.
* Implement incremental migration check to create the `partnerships` table if `oldVersion < 6`.

---

## 6. Firebase Changes

### Authentication:
* Enable Email/Password provider in Firebase Console.

### Firestore Collections:
* `/users`: Document fields: `email`, `createdAt`.
* `/partnerships`: Document fields: `userId`, `partnerEmail`, `partnerId` (nullable), `verificationToken`, `status` (`pending` / `active`), `createdAt`.

### Firestore Security Rules:
* Restrict `/users` reads and writes to authenticated UIDs matching document IDs.
* Restrict `/partnerships` writes:
  - Creation: User can write only if authenticated and `userId` matches auth UID.
  - Updates: Partner can write to update `status` to `active` and write `partnerId` only if authenticated and their email matches `partnerEmail`.
  - Reads: User can read if `userId` matches auth UID; partner can read if email matches `partnerEmail`.

---

## 7. Flutter Changes

### Riverpod Providers:
* `partnershipRepositoryProvider`: Exposes `SqlitePartnershipRepository`.
* `partnerControllerProvider`: Exposes the linking and verification state.

### Dependency Configuration:
* Add `firebase_core`, `firebase_auth`, and `cloud_firestore` plugins in `pubspec.yaml`.

---

## 8. Native Android Changes
None.

---

## 9. Acceptance Criteria
* **Validation Check**: User cannot invite their own email address or complete self-linking on the same device.
* **Verification Match**: Partner must enter the exact 8-character verification token generated in Firestore.
* **Link State Synchronization**: Upon token success, the partnership status updates to `active` in Firestore and propagates to the local SQLite database.
* **Security Lock**: Firestore rules block unauthenticated reads/writes, preventing third-party access to email links.
* **Config Safety**: Firebase configuration failures are caught in `main.dart`, and partner settings are rendered unavailable rather than falling back to local simulation.

---

## 10. Manual Testing Checklist

1. **Authentication Verification**:
   - Register User A and User B on Firebase.
2. **Invitation Loop**:
   - Log in as User A, navigate to `/partner-setup`, invite User B (`email_b@example.com`).
   - Open Firestore console: verify a `/partnerships` document is written with status `pending` and a verification token.
3. **Acceptance Loop**:
   - Log in as User B on a separate profile/device. Navigate to `/partner-setup`.
   - Enter the token generated in Firestore.
   - Verify document status in Firestore updates to `active`.
   - Verify User A's dashboard displays "Partner: Linked".
4. **Self-Linking Block**:
   - Attempt to invite A's own email. Verify that a validation error occurs.
5. **No Firebase Crash Test**:
   - Run the app without `google-services.json`. Verify the app initializes safely and `/partner-setup` renders the "Accountability features currently unavailable" warning.

---

## 11. Git Commit Plan

1. **`feat(firebase): initialize firebase auth, core, and firestore configs`**
   - Configures dependencies in `pubspec.yaml` and client firebase setup in `main.dart`.
2. **`feat(database): define partnerships table and schema version 6 migrations`**
   - Configures version upgrades in `session_database.dart` with `partner_uid` columns.
3. **`feat(partner): implement PartnerController and link repositories`**
   - Implements Firestore writes and SQLite persistence.
4. **`feat(ui): design PartnerSetupScreen and connect navigation`**
   - Connects screens and adds verification input widgets.

---

## 12. Approved Corrections (Sprint 5A Outcomes)

* **Firebase Auth Dependency**: Added `firebase_auth` dependency alongside core and firestore to manage authenticating users/partners securely.
* **Database Alignment**: Added `partner_uid` (nullable, TEXT) column in local SQLite `partnerships` database schema to enable validation against local profile tampering.
* **Token Logic**: Secure verification tokens are generated on invitation triggers and stored in Firestore for partner lookup/validation.
* **Failure Resilience**: Catches initialization failures on startup. If config is absent, the UI disables accountability settings and shows an explicit "Unavailable" warning state card instead of fallback mock simulation.

