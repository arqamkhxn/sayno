# Phase 6 — Sprint 2: Instagram Feed Masking

## 1. Goal
Implement the pre-emptive full-screen splash mask and the viewport-constrained mask overlays on native Android for Instagram, enabling selective blocking of Feed and Reels.

---

## 2. Scope

### Included:
* Drawing an immediate opaque fullscreen overlay window (Splash Mask) on Instagram entry to block the visual feed flash.
* Positioning a viewport-constrained mask (Opaque/Blurred) covering only the middle scrollable feed content.
* Applying pass-through WindowManager flags (`FLAG_NOT_TOUCH_MODAL` and `FLAG_NOT_FOCUSABLE`) to allow touch events to pass to transparent bar headers and bottom navigation tabs.
* Offsetting viewport coordinates according to system insets to handle Status/Navigation bar adjustments.
* Transitions from the Splash Mask to the Viewport Mask once layout scan checks are verified.

### Explicitly Excluded:
* Instagram Explore/Search tab focus masking (Sprint 3).
* YouTube Shorts click/activity ejections (Sprint 3).
* Limit tracking continuation logic (Sprint 4).

---

## 3. Files To Create
None.

---

## 4. Files To Modify

### Kotlin Code:
* **[SayNoOverlayManager.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoOverlayManager.kt)**:
  - Implement `showPreemptiveSplash()` drawing an opaque full-screen view.
  - Implement `showInstagramViewportMask()` constructing a layout with top transparent spacer (~56dp), middle blurred block view, and bottom transparent spacer (~56dp).
  - Configure touch pass-through WindowManager parameters.
* **[SayNoAccessibilityService.kt](file:///d:/sayno-main-phase-1/android/app/src/main/kotlin/com/example/sayno/SayNoAccessibilityService.kt)**:
  - Intercept `TYPE_WINDOW_STATE_CHANGED` transition events for package `com.instagram.android` and display the preemptive splash mask immediately.
  - Transition splash mask to viewport mask after active contract status validation is complete.

---

## 5. Database Changes
None.

---

## 6. Flutter Changes
None.

---

## 7. Native Android Changes
* Add layout templates for selective overlays in native Android module.
* Configure programmatic WindowManager layout configurations with flags:
  ```kotlin
  val params = WindowManager.LayoutParams(
      WindowManager.LayoutParams.MATCH_PARENT,
      WindowManager.LayoutParams.MATCH_PARENT,
      WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
      WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
      PixelFormat.TRANSLUCENT
  )
  ```

---

## 8. Acceptance Criteria
* **Visual Leak Elimination**: Tapping Instagram launcher icon shows the dark splash layout immediately, preventing any feed images from flashing.
* **Middle Feed Blocked**: Scroll feed area of Instagram home is blurred and unscrollable.
* **Frictionless Utilities**: Top Direct Messages icon and bottom search/profile buttons remain fully interactive and click-accessible.

---

## 9. Automated Tests
None. (Layout rendering behaviors are validated manually).

---

## 10. Manual Testing Checklist
1. **App Entry Flash Check**:
   - Cold launch Instagram app. Confirm the dark splash screen displays immediately (within ~10ms–30ms).
2. **Selective Viewport Test**:
   - Confirm that the middle feed is blocked.
   - Tap the bottom Profile tab -> verify you transition to the Profile page and it is unblocked.
   - Tap the top-right DM icon -> verify you open Direct Messages successfully.

---

## 11. Git Commit Plan
1. **`feat(native): implement full-screen preemptive splash mask in OverlayManager`**
2. **`feat(native): build viewport-constrained layout with pass-through flags`**
3. **`feat(native): trigger splash-to-viewport mask updates on Instagram package launches`**
