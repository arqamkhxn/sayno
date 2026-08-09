package com.sayno.app

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class SayNoAccessibilityService : AccessibilityService() {

    companion object {
        @JvmStatic
        @Volatile
        var instance: SayNoAccessibilityService? = null

        @JvmStatic
        var listener: ((Map<String, Any?>) -> Unit)? = null

        // Phase 6 Sprint 2: Instagram feed masking constants
        const val INSTAGRAM_PACKAGE = "com.instagram.android"
        // Delay between preemptive splash and viewport mask swap (ms).
        const val SPLASH_TO_MASK_DELAY_MS = 200L
    }

    private var lastActivePackage: String? = null
    val configManager by lazy { SayNoConfigManager(this) }
    val overlayManager by lazy { SayNoOverlayManager(this) }
    private val interventionManager by lazy { SayNoInterventionManager(this, overlayManager) }
    val limitManager by lazy { SayNoLimitManager(this, configManager, interventionManager) }

    // Handler for Instagram splash → viewport mask transition (Phase 6 Sprint 2)
    private val maskHandler = Handler(Looper.getMainLooper())

    // Handler and Runnable for dynamic, state-aware selective friction scans (Phase 6 Sprint 3)
    private val selectiveFrictionHandler = Handler(Looper.getMainLooper())
    private val selectiveFrictionRunnable = Runnable {
        val pkg = lastActivePackage ?: return@Runnable
        if (!isSelectiveFrictionActive(pkg)) {
            // Cleanup if no longer active
            overlayManager.hideSplash()
            overlayManager.hideViewportMask()
            overlayManager.hideExploreMask()
            return@Runnable
        }

        val rootNode = rootInActiveWindow ?: return@Runnable
        try {
            if (pkg == INSTAGRAM_PACKAGE) {
                scanInstagramScreenState(rootNode)
            } else if (pkg == "com.google.android.youtube") {
                scanYouTubeScreenState(rootNode)
            }
        } finally {
            rootNode.recycle()
        }
    }

    fun triggerSelectiveFrictionCheck() {
        selectiveFrictionHandler.removeCallbacks(selectiveFrictionRunnable)
        selectiveFrictionHandler.postDelayed(selectiveFrictionRunnable, 50L)
    }

    fun isSelectiveFrictionActive(packageName: String): Boolean {
        if (!configManager.isActiveContract() || configManager.isReleaseAuthorized()) {
            return false
        }
        val mode = configManager.getRestrictionMode(packageName)
        return when (mode) {
            "focus", "monk" -> true
            "utility" -> {
                val limit = configManager.getAppLimit(packageName)
                val usage = limitManager.getUsage(packageName)
                limit != -1L && usage >= limit
            }
            else -> false
        }
    }

    // Handler for debouncing content-change scan events (500ms delay)
    private val scanHandler = Handler(Looper.getMainLooper())
    private var pendingScanPackage: String? = null
    private var firstPendingEventTime: Long = 0L
    private val maxScanDelayMs = 1000L

    private val timeValidationHandler = Handler(Looper.getMainLooper())
    private val timeValidationRunnable = object : Runnable {
        override fun run() {
            performTimeDriftCheck()
            timeValidationHandler.postDelayed(this, 10000L) // check every 10 seconds
        }
    }

    private fun startTimeValidationLoop() {
        timeValidationHandler.removeCallbacks(timeValidationRunnable)
        timeValidationHandler.post(timeValidationRunnable)
    }

    private fun stopTimeValidationLoop() {
        timeValidationHandler.removeCallbacks(timeValidationRunnable)
    }

    private fun performTimeDriftCheck() {
        val isActive = configManager.isActiveContract()
        
        val monotonicOffsetBase = configManager.getMonotonicOffsetBase()
        val lastWall = configManager.getLastWallClockTimestamp()
        val lastMonotonic = configManager.getAccumulatedMonotonicTime()
        
        val currentMonotonic = android.os.SystemClock.elapsedRealtime()
        val calculatedAccumulatedMonotonic = currentMonotonic + monotonicOffsetBase
        val currentWall = System.currentTimeMillis()

        val offsetPrefs = getSharedPreferences("sayno_monotonic_offset", android.content.Context.MODE_PRIVATE)
        val bootTimeRollbackDetected = offsetPrefs.getBoolean("clock_manipulated_flag", false)

        if (isActive && bootTimeRollbackDetected) {
            Log.w("SayNoAccessibilityService", "Clock manipulation flag is active! Showing overlay.")
            overlayManager.showOverlay("SayNO Protection Active: System clock manipulation detected. Protection is locked.")
            val eventData = mapOf(
                "type" to "clock_manipulation",
                "timestamp" to System.currentTimeMillis()
            )
            listener?.invoke(eventData)
            return
        }

        if (lastWall == 0L || lastMonotonic == 0L) {
            configManager.saveAccumulatedMonotonicTime(calculatedAccumulatedMonotonic)
            configManager.saveLastWallClockTimestamp(currentWall)
            return
        }

        val elapsedWallMs = currentWall - lastWall
        val elapsedMonotonicMs = calculatedAccumulatedMonotonic - lastMonotonic
        val drift = Math.abs(elapsedWallMs - elapsedMonotonicMs)

        if (isActive) {
            if (elapsedWallMs < -30000L || drift > 30000L) {
                Log.w("SayNoAccessibilityService", "Time drift manipulation detected! Wall elapsed: $elapsedWallMs, Monotonic elapsed: $elapsedMonotonicMs")
                overlayManager.showOverlay("SayNO Protection Active: System clock manipulation detected. Protection is locked.")
                offsetPrefs.edit().putBoolean("clock_manipulated_flag", true).apply()
                val eventData = mapOf(
                    "type" to "clock_manipulation",
                    "timestamp" to System.currentTimeMillis()
                )
                listener?.invoke(eventData)
                return
            }
        }

        configManager.saveAccumulatedMonotonicTime(calculatedAccumulatedMonotonic)
        configManager.saveLastWallClockTimestamp(currentWall)
    }

    private val scanRunnable = Runnable {
        val pkg = pendingScanPackage ?: return@Runnable
        firstPendingEventTime = 0L
        val restricted = performKeywordScan(pkg)
        if (restricted) {
            interventionManager.startRestrictedContentIntervention(pkg)
        }
    }

    private val screenReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: android.content.Context?, intent: android.content.Intent?) {
            val action = intent?.action ?: return
            val eventData = when (action) {
                android.content.Intent.ACTION_SCREEN_OFF -> mapOf("type" to "screen_off")
                android.content.Intent.ACTION_SCREEN_ON -> {
                    val km = getSystemService(android.content.Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
                    mapOf(
                        "type" to "screen_on",
                        "isLocked" to km.isKeyguardLocked
                    )
                }
                android.content.Intent.ACTION_USER_PRESENT -> mapOf("type" to "device_unlocked")
                else -> null
            }
            eventData?.let { data ->
                listener?.invoke(data)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        val filter = android.content.IntentFilter().apply {
            addAction(android.content.Intent.ACTION_SCREEN_OFF)
            addAction(android.content.Intent.ACTION_SCREEN_ON)
            addAction(android.content.Intent.ACTION_USER_PRESENT)
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, filter, android.content.Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screenReceiver, filter)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this

        // Auto-reattach the listener if MainActivity is alive
        MainActivity.instance?.let { activity ->
            listener = { eventData ->
                activity.dispatchEvent("onAccessibilityEvent", eventData)
            }
        }

        val eventData = mapOf(
            "type" to "protection_enabled"
        )
        listener?.invoke(eventData)

        startTimeValidationLoop()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val eventPackage = event.packageName?.toString()
        if (configManager.isActiveContract() && !configManager.isReleaseAuthorized() && isSettingsOrInstaller(eventPackage)) {
            val eventType = event.eventType
            if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
                eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            ) {
                performSettingsBypassScan()
            }
        }

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                val packageName = event.packageName?.toString() ?: return

                // Filter out internal system package events
                if (packageName == "android" || packageName == "com.android.systemui") {
                    return
                }

                if (packageName != lastActivePackage) {
                    limitManager.endSession()

                    // --- Phase 6 Sprint 2: Viewport Mask Teardown ---
                    // If we are *leaving* Instagram, dismantle any active feed masks.
                    if (lastActivePackage == INSTAGRAM_PACKAGE) {
                        maskHandler.removeCallbacksAndMessages(null)
                        selectiveFrictionHandler.removeCallbacks(selectiveFrictionRunnable)
                        overlayManager.hideSplash()
                        overlayManager.hideViewportMask()
                        overlayManager.hideExploreMask()
                        Log.d("SayNoAccessibilityService", "Left Instagram — feed and explore masks removed.")
                    }

                    lastActivePackage = packageName

                    // Hide native overlay and reset state if leaving blocked/monitored apps
                    if (packageName != "com.sayno.app" && !configManager.getMonitoredPackages().contains(packageName)) {
                        interventionManager.resetInterventionState()
                    }

                    val activeMonitoredPackage = if (configManager.getMonitoredPackages().contains(packageName)) {
                        packageName
                    } else {
                        null
                    }

                    if (activeMonitoredPackage != null) {
                        limitManager.startSession(activeMonitoredPackage)
                    }

                    val eventData = mapOf(
                        "type" to "app_change",
                        "packageName" to activeMonitoredPackage
                    )
                    listener?.invoke(eventData)

                    // Cancel any pending scan when the foreground app changes
                    scanHandler.removeCallbacks(scanRunnable)
                    pendingScanPackage = null
                    firstPendingEventTime = 0L

                    // Trigger an immediate scan if the new app is high-risk
                    if (configManager.getHighRiskPackages().contains(packageName)) {
                        pendingScanPackage = packageName
                        scanHandler.postDelayed(scanRunnable, 150L)
                    }

                    // --- Phase 6 Sprint 2: Instagram feed masking ---
                    if (packageName == INSTAGRAM_PACKAGE && isSelectiveFrictionActive(packageName)) {
                        overlayManager.showPreemptiveSplash()
                        Log.d("SayNoAccessibilityService", "Instagram opened — preemptive splash shown.")

                        maskHandler.postDelayed({
                            if (lastActivePackage == INSTAGRAM_PACKAGE) {
                                overlayManager.hideSplash()
                                // Run layout scan to determine correct starting mask (Feed/Explore/None)
                                triggerSelectiveFrictionCheck()
                            }
                        }, SPLASH_TO_MASK_DELAY_MS)
                    }

                    // YouTube Shorts Activity fail-safe ejection (Phase 6 Sprint 3)
                    if (packageName == "com.google.android.youtube" && isSelectiveFrictionActive(packageName)) {
                        val className = event.className?.toString() ?: ""
                        if (className.contains("ShortsActivity") || className.contains("ShortsViewer") || className.contains("ShortsPlayer")) {
                            Log.d("SayNoAccessibilityService", "YouTube Shorts Activity detected ($className). Ejecting...")
                            performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
                        }
                    }
                }
            }

            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                val packageName = event.packageName?.toString() ?: return

                if (isSelectiveFrictionActive(packageName)) {
                    triggerSelectiveFrictionCheck()
                }

                // Only schedule a scan for high-risk packages
                if (!configManager.getHighRiskPackages().contains(packageName)) return

                val now = System.currentTimeMillis()
                if (firstPendingEventTime == 0L) {
                    firstPendingEventTime = now
                }

                val timeSinceFirst = now - firstPendingEventTime
                if (timeSinceFirst >= maxScanDelayMs) {
                    // Force an immediate scan
                    scanHandler.removeCallbacks(scanRunnable)
                    pendingScanPackage = packageName
                    scanRunnable.run()
                } else {
                    // Debounce: reset the 150ms window on every content-change event
                    scanHandler.removeCallbacks(scanRunnable)
                    pendingScanPackage = packageName
                    scanHandler.postDelayed(scanRunnable, 150L)
                }
            }

            AccessibilityEvent.TYPE_VIEW_FOCUSED -> {
                val packageName = event.packageName?.toString() ?: return
                if (isSelectiveFrictionActive(packageName)) {
                    triggerSelectiveFrictionCheck()
                }
            }

            AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                val packageName = event.packageName?.toString() ?: return
                if (isSelectiveFrictionActive(packageName)) {
                    val source = event.source
                    val desc = source?.contentDescription?.toString()?.lowercase() ?: ""
                    val text = source?.text?.toString()?.lowercase() ?: ""

                    if (packageName == INSTAGRAM_PACKAGE) {
                        if (desc.contains("reels") || text.contains("reels")) {
                            Log.d("SayNoAccessibilityService", "Instagram Reels tab clicked. Ejecting...")
                            performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
                        }
                    } else if (packageName == "com.google.android.youtube") {
                        if (desc == "shorts" || text == "shorts") {
                            Log.d("SayNoAccessibilityService", "YouTube Shorts tab clicked. Ejecting...")
                            performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
                        }
                    }
                    source?.recycle()
                    triggerSelectiveFrictionCheck()
                }
            }
        }
    }

    private fun isSettingsOrInstaller(packageName: String?): Boolean {
        if (packageName == null) return false
        val lower = packageName.lowercase()
        return lower.contains("settings") || 
               lower.contains("packageinstaller") || 
               lower.contains("installer") ||
               lower == "com.android.vending"
    }

    private class BypassScanResult {
        var containsSayNo: Boolean = false
        var containsBypassTrigger: Boolean = false
    }

    private fun performSettingsBypassScan() {
        val rootNode = rootInActiveWindow ?: return
        try {
            val result = BypassScanResult()
            scanNodeForBypass(rootNode, result)
            if (result.containsSayNo && result.containsBypassTrigger) {
                Log.w("SayNoAccessibilityService", "Bypass attempt detected! SayNo found on screen with bypass controls.")
                interventionManager.startSettingsLockoutIntervention()
                val eventData = mapOf(
                    "type" to "settings_bypass",
                    "packageName" to rootNode.packageName?.toString(),
                    "timestamp" to System.currentTimeMillis()
                )
                listener?.invoke(eventData)
            }
        } finally {
            rootNode.recycle()
        }
    }

    private fun scanNodeForBypass(node: AccessibilityNodeInfo?, result: BypassScanResult) {
        if (node == null) return

        val text = node.text?.toString()
        val desc = node.contentDescription?.toString()
        val viewId = node.viewIdResourceName

        if (text != null && text.contains("sayno", ignoreCase = true)) {
            result.containsSayNo = true
        }
        if (desc != null && desc.contains("sayno", ignoreCase = true)) {
            result.containsSayNo = true
        }

        if (viewId != null) {
            val lowerViewId = viewId.lowercase()
            if (lowerViewId == "com.android.settings:id/force_stop_button" ||
                lowerViewId == "com.android.settings:id/uninstall_button" ||
                lowerViewId == "com.android.settings:id/switch_widget" ||
                lowerViewId == "android:id/switch_widget" ||
                lowerViewId == "com.android.settings:id/button1" ||
                lowerViewId == "android:id/button1" ||
                lowerViewId.contains("force_stop") ||
                lowerViewId.contains("uninstall") ||
                lowerViewId.contains("switch_widget") ||
                lowerViewId.contains("packageinstaller")
            ) {
                result.containsBypassTrigger = true
            }
        }

        val textLower = text?.lowercase()
        val descLower = desc?.lowercase()
        val bypassKeywords = listOf(
            "uninstall", "desinstalar",
            "force stop", "forzar detención", "forzar parada",
            "disable", "desactivar"
        )
        for (kw in bypassKeywords) {
            if ((textLower != null && textLower.contains(kw)) || (descLower != null && descLower.contains(kw))) {
                result.containsBypassTrigger = true
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            scanNodeForBypass(child, result)
            child.recycle()
        }
    }

    // -----------------------------------------------------------------------
    // Keyword scanning (runs on main thread via Handler)
    // -----------------------------------------------------------------------

    /// Traverses the active window's node tree, extracts all visible text,
    /// matches it against the keyword list, and dispatches a structured result
    /// to the Flutter listener — without ever sending raw text across the bridge.
    fun performKeywordScan(packageName: String): Boolean {
        val startTime = System.currentTimeMillis()
        val rootNode = rootInActiveWindow ?: run {
            return false
        }

        try {
            val textList = mutableListOf<String>()
            val nodeCount = IntArray(1)
            extractText(rootNode, textList, nodeCount)

            val combined = textList.joinToString(" ").lowercase()
            val matched = mutableListOf<String>()

            for (keyword in configManager.getKeywords()) {
                if (combined.contains(keyword.lowercase())) {
                    matched.add(keyword)
                }
            }

            val eventData: Map<String, Any?> = mapOf(
                "type" to "content_scan",
                "packageName" to packageName,
                "restrictedContentDetected" to matched.isNotEmpty(),
                "matchedKeywords" to matched,
                "timestamp" to System.currentTimeMillis()
            )
            listener?.invoke(eventData)

            return matched.isNotEmpty()
        } finally {
            rootNode.recycle()
        }
    }

    /// Recursively extracts visible text and content descriptions from an
    /// AccessibilityNodeInfo tree. Child nodes are recycled after processing
    /// to prevent system-level memory leaks.
    private fun extractText(node: AccessibilityNodeInfo?, textList: MutableList<String>, nodeCount: IntArray) {
        if (node == null) return
        nodeCount[0]++

        if (node.isVisibleToUser) {
            node.text?.toString()?.takeIf { it.isNotBlank() }?.let { textList.add(it) }
            node.contentDescription?.toString()?.takeIf { it.isNotBlank() }?.let { textList.add(it) }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            extractText(child, textList, nodeCount)
            child.recycle()
        }
    }

    // -----------------------------------------------------------------------

    override fun onInterrupt() {
        scanHandler.removeCallbacks(scanRunnable)
        maskHandler.removeCallbacksAndMessages(null)
        selectiveFrictionHandler.removeCallbacks(selectiveFrictionRunnable)
    }

    override fun onDestroy() {
        stopTimeValidationLoop()
        limitManager.endSession()
        instance = null
        scanHandler.removeCallbacks(scanRunnable)
        maskHandler.removeCallbacksAndMessages(null)
        selectiveFrictionHandler.removeCallbacks(selectiveFrictionRunnable)
        overlayManager.hideSplash()
        overlayManager.hideViewportMask()
        overlayManager.hideExploreMask()
        val eventData = mapOf(
            "type" to "protection_disabled"
        )
        listener?.invoke(eventData)
        listener = null
        try {
            unregisterReceiver(screenReceiver)
        } catch (e: Exception) {
            // Ignore if not registered
        }
        super.onDestroy()
    }

    // -----------------------------------------------------------------------
    // Instagram layout scanning state structure (Phase 6 Sprint 3)
    // -----------------------------------------------------------------------

    private class InstagramScanner {
        var isReelsTabSelected = false
        var isSearchTabSelected = false
        var isHomeTabSelected = false
        var isProfileTabSelected = false
        var isSearchFocused = false
        
        var hasReelsElements = false
        var hasExploreGrid = false
        var hasHomeFeedElements = false
        var isDmScreen = false
        var isStoryComposer = false
        var hasBottomNavigation = false
    }

    private fun scanInstagramScreenState(rootNode: AccessibilityNodeInfo) {
        val scanner = InstagramScanner()
        traverseInstagramTree(rootNode, scanner)

        if (scanner.isReelsTabSelected || scanner.hasReelsElements) {
            Log.d("SayNoAccessibilityService", "Instagram Reels detected. Ejecting...")
            performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
            overlayManager.hideSplash()
            overlayManager.hideViewportMask()
            overlayManager.hideExploreMask()
            return
        }

        if (scanner.isSearchTabSelected) {
            overlayManager.hideSplash()
            overlayManager.hideViewportMask()
            if (scanner.isSearchFocused) {
                overlayManager.hideExploreMask()
            } else {
                overlayManager.showInstagramExploreMask()
            }
            return
        }

        if (scanner.isHomeTabSelected) {
            overlayManager.hideSplash()
            overlayManager.hideExploreMask()
            overlayManager.showInstagramViewportMask()
            return
        }

        // If bottom navigation is present, check if we are on Profile
        if (scanner.hasBottomNavigation) {
            if (scanner.isProfileTabSelected) {
                overlayManager.hideSplash()
                overlayManager.hideViewportMask()
                overlayManager.hideExploreMask()
                return
            }
        }

        // DMs, Camera, settings, or detailed items where bottom navigation isn't rendered
        if (scanner.isDmScreen || scanner.isStoryComposer || !scanner.hasBottomNavigation) {
            overlayManager.hideSplash()
            overlayManager.hideViewportMask()
            overlayManager.hideExploreMask()
            return
        }

        // Fail-secure fallback: default to showing the viewport mask if layout is ambiguous
        overlayManager.hideSplash()
        overlayManager.hideExploreMask()
        overlayManager.showInstagramViewportMask()
    }

    private fun traverseInstagramTree(node: AccessibilityNodeInfo?, scanner: InstagramScanner) {
        if (node == null) return

        val className = node.className?.toString() ?: ""
        val desc = node.contentDescription?.toString() ?: ""
        val text = node.text?.toString() ?: ""
        val viewId = node.viewIdResourceName ?: ""

        val descLower = desc.lowercase()
        val textLower = text.lowercase()

        // Detect bottom tab bar items
        if (descLower.contains("home")) {
            scanner.hasBottomNavigation = true
            if (node.isSelected) {
                scanner.isHomeTabSelected = true
            }
        } else if (descLower.contains("search") || descLower.contains("explore")) {
            scanner.hasBottomNavigation = true
            if (node.isSelected) {
                scanner.isSearchTabSelected = true
            }
        } else if (descLower.contains("reels")) {
            scanner.hasBottomNavigation = true
            if (node.isSelected) {
                scanner.isReelsTabSelected = true
            }
        } else if (descLower.contains("profile") || descLower.contains("tab 5 of 5")) {
            scanner.hasBottomNavigation = true
            if (node.isSelected) {
                scanner.isProfileTabSelected = true
            }
        } else if (descLower.contains("create") || descLower.contains("new post")) {
            scanner.hasBottomNavigation = true
        }

        // Detect focused search input
        if (className.contains("EditText") && 
            (descLower.contains("search") || textLower.contains("search") || viewId.contains("search", ignoreCase = true))
        ) {
            if (node.isFocused) {
                scanner.isSearchFocused = true
            }
        }

        // Reels content elements
        if (descLower.contains("double tap to like") || 
            descLower.contains("swipe up for next video") || 
            viewId.contains("reel", ignoreCase = true) ||
            descLower.contains("reels video")
        ) {
            scanner.hasReelsElements = true
        }

        // DM content indicators
        if (viewId.contains("direct", ignoreCase = true) || 
            viewId.contains("message", ignoreCase = true) || 
            textLower.contains("messages") || 
            textLower.contains("chats")
        ) {
            scanner.isDmScreen = true
        }

        // Story composer indicators
        if (viewId.contains("camera", ignoreCase = true) || 
            descLower.contains("story camera") || 
            descLower.contains("shutter button")
        ) {
            scanner.isStoryComposer = true
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            traverseInstagramTree(child, scanner)
            child.recycle()
        }
    }

    // -----------------------------------------------------------------------
    // YouTube layout scanning and Shorts ejection (Phase 6 Sprint 3)
    // -----------------------------------------------------------------------

    private class YouTubeScanner {
        var isShortsActive = false
    }

    private fun scanYouTubeScreenState(rootNode: AccessibilityNodeInfo) {
        val scanner = YouTubeScanner()
        traverseYouTubeTree(rootNode, scanner)
        if (scanner.isShortsActive) {
            Log.d("SayNoAccessibilityService", "YouTube Shorts detected in layout. Ejecting...")
            performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
        }
    }

    private fun traverseYouTubeTree(node: AccessibilityNodeInfo?, scanner: YouTubeScanner) {
        if (node == null || scanner.isShortsActive) return

        val desc = node.contentDescription?.toString() ?: ""
        val text = node.text?.toString() ?: ""
        val viewId = node.viewIdResourceName ?: ""

        val descLower = desc.lowercase()
        val textLower = text.lowercase()

        if (descLower == "shorts" && node.isSelected) {
            scanner.isShortsActive = true
            return
        }

        if (descLower.contains("shorts player") || 
            descLower.contains("shorts video") || 
            viewId.contains("shorts_player") || 
            viewId.contains("shorts_container") ||
            textLower == "remix" ||
            descLower.contains("dislike this video")
        ) {
            if (descLower.contains("shorts player") || viewId.contains("shorts") || textLower == "remix") {
                scanner.isShortsActive = true
                return
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            traverseYouTubeTree(child, scanner)
            child.recycle()
        }
    }
}
