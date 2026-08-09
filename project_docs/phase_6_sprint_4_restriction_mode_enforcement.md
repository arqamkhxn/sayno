# Phase 6 — Sprint 4: Restriction Mode Enforcement

## 1. Goal
Implement the multi-mode configuration engine and update the Kotlin Limit Manager and Flutter UI to select and enforce the four modes (Utility, Time Limit, Focus, Monk).

---

## 2. Scope

### Included:
* Integrating the restriction mode selection (Utility, Time Limit, Focus, Monk) into the Flutter contract creation and app limit adjustment dashboards.
* Passing the configured restriction mode via `setAppLimit` on contract activation.
* Extending Kotlin `SayNoLimitManager` to prevent terminating session tracking when the limit is exceeded if the app's mode is set to `utility`.
* Implementing the native logic routing layout overlay choices based on active mode configurations:
  - **Utility Mode**:
    - *Before Limit*: Full access.
    - *After Limit*: Middle viewport mask active; DMs, search query, and profiles open.
  - **Time Limit Mode**:
    - *Before Limit*: Full access.
    - *After Limit*: Fullscreen block overlay active (home gesture ejection).
  - **Focus Mode**:
    - *Always*: Middle viewport mask active; DMs, search query, and profiles open (no daily limit needed).
  - **Monk Mode**:
    - *Before Limit*: Middle viewport mask active (feeds blocked, DMs/search open).
    - *After Limit*: Fullscreen block overlay active (home gesture ejection).

### Explicitly Excluded:
* Browser-based selective blocking.
* Remote templates layout updates.

---

## 3. Files To Create
None.

---

## 4. Files To Modify

### Flutter Code:
* **[contract_creation_screen.dart](file:///d:/sayno-main-phase-1/lib/features/contract/presentation/contract_creation_screen.dart)** (or the limit configuration sheet):
  - Add card-selector or dropdown selection widgets mapping the four `RestrictionMode` options.
  - Send the selected mode string downstream during contract activation.
* **[contract_controller.dart](file:///d:/sayno-main-phase-1/lib/features/contract/application/contract_controller.dart)**:
  - Update initialization triggers to bundle restriction modes with app limits.

### Kotlin Code:
* **[SayNoLimitManager.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoLimitManager.kt)**:
  - Update limit checks: if limit is exceeded in `Utility` mode, trigger the selective viewport overlay but do **not** invoke `stopChecking()` or close the tracking session.
* **[SayNoInterventionManager.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoInterventionManager.kt)**:
  - Select overlay type (splash screen vs viewport mask vs full-screen block lockout screen) based on the package name, restriction mode, and limit status.
* **[SayNoAccessibilityService.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoAccessibilityService.kt)**:
  - Wire up mode checks during window event tree traversals.

---

## 5. Database Changes
None. (Uses SQLite version 9 migration from Sprint 1).

---

## 6. Flutter Changes
* Update the app limit configuration dialog sheets to display selectable restriction modes with clear definitions:
  - **Time Limit**: Broad limit blocking the entire app.
  - **Utility**: Block infinite feeds after limit is reached; keep DMs/Search open.
  - **Focus**: Always block infinite feeds; keep DMs/Search open.
  - **Monk**: Always block infinite feeds; block the entire app after the limit is reached.

---

## 7. Native Android Changes
* Modify `checkLimits()` inside `SayNoLimitManager.kt` to enforce selective overlay triggers without session terminations for utility packages.
* Update `SayNoInterventionManager` to map overlays and perform HOME ejections for monk/time limits.

---

## 8. Acceptance Criteria
* **Utility Mode Limits**: Once limit is exceeded, Instagram feed is blocked, but DMs remain interactive. Time spent inside DMs continues to accumulate in the database.
* **Monk Mode Limits**: Instagram feed is blocked from startup. Once limit is exceeded, DMs are also blocked, and accessing Instagram triggers a HOME ejection.
* **Focus Mode Limits**: Instagram feed is blocked from startup always, even if limit is not exceeded. DM/Search remains interactive.
* **Time Limit Mode**: Behaviors match the standard daily block (Phase 3/4 baseline).

---

## 9. Automated Tests
* Create unit tests verifying that creating a contract correctly persists the selected restriction mode and triggers platform channel updates with valid arguments.

---

## 10. Manual Testing Checklist
1. **Utility Mode Verification**:
   - Set Instagram limit to 1 minute, mode `Utility`.
   - Scroll feed for 1 minute -> confirm the feed viewport blurs/blocks.
   - Click bottom Profile tab and navigate to DMs -> verify these areas are fully interactive and that the timer continues to increment in SharedPreferences.
2. **Monk Mode Verification**:
   - Set Instagram limit to 1 minute, mode `Monk`.
   - Open Instagram -> verify the feed is blocked immediately.
   - Spend 1 minute in DMs -> verify the app is fully blocked and ejections are triggered.
3. **Focus Mode Verification**:
   - Set Instagram mode to `Focus`.
   - Open Instagram -> verify the feed is blocked immediately from launch (with no time limit constraints).

---

## 11. Git Commit Plan
1. **`feat(native): adapt limit checking loop to support continuous tracking in Utility mode`**
2. **`feat(native): enforce selective layouts based on mode configuration definitions`**
3. **`feat(ui): integrate RestrictionMode selector into contract limit setups`**
