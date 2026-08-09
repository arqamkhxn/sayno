package com.sayno.app

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.util.Log

class SayNoInterventionManager(
    private val service: SayNoAccessibilityService,
    private val overlayManager: SayNoOverlayManager
) {
    private val handler = Handler(Looper.getMainLooper())
    private var isInterventionInProgress = false

    fun startRestrictedContentIntervention(packageName: String) {
        if (isInterventionInProgress || overlayManager.isOverlayShowing()) {
            return
        }

        isInterventionInProgress = true
        // Phase 1: BACK
        executeBackAttempt(1, packageName)
    }

    fun startDailyLimitIntervention(packageName: String) {
        val mode = service.configManager.getRestrictionMode(packageName)
        if (mode == "utility" || mode == "focus") {
            // For utility/focus mode, we do NOT show the full-screen block overlay.
            // Selective friction masking overlays are drawn dynamically instead.
            val eventData = mapOf(
                "type" to "limit_reached",
                "packageName" to packageName,
                "timestamp" to System.currentTimeMillis()
            )
            SayNoAccessibilityService.listener?.invoke(eventData)
            return
        }

        if (isInterventionInProgress || overlayManager.isOverlayShowing()) {
            return
        }
        isInterventionInProgress = true
        
        // Phase 7 Replacement Engine: Auto-launch Gateway for Monk/Time Limit modes
        val intent = android.content.Intent("android.intent.action.VIEW").apply {
            data = android.net.Uri.parse("sayno://replacement/gateway")
            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        try {
            service.startActivity(intent)
        } catch (e: Exception) {
            Log.e("SayNoInterventionManager", "Failed to launch Replacement Gateway", e)
            overlayManager.showOverlay("This application has been blocked by SayNO due to daily limit restrictions.")
        }
        
        val eventData = mapOf(
            "type" to "limit_reached",
            "packageName" to packageName,
            "timestamp" to System.currentTimeMillis()
        )
        SayNoAccessibilityService.listener?.invoke(eventData)

        isInterventionInProgress = false
    }

    fun startLimitReachedIntervention(packageName: String) {
        startDailyLimitIntervention(packageName)
    }

    fun startSettingsLockoutIntervention(reason: String = "Your contract is currently active. To remove protection, start a Release Request.") {
        if (isInterventionInProgress || overlayManager.isOverlayShowing()) {
            return
        }

        isInterventionInProgress = true
        // Show native overlay immediately
        overlayManager.showOverlay(reason)

        // Eject the user by performing BACK or HOME action
        val success = service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
        if (!success) {
            service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
        }
        isInterventionInProgress = false
    }

    private fun executeBackAttempt(attempt: Int, packageName: String) {
        val success = service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
        if (!success) {
            // Fallback: HOME -> Replacement Gateway
            service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
            
            val intent = android.content.Intent("android.intent.action.VIEW").apply {
                data = android.net.Uri.parse("sayno://replacement/gateway")
                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            try {
                service.startActivity(intent)
            } catch (e: Exception) {
                overlayManager.showOverlay("This application has been blocked by SayNO due to restricted content.")
            }
            isInterventionInProgress = false
            return
        }

        // Wait 250ms, then rescan
        handler.postDelayed({
            val stillRestricted = service.performKeywordScan(packageName)
            if (stillRestricted) {
                if (attempt < 2) {
                    executeBackAttempt(attempt + 1, packageName)
                } else {
                    // Still restricted after max attempts: show Gateway
                    val intent = android.content.Intent("android.intent.action.VIEW").apply {
                        data = android.net.Uri.parse("sayno://replacement/gateway")
                        addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
                    try {
                        service.startActivity(intent)
                    } catch (e: Exception) {
                        overlayManager.showOverlay("This application has been blocked by SayNO due to restricted content.")
                    }
                    isInterventionInProgress = false
                }
            } else {
                isInterventionInProgress = false
            }
        }, 250L)
    }

    fun resetInterventionState() {
        isInterventionInProgress = false
        overlayManager.hideOverlay()
    }
}
