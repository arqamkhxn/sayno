# Pre-Implementation Architecture Review: SayNO Roadmap (Phases 4, 5, & 6)

This audit evaluates [phase_4_blueprint.md](file:///d:/sayno-main-phase-1/project_docs/phase_4_blueprint.md), [phase_5_blueprint.md](file:///d:/sayno-main-phase-1/project_docs/phase_5_blueprint.md), and [phase_6_blueprint.md](file:///d:/sayno-main-phase-1/project_docs/phase_6_blueprint.md) to ensure technical cohesion, database completeness, and feasibility.

---

### 1. CONTRADICTIONS

* **Reboot Monotonic Drift Loophole**: 
  [phase_4_blueprint.md](file:///d:/sayno-main-phase-1/project_docs/phase_4_blueprint.md) (Module A) dictates that system wall clock drift must be compared to the monotonic hardware clock (`SystemClock.elapsedRealtime()`). However, `elapsedRealtime()` resets to 0 on reboot. If reboot survival persistence (saving accumulated monotonic uptime before shutdown or periodically) is deferred to [phase_5_blueprint.md](file:///d:/sayno-main-phase-1/project_docs/phase_5_blueprint.md) (Module E), any device reboot during Phase 4 will cause a false clock manipulation trigger and lock the user out.
* **Release Request Pipeline Conflict**: 
  In Phase 4, the Release Request is a single-step offline transition: `Cooldown (24h) -> Released`. In Phase 5, this expands to a multi-step partner/cloud flow: `Cooldown (24h) -> Partner Approval -> Grace Window (24h) -> Released`. The behavior is undefined when a user initiates a Release Request in Phase 5 but **does not have a linked partner** (e.g., fallback path to local 24h cooldown, or locking the release system entirely).
* **Wallet Currency vs. Contract Credits**: 
  The existing UI mockup [WalletScreen](file:///d:/sayno-main-phase-1/lib/features/wallet/presentation/wallet_screen.dart) presents transactions in dollar values ($10.00, $2.50) representing credit balances. However, the Contract domain model [ContractApp](file:///d:/sayno-main-phase-1/lib/features/contract/domain/contract_app.dart) defines `totalCredits` and `remainingCredits` strictly as a `Duration` (seconds/minutes of allowed app usage). There is a semantic and logic mismatch in how monetary wallet transactions map to time-based contract credits.
* **Utility Mode Post-Limit Tracking**: 
  In Phase 6's Utility Mode, once an app reaches its limit, the Feed and Reels are masked, but DMs remain accessible. However, the current native [SayNoLimitManager](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoLimitManager.kt) calls `stopChecking()` and terminates session tracking the moment the limit is hit:
  ```kotlin
  if (limit != -1L && totalUsage >= limit) {
      interventionManager?.startLimitReachedIntervention(pkg)
      stopChecking()
  }
  ```
  If tracking stops, any usage accrued in allowed utility areas (DMs) post-limit will not be recorded, rendering daily usage totals inaccurate.

---

### 2. IMPLEMENTATION BLOCKERS

* **Missing Local SQLite Schema for Partner & Release Requests**: 
  [phase_5_blueprint.md](file:///d:/sayno-main-phase-1/project_docs/phase_5_blueprint.md) defines Firestore collections for partnerships and release requests but does not specify their local SQLite schemas. For the app to support "Offline Integrity" (verifying active requests and partner link states while offline), a local DB representation is required.
* **Missing Monotonic Uptime Persistence Schema**: 
  To enforce monotonic time calculations across reboots, the native side must store periodic monotonic checkpoints. The persistence mechanism, storage keys, and background update frequency (e.g., SharedPreferences write interval) are completely undefined.
* **No Database Schema for Wallet / Transactions**: 
  There are zero database tables or entities defined for storing wallet balance and transaction logs, despite the UI presenting this feature.

---

### 3. PHASE DEPENDENCIES

The order **Phase 4 $\rightarrow$ Phase 5 $\rightarrow$ Phase 6** is logically valid, with one critical adjustments:
* **Move Monotonic Reboot Recovery to Phase 4**: The monotonic uptime accumulation and recovery logic across device boots (currently in Phase 5 Technical Notes) must be moved into Phase 4's Time Drift Shield. Otherwise, Phase 4's clock manipulation checks will break on every reboot.

---

### 4. DATABASE REVIEW

* **Wallet Tables**: *Totally Missing*. No tables exist to store balance, transactions, or penalty structures.
* **Contract Tables**: Valid, but needs expansion in Phase 6.
* **Restriction Modes**: The `app_limits` table in [SessionDatabase](file:///d:/sayno-main-phase-1/lib/features/protection/data/session_database.dart) lacks a `restriction_mode` column. If custom limits configured outside of active contracts are to support Selective Friction (e.g., Utility Mode), they cannot store this setting.
* **Partner / Release Request Systems**: Missing SQLite structures to store `partnership_status`, `cooldown_expires_at`, `grace_window_expires_at`, and status enums locally.
* **Migration Risks**: Transitioning from Phase 4 to Phase 5 requires altering the local `release_requests` schema to support the additional approval and grace window timestamps.

---

### 5. NATIVE AND FLUTTER REVIEW

* **Accessibility settings bypass vulnerabilities**:
  Scanning for button texts like "Uninstall" or "Force Stop" in [SayNoAccessibilityService](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoAccessibilityService.kt) fails on devices configured with non-English system languages.
* **Selective Viewport Masking**:
  Drawing a single window with touch pass-through flags and calculating y-coordinates is highly realistic. However, drawing a layout over the exact middle viewport is cleaner when using separate window layout configurations rather than touch exclusions on a full-screen frame.
* **YouTube Shorts activity signature**:
  Obfuscated class names in YouTube updates make strict activity matching (`ShortsActivity`) highly brittle. The accessibility service must fall back on scanning layout node labels containing "Shorts" or specific layout dimensions.

---

### 6. MVP RISK REVIEW

* **Highest Implementation Risk**: *Monotonic clock calibration*. Accurately reconstructing monotonic duration across unexpected device shut-downs/reboots without causing clock manipulation lockouts.
* **Highest Maintenance Risk**: *Selective layout tracking (Instagram/YouTube)*. Layout changes or ID obfuscations by social media apps will disable selective masks, requiring frequent updates to SayNO's node traversing rules.
* **Highest UX Risk**: *Partner lockouts*. The user is permanently locked if a partner loses their device or remains unresponsive, with no self-recovery mechanism.

---

### 7. FINAL VERDICT

**B) Needs Minor Fixes Before Implementation**

#### Critical Fixes Required:
1. **Move Monotonic Reboot Recovery to Phase 4**: Relocate the Kotlin persistence logic for `SystemClock.elapsedRealtime()` recovery across reboots to Phase 4 to prevent broken time drift locks on reboot.
2. **Define Local DB Schema for Release Requests & Partners**: Add local SQLite tables in Phase 4 for `release_requests` (columns: `id`, `requested_at_utc`, `cooldown_duration_seconds`, `status`, `partner_approved_at_utc`, `grace_window_expires_at_utc`) and `partnerships` (columns: `id`, `partner_email`, `status`) to support offline checks and seamless Phase 5 upgrades.
3. **Allow Continuous Session Tracking in Utility Mode**: Refactor [SayNoLimitManager](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoLimitManager.kt) to maintain active tracking of the usage session post-limit when the app is in `Utility` mode, instead of calling `stopChecking()`.
4. **Specify Fallback for Partnerless Release Requests**: Define a rule in Phase 5 where if no partner is linked, the release request falls back to a standard local 24-hour cooldown authorization.
5. **Use Resource IDs / Obfuscation Fallbacks for Native Safeguards**: Enforce resource ID checks (`com.android.settings:id/force_stop_button`) rather than localized English texts to safeguard settings bypasses internationally.
