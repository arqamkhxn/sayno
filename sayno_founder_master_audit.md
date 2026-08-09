# SayNO — Founder's Master Product Audit

**Document Version:** 1.0  
**Date:** June 25, 2026  
**Role:** Founder, Product Architect, & Vision Keeper  
**Scope:** Reconstructing the Complete Product Memory of SayNO  

---

## Executive Summary

SayNO is a **Digital Discipline Platform** designed to help users overcome social media addiction, attention fragmentation, and compulsive digital habits. By replacing fleeting motivation with structured, partner-backed commitments and native system-level friction, SayNO makes disciplined behavior easier than impulsive bypasses.

This master document reconstructs the entire product memory of SayNO. It details the chronological evolution of the product from a simple screen blocker mockup into a native-first Android and cloud-synchronized platform. It catalogs every implemented feature, highlights planned and deferred items, maps the user journey, outlines the core decisions and rejected paths, and establishes the product's posture as we prepare for Version 1.0.

---

## PART 1 — COMPLETE PRODUCT HISTORY

### Phase 1: Foundation & UI System
* **Why This Phase Existed:** To establish the visual identity, brand tone, and interface guidelines of SayNO. Before building complex security code, we needed to define how a premium discipline application should look, feel, and communicate.
* **Problem Solved:** Attention fragmentation and anxiety. Most productivity apps use bright, gamified, or neon interfaces that excite the brain. Phase 1 established a low-stimulus environment to encourage calm focus.
* **Major User-Facing Features:**
  * Minimalist Dark Theme Dashboard.
  * Digital Health statistics tiles and app limit cards.
  * Navigational hub connecting the dashboard, settings, and health modules.
* **Major Internal Systems:**
  * GoRouter-based modular routing tree.
  * Unified component design system utilizing standardized colors (`#0A0A0A` background, `#111111` cards, green/amber/red status colors) and padding.
  * Basic Riverpod state notification layers.
* **What Changed compared to previous phase:** This was the initial foundation (no previous phase).
* **Final Completion Status:** **100% Completed.**

### Phase 2: Silent Guardian (Native Protection & Usage Sync)
* **Why This Phase Existed:** To build native Android protection that works in the background, independent of whether the main Flutter application is open or killed.
* **Problem Solved:** The "App-Killing Bypass." Typical blockers are easily bypassed by swiping the application out of memory, force stopping the service, or disabling background permissions. 
* **Major User-Facing Features:**
  * Live session timers showing real-time monitored app usage.
  * Alarm-red "LIMIT REACHED" banners on active cards.
  * Full-screen native block overlay (`BlockOverlay`) displaying professional, non-shaming lockout notices.
  * Interactive Digital Health screen displaying dynamically synced limits.
* **Major Internal Systems:**
  * Android Accessibility Service integration (`SayNoAccessibilityService`) listening for package and content changes.
  * Native SharedPreferences registers (`sayno_config`, `sayno_usage`) acting as the service's native database.
  * SQLite relational database (`sayno_sessions.db` with `sessions` and `app_limits` tables) storing completed sessions.
  * Local, on-device keyword scanning traversing node trees, matching target keywords, and passing results to Flutter via MethodChannels.
  * Starvation protection for fast scrolling and node recycling to prevent memory leaks.
  * Chronological midnight usage reset checking.
* **What Changed compared to previous phase:** Transitioned the product from a static visual mockup into a functioning background blocker.
* **Final Completion Status:** **100% Completed.**

### Phase 3: Contract Engine / Streak Engine
* **Why This Phase Existed:** To introduce structured commitment contracts and daily progress feedback loops, helping users build long-term digital habits.
* **Problem Solved:** Motivation depletion. Standard blocking fails when users can turn it off at will. Contracts introduce a structured discipline period with streak metrics that gamify consistency.
* **Major User-Facing Features:**
  * "Create Contract" set-up screen defining duration (e.g., 30 days) and apps to monitor.
  * Color-coded Contract Calendar showing green (passed) and red (failed) history blocks.
  * Streaks metrics (current streak and longest record).
  * "Borrow Minutes" trigger that lets users access a restricted app post-limit in exchange for failing today's calendar status and resetting active streaks.
