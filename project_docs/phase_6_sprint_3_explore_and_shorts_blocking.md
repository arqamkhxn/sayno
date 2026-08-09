# Phase 6 — Sprint 3: Explore & Shorts Blocking

## 1. Goal
Implement state-aware Explore grid masking on Instagram based on keyboard/search focus, and eradicate YouTube Shorts using a dual-gate click interception and fail-safe activity ejection system.

---

## 2. Scope

### Included:
* Masking the infinite Explore grid beneath Instagram's top search bar.
* Listening for focus accessibility events (`TYPE_VIEW_FOCUSED` / `TYPE_VIEW_CLICKED`) on search text inputs inside Instagram to temporarily hide the Explore mask.
* Re-applying the Explore mask as soon as search bar focus is lost (keyboard dismissed, search cleared).
* Intercepting clicks on YouTube "Shorts" bottom navigation tabs and horizontal Shorts shelves on the Home Feed.
* Implementing a native check on window transitions to scan class names for `ShortsActivity` or Shorts player hierarchies.
* Triggering a native `GLOBAL_ACTION_BACK` gesture immediately if YouTube Shorts are loaded.

### Explicitly Excluded:
* Restructuring limit session updates (Sprint 4).
* Restriction mode configuration widgets in Flutter (Sprint 4).

---

## 3. Files To Create
None.

---

## 4. Files To Modify

### Kotlin Code:
* **[SayNoAccessibilityService.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoAccessibilityService.kt)**:
  - In `onAccessibilityEvent()`, monitor focus changes on `android.widget.EditText` search bars inside Instagram. Toggle Explore overlay visibility.
  - Monitor class transitions to YouTube Shorts activity wrapper (`com.google.android.apps.youtube.app.extensions.shorts.viewer.ShortsActivity`) or node descriptors ("Shorts player").
  - Execute `performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)` on Shorts detection.
* **[SayNoOverlayManager.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoOverlayManager.kt)**:
  - Implement `showInstagramExploreMask()` and focus toggle methods.

---

## 5. Database Changes
None.

---

## 6. Flutter Changes
None.

---

## 7. Native Android Changes
* Add YouTube Shorts class detection filters.
* Monitor focus events in accessibility controller loops:
  ```kotlin
  if (event.eventType == AccessibilityEvent.TYPE_VIEW_FOCUSED && event.className == "android.widget.EditText") {
      overlayManager.hideExploreMask()
  }
  ```

---

## 8. Acceptance Criteria
* **Instagram Explore Blocked**: Explore grid remains blurred by default.
* **Functional Search query**: Focusing the search input successfully reveals the keyboard and removes the blur. Dismissing search restores the blur immediately.
* **Shorts Interception**: Tapping "Shorts" navigation or horizontal Shorts shelves returns the user to the feed immediately.
* **Shorts Deep-Link Guard**: Opening a Shorts player activity via direct links triggers a back gesture and ejects the user.

---

## 9. Automated Tests
None. (Dynamic layout traversal is validated manually).

---

## 10. Manual Testing Checklist
1. **Explore Grid Focus Masking**:
   - Go to Search tab in Instagram. Verify Explore grid content is masked.
   - Tap the top search input bar -> confirm the overlay hides, allowing search typing.
   - Dismiss search -> verify the grid mask is instantly re-applied.
2. **YouTube Shorts Click Guard**:
   - Open YouTube app. Tap the "Shorts" navigation tab.
   - Verify you are immediately returned to the home screen with a warning toast.
3. **YouTube Shorts Deep-Link Guard**:
   - Click a Shorts link from a browser or messaging app.
   - Verify that the player activity opens and is instantly closed by a BACK gesture.

---

## 11. Git Commit Plan
1. **`feat(native): track EditText search focus to show/hide Explore grid mask in Instagram`**
2. **`feat(native): build dual-gate click and activity interception for YouTube Shorts`**
3. **`feat(native): trigger BACK gesture ejections on Shorts Activity load`**
