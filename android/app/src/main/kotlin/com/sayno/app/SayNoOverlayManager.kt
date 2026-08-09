package com.sayno.app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.TextView

class SayNoOverlayManager(private val service: AccessibilityService) {

    private val windowManager: WindowManager = service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var overlayView: View? = null
    private var splashView: View? = null
    private var viewportMaskView: View? = null

    // -----------------------------------------------------------------------
    // Preemptive full-screen splash mask (Phase 6 Sprint 2)
    // Shown immediately when a monitored app (e.g. Instagram) is launched to
    // prevent the feed from visually flashing before the viewport mask renders.
    // -----------------------------------------------------------------------

    fun showPreemptiveSplash() {
        if (splashView != null) return

        val splash = View(service).apply {
            setBackgroundColor(Color.parseColor("#1A1A2E"))
        }
        splashView = splash

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.OPAQUE
        ).apply {
            gravity = Gravity.TOP
        }

        try {
            windowManager.addView(splash, params)
            Log.d("SayNoOverlayManager", "Preemptive splash shown.")
        } catch (e: Exception) {
            Log.e("SayNoOverlayManager", "Failed to show preemptive splash", e)
            splashView = null
        }
    }

    fun hideSplash() {
        val view = splashView ?: return
        try {
            windowManager.removeView(view)
        } catch (e: Exception) {
            Log.e("SayNoOverlayManager", "Failed to remove splash view", e)
        } finally {
            splashView = null
        }
    }

    // -----------------------------------------------------------------------
    // Viewport-constrained Instagram feed mask (Phase 6 Sprint 2)
    // Blocks only the scrollable middle feed area while leaving the status
    // bar, top action bar, and bottom navigation bar fully interactive.
    //
    // Layout structure:
    //   [ transparent top spacer  ~56dp  ]  ← status bar + action bar
    //   [ blurred/opaque mask view        ]  ← BLOCKED feed scroll area
    //   [ transparent bottom spacer ~56dp ]  ← bottom navigation bar
    //
    // FLAG_NOT_TOUCH_MODAL + FLAG_NOT_FOCUSABLE = touch events pass through
    // transparent regions to the underlying app view hierarchy.
    // -----------------------------------------------------------------------

    fun showInstagramViewportMask() {
        if (viewportMaskView != null) return

        val density = service.resources.displayMetrics.density
        val topSpacerDp = 56
        val bottomSpacerDp = 56
        val topPx = (topSpacerDp * density).toInt()
        val bottomPx = (bottomSpacerDp * density).toInt()

        // Root frame: full-screen, transparent background.
        val root = FrameLayout(service).apply {
            setBackgroundColor(Color.TRANSPARENT)
        }

        // Middle blurred mask that occupies all vertical space between the
        // top and bottom transparent spacers.
        val feedMask = View(service).apply {
            setBackgroundColor(Color.parseColor("#E81A1A2E"))  // ~91% opaque dark overlay
        }

        val maskParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ).apply {
            setMargins(0, topPx, 0, bottomPx)
        }
        root.addView(feedMask, maskParams)
        
        // Phase 7: Opt-in Gateway button for Utility/Focus mode
        val optInButton = Button(service).apply {
            text = "Open Intentional Content"
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#4CAF50"))
            setPadding(32, 16, 32, 16)
            setOnClickListener {
                hideViewportMask()
                val intent = android.content.Intent("android.intent.action.VIEW").apply {
                    data = android.net.Uri.parse("sayno://replacement/gateway")
                    addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                try {
                    service.startActivity(intent)
                } catch (e: Exception) {
                    Log.e("SayNoOverlayManager", "Failed to launch Gateway from Viewport Mask", e)
                }
            }
        }
        val btnParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
        }
        root.addView(optInButton, btnParams)
        
        viewportMaskView = root

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP
        }

        try {
            windowManager.addView(root, params)
            Log.d("SayNoOverlayManager", "Instagram viewport mask shown.")
        } catch (e: Exception) {
            Log.e("SayNoOverlayManager", "Failed to show Instagram viewport mask", e)
            viewportMaskView = null
        }
    }

    fun hideViewportMask() {
        val view = viewportMaskView ?: return
        try {
            windowManager.removeView(view)
        } catch (e: Exception) {
            Log.e("SayNoOverlayManager", "Failed to remove viewport mask", e)
        } finally {
            viewportMaskView = null
        }
    }

    fun isViewportMaskShowing(): Boolean = viewportMaskView != null

    private var exploreMaskView: View? = null

    // -----------------------------------------------------------------------
    // State-aware Instagram Explore grid mask (Phase 6 Sprint 3)
    // Masks the infinite Explore grid content while leaving the top search
    // bar and bottom navigation bar interactive.
    // -----------------------------------------------------------------------

    fun showInstagramExploreMask() {
        if (exploreMaskView != null) return

        val density = service.resources.displayMetrics.density
        val topSpacerDp = 56
        val bottomSpacerDp = 56
        val topPx = (topSpacerDp * density).toInt()
        val bottomPx = (bottomSpacerDp * density).toInt()

        val root = FrameLayout(service).apply {
            setBackgroundColor(Color.TRANSPARENT)
        }

        val exploreMask = View(service).apply {
            setBackgroundColor(Color.parseColor("#E81A1A2E")) // blurred/opaque dark overlay
        }

        val maskParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ).apply {
            setMargins(0, topPx, 0, bottomPx)
        }
        root.addView(exploreMask, maskParams)
        
        // Phase 7: Opt-in Gateway button for Explore mask
        val optInButton = Button(service).apply {
            text = "Open Intentional Content"
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#4CAF50"))
            setPadding(32, 16, 32, 16)
            setOnClickListener {
                hideExploreMask()
                val intent = android.content.Intent("android.intent.action.VIEW").apply {
                    data = android.net.Uri.parse("sayno://replacement/gateway")
                    addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                try {
                    service.startActivity(intent)
                } catch (e: Exception) {
                    Log.e("SayNoOverlayManager", "Failed to launch Gateway from Explore Mask", e)
                }
            }
        }
        val btnParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
        }
        root.addView(optInButton, btnParams)
        
        exploreMaskView = root

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP
        }

        try {
            windowManager.addView(root, params)
            Log.d("SayNoOverlayManager", "Instagram Explore mask shown.")
        } catch (e: Exception) {
            Log.e("SayNoOverlayManager", "Failed to show Instagram Explore mask", e)
            exploreMaskView = null
        }
    }

    fun hideExploreMask() {
        val view = exploreMaskView ?: return
        try {
            windowManager.removeView(view)
        } catch (e: Exception) {
            Log.e("SayNoOverlayManager", "Failed to remove Explore mask", e)
        } finally {
            exploreMaskView = null
        }
    }

    fun isExploreMaskShowing(): Boolean = exploreMaskView != null

    fun showOverlay(reason: String) {
        if (overlayView != null) {
            updateReason(reason)
            return
        }

        val inflater = LayoutInflater.from(service)
        try {
            overlayView = inflater.inflate(R.layout.block_overlay_layout, null)
        } catch (e: Exception) {
            Log.e("SAYNO_DEBUG", "Error inflating native block overlay layout", e)
            return
        }

        val view = overlayView ?: return

        updateReason(reason)

        val btnGoBack = view.findViewById<Button>(R.id.btn_go_back)
        val btnClose = view.findViewById<Button>(R.id.btn_close)

        btnGoBack?.setOnClickListener {
            hideOverlay()
            service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
        }

        btnClose?.setOnClickListener {
            hideOverlay()
            service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
        }

        try {
            windowManager.addView(view, params)
        } catch (e: Exception) {
            Log.e("SAYNO_DEBUG", "Failed to add native block overlay window", e)
            overlayView = null
        }
    }

    fun hideOverlay() {
        val view = overlayView ?: return
        try {
            windowManager.removeView(view)
        } catch (e: Exception) {
            Log.e("SAYNO_DEBUG", "Failed to remove native block overlay window", e)
        } finally {
            overlayView = null
        }
    }

    fun isOverlayShowing(): Boolean {
        return overlayView != null
    }

    private fun updateReason(reason: String) {
        val view = overlayView ?: return
        val messageView = view.findViewById<TextView>(R.id.block_message)
        messageView?.text = reason
    }
}