* **Major Internal Systems:**
  * Database schema upgrades adding `contracts`, `contract_apps`, and `contract_days` SQLite tables.
  * `ContractValidationService` running on app launch to verify UTC midnight transitions and recalculate streak counts.
  * Active contract status MethodChannel mapping (`updateActiveContractStatus`) notifying the Kotlin service when to enable restrictions.
* **What Changed compared to previous phase:** Shifted focus from simple, easily modified app limits to binding, multi-day Commitment Contracts with gamified streak rewards.
* **Final Completion Status:** **100% Completed.**

### Phase 4: The Vault Layer (Enforcement & Time Integrity)
* **Why This Phase Existed:** To protect active contracts from being bypassed through common system-level modifications (clock manipulation, settings bypasses, app restarts).
* **Problem Solved:** The "Technical Bypass loophole." Users under high impulsive stress will attempt to uninstall the app, change device settings, or manipulate the system clock backward to fake daily usage limits.
* **Major User-Facing Features:**
  * "Request Release" page and countdown timer in settings (the single gateway to uninstall/disable the app).
  * "Cancel Request" trigger to instantly reactivate protection.
  * "Clock Manipulation Detected" system lockout overlay.
  * "Protection Active" interception dialogue rendering on top of the Settings app.
* **Major Internal Systems:**
  * Time Drift Shield: Kotlin daemon comparing device wall clock elapsed time against monotonic hardware clock elapsed time (`SystemClock.elapsedRealtime()`).
  * Boot completed receiver (`BootReceiver`) checking for boot-level clock rollbacks and restoring config profiles.
  * Settings Interception Shield: Accessibility node scanner checking for package `com.android.settings` and blocking access to uninstall, force stop, or toggle accessibility switches.
  * `TimeVerificationService`: Queries network time (Google date headers via HTTP HEAD) to verify local clock drift within a 30-second skew threshold.
  * SQLite `release_requests` table tracking cooldown request parameters.
* **What Changed compared to previous phase:** Hardened the application's native integrity, turning SayNO into a secure vault that cannot be uninstalled or stopped during an active contract.
* **Final Completion Status:** **100% Completed.**  
  *(Note: The original master architecture designated Phase 4 as "Commitment Economy" (Wallet/Penalties). Due to Play Store risk and billing complexity, "The Vault Layer" was prioritized for Phase 4, and monetary wallets were postponed).*

### Phase 5: Human Accountability (Fortress Mode)
* **Why This Phase Existed:** To shift the primary bypass barrier from mechanical locks to interpersonal social stakes, while protecting local databases from storage-clear cheats.
* **Problem Solved:** Self-sabotage. Technical locks can eventually be cracked via ADB or factory resets. Accountability pairing makes bypass attempts visible to someone the user respects, adding a social barrier. It also closes the local data-clear bypass loop.
* **Major User-Facing Features:**
  * Account login and registration interface.
  * Partner Link Screen: invite input by email, token-validation flow.
  * Multi-Stage Release Request interface: displaying cooldown countdown, partner approval status, and a secondary 24-hour grace window.
* **Major Internal Systems:**
  * Firestore database sync: Backing up active contracts and release states to Firestore.
  * Pessimistic Rehydration: Checking cloud records upon login/install to instantly restore shields, rendering storage-clearing or uninstall-reinstall cheats useless.
  * SQLite partnerships table and expanded release requests schema (tracking partner approval and grace window timestamps).
  * FCM Partner push notifications for alerts (release requests, cancellations, completions, and settings bypass attempts).
* **What Changed compared to previous phase:** Upgraded local, isolated Vault protection into a cloud-synchronized, partner-gated social accountability network.
* **Final Completion Status:** **100% Completed.**

### Phase 6: Selective Friction Layer
* **Why This Phase Existed:** To prevent "lockout fatigue" by applying friction directly to addictive infinite scroll zones while preserving vital messaging and search utilities.
* **Problem Solved:** Total app lockouts block messaging tools (like Instagram DMs), forcing users to uninstall or deactivate SayNO. Selective friction blocks the addiction loop without disabling the utility.
* **Major User-Facing Features:**
  * Viewport-Constrained Feed Masking: Instagram Feed scroll viewport is blurred, while the top bar (DMs) and bottom tabs (Search/Profile) remain active.
  * Pre-emptive Splash Screen: A brief dark splash masking Instagram's cold launch to prevent feed flashes before accessibility nodes load.
  * Instagram Explore grid masking (blocking grids but revealing results once the search bar gains focus).
  * YouTube Shorts click and player activity ejections (triggering a BACK action and showing a warning toast).
  * Four selective restriction modes: Utility, Focus, Monk, and Time Limit.
* **Major Internal Systems:**
  * Viewport coordinate masking overlays: Native windows drawn with pass-through flags (`FLAG_NOT_TOUCH_MODAL`, `FLAG_NOT_FOCUSABLE`).
  * `SayNoAccessibilityService` layout tree analysis checking selected states, focus events (`TYPE_VIEW_FOCUSED`), clicks (`TYPE_VIEW_CLICKED`), and player class signatures (`ShortsActivity`).
  * Config manager mapping `RestrictionMode` variables per package.
  * Kotlin `SayNoLimitManager` refactored to continue check loops and usage calculations in background post-limit while in `Utility` mode.
* **What Changed compared to previous phase:** Replaced binary, full-app ejections on social media with surgical, viewport-level scroll blocking and Shorts-specific player ejections.
* **Final Completion Status:** **100% Completed.**

---

## PART 2 — COMPLETE FEATURE INVENTORY

### Protection Layers
* **Foreground Monitored App Detection:** Captures active package names on launch/swap.
* **On-Device Keyword Scanning:** debounced recursive traversal of accessibility node trees on high-risk packages to scan for blacklisted words without crossing the Flutter bridge.
* **Daily Usage Limits:** Enforcing user-configured usage thresholds per application.
* **Pre-emptive App-Entry Splash:** Full-screen opaque mask shown during social media startup to prevent layout flashes.
* **Viewport-Constrained Masking:** blurring/blocking scrollable feeds on Instagram while keeping headers and navigation active.
* **Explore Grid Masking:** masking infinite grids on Instagram, automatically hiding the mask when the search search input bar is focused, and restoring it when focus is lost.
* **YouTube Shorts tab interception:** programmatically executing BACK when tapping bottom navigation tabs.
* **YouTube Shorts player ejection:** immediately executing BACK gestures when Shorts player activity class signatures are detected.
* **Multi-Mode restriction filters:** Applying Utility, Focus, Monk, or Time Limit filters to monitored apps.
* **Active Window Rescan:** programmatically forcing node checks on content transitions.
* **Starvation Protection:** debounces text scanning, but forces scans immediately if continuous typing/scrolling runs for 1 second.
* **Node Leak Protection:** Recycles node trees (`AccessibilityNodeInfo.recycle()`) to protect device performance.

### Commitment Contracts
* **Contract Configurator:** Wizard setting duration (days), monitored apps, daily limits, and restriction modes.
* **Streak Tracker:** tracking current consecutive green days and highest records.
* **Contract Calendar:** Color-coded daily block map representing GREEN (passed) and RED (failed/time borrowed) history.
* **Streak Validation Daemon:** Runs on startup to verify UTC midnight shifts and update metrics.
* **Platform Sync Manager:** Communicates active contract states to native Kotlin to lock settings shields.
* **Contract Completion Restorer:** Restores generic limits when contract duration ends.

### Recovery & Relapse Mitigation
* **Credit Bank ("Borrow Minutes"):** Deducts contract duration and failures locally, reset active streaks to 0, and extends native daily limits by current usage + borrowed time to avoid total lockout crashes.

### Human Accountability (Fortress Mode)
* **Partner Invitation System:** email invitations, paired secure token generation.
* **Token Validation:** cryptographically checks paired links to prevent self-linking.
* **Double Cooldown Release Request:** 24-hour cooldown -> Partner Approval -> 24-hour grace window countdown before deactivation is authorized.
* **Release Cancellation:** allows users to cancel requests at any point to restore full protection and preserve streaks.
* **Partner Alert notifications:** FCM alerts sent to partners for requests, cancellations, completions, and settings bypass attempts.

### Cloud Synchronization
* **Firebase Auth integration:** User and partner login/registration.
* **Firestore Contract Backup:** Uploads contract lists and calendar arrays.
* **Firestore Release Request Sync:** Tracks approval flags.
* **Pessimistic Rehydration Check:** checks Firestore on startup to download and apply contracts, blocking storage-wipe bypasses.

### The Vault (System Integrity)
* **Monotonic clock verification:** compares wall clock drift against hardware monotonic clocks.
* **Time travel reset warning:** skips reset updates if backward date shifts are detected.
* **Reboot rollback checker:** `BootReceiver` flags clock manipulation if boot time is earlier than last recorded shutdown.
* **Settings Page Intercept:** blocks access to Android settings, downloaded accessibility lists, and package manager screens.
* **Safeguards scanner:** node checker identifying force stop, uninstall, and toggle switch resource buttons on Settings packages.
* **Single deactivation gateway:** blocks setting changes unless release requests are completed.

### User Experience
* **Premium Dark Theme:** Low-stimulus dark aesthetics.
* **Dashboard Widgets:** displays active app timers, progress charts, and active contract limits.
* **Digital Health lists:** retrieves and prints today's actual accumulated usage per app.
* **Non-Shaming messaging:** Calm, professional language.
* **Root Stack overlay integration:** Stack overlays GoRouter layers.

---

## PART 3 — IMPLEMENTED VS PLANNED

### SECTION A: IMPLEMENTED (Currently in Codebase)
* **Custom Dark Theme & Scaffolding:** `lib/theme/` and `lib/shared/widgets/`.
* **GoRouter Navigation:** `lib/navigation/`.
* **SQLite Database service:** `sessions`, `app_limits`, `contracts`, `contract_apps`, `contract_days`, `release_requests`, and `partnerships` schemas.
* **Session Repository & Usage Accumulator:** Relational persistence.
* **Android Accessibility Service:** `SayNoAccessibilityService` setup.
* **Foreground app package detection:** native MethodChannel bridge.
* **On-device keyword registry sync:** Kotlin registry matching.
* **Native overlay drawing:** WindowManager overlays.
* **Intervention gestures:** Programmatic BACK/HOME actions.
* **System broadcast listeners:** Screen state and Keyguard unlocks.
* **Contract wizard & calendar screens:** `lib/features/contract/`.
* **Time Drift Shield:** Monotonic hardware clock delta vs wall clock delta.
* **Boot completes handler:** `BootReceiver` and monotonic offset restores.
* **Settings Interception Shield:** Blocking settings, force stops, uninstalls.
* **Firebase authentication & Firestore sync:** Contract and partnership collections.
* **FCM partner notification hook:** `notificationServiceProvider` integrations.
* **Multi-stage release request logic:** 24h Cooldown, Firestore Partner Approval listener, and 24h Grace Window.
* **Pre-emptive splash screen:** Opaque splash shown on launching Instagram.
* **Instagram viewport feed blur masking:** constrained overlay drawing.
* **Instagram Explore grid masking:** focused EditText monitoring.
* **YouTube Shorts player activity & click ejection:** player class monitoring.
* **Four restriction modes:** Utility, Focus, Monk, and Time Limit synced to SharedPreferences.
* **Borrow Minutes:** Local credit bank.

### SECTION B: PLANNED (Roadmap Features Pushed/Deferred)
* **Reboot Monotonic Checkpoint persistence:** A background Kotlin worker that periodically writes the accumulated monotonic elapsed time to SharedPreferences to prevent clock manipulation lockouts on normal boots.
* **Auto-Update Layout Registry:** A remote registry server allowing the app to download revised layout node IDs for Instagram/YouTube dynamically, preventing selective blurs from breaking on app updates.
* **OTP Release System:** out-of-band unlock code generation (6-digit PIN sent to the partner, entered on the user's device).
* **Contract Override Requests:** Partner-approved contract modifications mid-flight with a 12-hour cooldown gate.
* **Emergency Access panic button:** Temporary 1-hour access to blocked apps, balanced by a severe penalty (deducting streak credits or resetting contract streaks) and immediate push notifications to the partner.
* **Advanced Accountability Digests:** detailed habit reporting, usage graphs, and weekly digests for the partner.
* **Browser-based selective blocking:** Viewport feed masking and Shorts/Reels ejections on mobile browsers like Chrome and Firefox.

### SECTION C: IDEAS (Discussions Postponed/Unresolved)
* **Commitment Economy Wallet & Monetary Penalties:** implementing actual credit cards, billing APIs, charging deposits, and collecting dollar penalties for contract violations (mocked in UI, database/logic is completely un-started).
* **iOS Platform support:** Porting the accessibility/overlay layers to iOS.
* **SMS Gateway Integration:** Fallback SMS alerts for offline partners.
* **Team Accountability:** Paired links with multiple partners.

---

## PART 4 — FUTURE ROADMAP MEMORY

```
[Phase 7: AI & Layout Resilience] ➔ [Phase 8: Extended Accountability] ➔ [Phase 9: Commitment Economy]
```

### Phase 7: AI Protection & Layout Resilience
* **Objective:** Transition protection scanning from rigid keyword registries to on-device intelligence, and protect selective masking from social media layout updates.
* **Planned Philosophy:** Surgical AI detection is more sustainable than keyword lists; automated layout updates prevent maintenance decay.
* **Planned Features:**
  * **On-device Sensitive Image Detection (Pornography Filter):** Local neural networks inspecting image bounds in real-time.
  * **Advanced Content Classification:** Local text NLP classification on accessibility text trees.
  * **Auto-Update Layout Registry:** Remote registry server allowing the app to download revised layout node IDs dynamically.
* **Current Confidence Level:** **High.**
* **Finalized or Under Discussion:** **Finalized** (detailed in Phase 6 Blueprints and Phase 5 Discovery Reports).

### Phase 8: Extended Accountability & Emergency Panic Gateway
* **Objective:** Refine partner-gated workflows to support flexibilities without compromising discipline.
* **Planned Philosophy:** Gated exceptions with social costs are better than total lockout frustration.
* **Planned Features:**
  * **OTP Release:** Partner-generated 6-digit PIN unlocks.
  * **Contract Override Requests:** Draft modifications with a 12-hour cooldown and partner approval.
  * **Emergency Access requests:** 1-hour panic button with streak reset penalties.
* **Current Confidence Level:** **Medium.**
* **Finalized or Under Discussion:** **Finalized** (detailed in Phase 5 Discovery Reports).

### Phase 9: Commitment Economy & Custom Analytics
* **Objective:** Drive long-term reflection through numbers, metrics, and economic commitments.
* **Planned Philosophy:** Quantitative feedback and financial stakes build long-term habits.
* **Planned Features:**
  * **Advanced Accountability Digests:** detailed habit reports and weekly summaries for the partner.
  * **Commitment Economy Wallet Integration:** actual SQLite persistence for financial credits and penalty charges.
* **Current Confidence Level:** **Medium-Low.**
* **Finalized or Under Discussion:** **Under Discussion** (due to Google Play financial policy risks).

---

## PART 5 — PRODUCT EVOLUTION

```
Originally (Phase 1-2)
Simple native Android screen time blocker, usage tracker, and keyword ejector.
      │
      ▼
Later (Phase 3)
Commitment Contracts (1-30 days) and a Streak Engine to motivate users via consecutive "green" days, with a local "Borrow Minutes" credit bank.
      │
      ▼
Later (Phase 4)
Monetary wallet postponed. Prioritized "The Vault Layer" focusing on native security (preventing settings bypasses, blocking clock adjustments, and introducing a local 24-hour cooldown gateway).
      │
      ▼
Later (Phase 5)
Vault expanded into "Human Accountability", moving bypass friction from system overlays to social stakes (Cooldown -> Partner Approval -> Grace Window) and adding Firestore backup sync.
      │
      ▼
Later (Phase 6)
AI Protection postponed. Restructured as the "Selective Friction Layer," surgically masking social media infinite scrolls (Reels, Feed, Shorts) while keeping DMs active to prevent lockout fatigue.
      │
      ▼
Today (Current State)
SayNO is a multi-layered Digital Discipline Platform combining native integrity, cloud backup, partner-gating, and selective social media masking.
```

---

## PART 6 — DECISIONS WE MADE

* **Dark-Only Styling:** No light mode. Standardizes design, maintains brand identity, and reduces visual stimulation.
* **Professional, Non-Shaming Tone of Voice:** Use calm language like `"Limit Reached"` or `"Clock Manipulation Detected"` instead of `"Failure"` or `"Cheating."`
* **Decoupled native architecture:** Kotlin accessibility service operates on native configurations independent of the Flutter UI process.
* **Network-validated time:** Using Google HTTP HEAD headers as the single source of truth for clock verification, rejecting device wall clocks.
* **Social friction over technical lockouts:** Admitting OS restrictions make 100% technical lockout impossible, using human relationship stakes as the ultimate barrier.
* **Surgical masking over total lockout:** Preserving DM and search utility on Instagram to prevent lockout fatigue and uninstallation impulses.
* **Virtual credits instead of cash payments:** Postponing billing complexity and app store policy risks.
* **1-to-1 Accountability Links:** Restricting links to a strict 1-to-1 relationship to minimize database and UI complexity.
* **"Release Request" as the single gateway:** Accessibility deactivation, uninstallation, and force stops are completely blocked unless a release request is completed.

---

## PART 7 — REJECTED IDEAS

### 1. Cash-based Monetary Penalties
* **What it was:** Charging the user's credit card actual dollar penalties for contract violations.
* **Why it was rejected:** Google Play financial rules restrict apps from charging penalty fees, and managing deposit balances introduces significant engineering and legal overhead.
* **What replaced it:** Time-based credit bank (`"Borrow Minutes"`) and contract streak resets.

### 2. SMS Gateway Notifications
* **What it was:** Sending verification codes and alerts to partners via text messages.
* **Why it was rejected:** Google Play Store bans non-default messaging apps from requesting `SEND_SMS` permissions. Transactional SMS costs are also high.
* **What replaced it:** Firebase Cloud Messaging (FCM) push notifications.

### 3. Permanent Technical Lockouts
* **What it was:** Attempting to lock users out of their phones or apps permanently without an exit gateway.
* **Why it was rejected:** Android OS constraints make a 100% technical lockout impossible without root access. Users under high stress will find developer bypasses (like ADB), leading to app deletion.
* **What replaced it:** The double-cooldown release request gateway (24h Cooldown -> Partner Approval -> 24h Grace Window).

### 4. Global App-Level Blocking for Instagram
* **What it was:** Ejecting the user from Instagram entirely once their daily limit was reached.
* **Why it was rejected:** Users need Instagram DMs to coordinate meetings, and complete ejections cause high frustration, prompting them to uninstall SayNO.
* **What replaced it:** Viewport-Constrained Feed Masking (blurring the feed viewport while leaving DMs and profile navigation interactive).

---

## PART 8 — CURRENT PRODUCT IDENTITY

SayNO belongs strictly to the category of a **Digital Discipline Platform**.

### Why it is not:
* **A Screen Time Blocker:** Screen blockers are easily bypassed, rely on user motivation to stay enabled, and implement binary app-level lockouts. SayNO enforces system-level settings shields, checks monotonic hardware time drift, and uses selective feed masking.
* **An Accountability App:** Generic accountability apps only report metrics or catalog failures post-facto. SayNO actively intervenes at the native level, gating app settings changes behind a partner-approved double-cooldown release process.
* **A Self-Control App:** Self-control apps rely on motivation. SayNO is built around systems—Commitment Contracts, Time Shields, and Social Friction.

---

## PART 9 — VERSION 1.0

When SayNO launches publicly, users will receive a **Digital Discipline Platform** designed to help them reclaim their attention and build self-control without losing digital connectivity.

* **The Experience:** A low-stimulus, minimalist Dark Theme application with zero promotional spam. Launching restricted apps (Instagram, YouTube) is met with precise feed blurring or immediate Shorts ejections, while direct messages remain accessible.
* **The Philosophy:** **Systems Over Motivation.** Motivation is temporary; systems are permanent. SayNO does not shame or remind the user—it enforces commitment contracts and social accountability rules.
* **The Value Proposition:** Regain focus and eliminate infinite scrolling without losing vital digital utilities or messaging tools.
* **The Transformation:** Transitioning from impulsive, high-dopamine scrolling to structured, partner-supported digital usage.
* **The Competitive Advantage:** Un-bypassable settings shields, clock manipulation blocks, and viewport-constrained selective masking.
* **Target Audience:** High-performance professionals, students, and individuals battling social media addiction or attention fragmentation.

---

## PART 10 — MASTER ROADMAP

### Implemented current phases (Phases 1–6)

| Phase | Status | Objective | Major Features | Finalized? |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 1: Foundation & UI System** | Completed | Establish branding, standard layouts, and custom widgets. | Dark Theme Dashboard, GoRouter navigation, design system. | Yes |
| **Phase 2: Silent Guardian** | Completed | Native background Android monitoring and usage tracking. | Accessibility Service, SQLite usage sync, full-screen Block overlays. | Yes |
| **Phase 3: Contract Engine** | Completed | Commitment contracts, calendar history, and streak metrics. | Contract wizards, calendar screens, "Borrow Minutes" credit bank. | Yes |
| **Phase 4: The Vault Layer** | Completed | Native security hardening and time integrity. | Monotonic Time Drift checking, Settings Interception Shield, local 24h Cooldown. | Yes |
| **Phase 5: Human Accountability** | Completed | Interpersonal social friction and cloud-sync. | Firebase login, partner linking, Cooldown -> Approval -> Grace Window flow. | Yes |
| **Phase 6: Selective Friction Layer** | Completed | Surgical viewport feed masking and Shorts ejections. | Instagram feed masking, YouTube Shorts player ejection, Focus/Utility modes. | Yes |

### Future roadmap

| Future Phase | Objective | Status | Confidence |
| :--- | :--- | :--- | :--- |
| **Phase 7: AI & Layout Resilience** | On-device sensitive image detection and remote layout update registry. | Planned | High |
| **Phase 8: Extended Accountability** | Partner OTP release pins, contract overrides, emergency panic button. | Planned | Medium |
| **Phase 9: Commitment Economy** | Weekly partner summaries, interactive historical charts. | Under Discussion | Medium-Low |
| **Long-Term Vision** | iOS platform support, Personal Growth habit coaching. | Under Discussion | Low |

---

## PART 11 — MEMORY GAPS

The following inconsistencies and conflicting items exist in the project and are reported for alignment:

* **Wallet Screen UI Mockup vs Contract Credit Implementation:** The `WalletScreen` is mocked with dollar transaction tiles (`$10.00`, `$2.50`), whereas the Contract engine defines credits strictly as time-based duration parameters (`remainingCreditsSeconds`, `totalCreditsSeconds`). The database completely lacks transaction tables.
* **Reboot Monotonic Checkpoint Loophole:** The Time Drift Shield compares wall clock deltas against `SystemClock.elapsedRealtime()`. Because this clock resets to 0 on reboot, there is a loophole where a device restart can trigger false clock manipulation locks. A background persistence checker for monotonic time is planned but not implemented.
* **Settings Interception Shield English Locales Dependency:** The Settings Interception check in Kotlin scans accessibility layouts for text labels matching `"Uninstall"`, `"Force Stop"`, and `"Disable"`. If a user changes their device language to a non-English locale, these checks fail, allowing them to bypass the settings shields.
* **Database Alter Migration Paths:** The `release_requests` SQLite schema was modified twice across database upgrades (adding partner approvals and grace window expirations) without standardized unit testing of migration paths.
