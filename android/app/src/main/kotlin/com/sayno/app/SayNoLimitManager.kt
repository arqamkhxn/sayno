package com.sayno.app

import android.content.Context
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.util.Log

class SayNoLimitManager(
    private val context: Context,
    private val configManager: SayNoConfigManager,
    private val interventionManager: SayNoInterventionManager? = null
) {
    private val usagePrefs: SharedPreferences = context.getSharedPreferences("sayno_usage", Context.MODE_PRIVATE)
    private val handler = Handler(Looper.getMainLooper())
    
    private var activePackage: String? = null
    private var sessionStartTime: Long = 0L
    private var isTracking = false

    init {
        checkMidnightReset()
    }

    private fun getCurrentDateString(): String {
        val sdf = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
        sdf.timeZone = java.util.TimeZone.getTimeZone("UTC")
        return sdf.format(java.util.Date())
    }

    private fun checkMidnightReset() {
        val today = getCurrentDateString()
        val lastResetDate = usagePrefs.getString("last_reset_date", "") ?: ""
        if (lastResetDate.isEmpty() || today.compareTo(lastResetDate) > 0) {
            val editor = usagePrefs.edit()
            editor.putString("last_reset_date", today)

            // Clean up keys older than 30 days
            val allKeys = usagePrefs.all.keys
            val thirtyDaysAgo = java.util.Calendar.getInstance(java.util.TimeZone.getTimeZone("UTC")).apply {
                time = java.util.Date()
                add(java.util.Calendar.DAY_OF_YEAR, -30)
            }
            val sdf = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
            sdf.timeZone = java.util.TimeZone.getTimeZone("UTC")
            val limitDateString = sdf.format(thirtyDaysAgo.time)

            for (key in allKeys) {
                if (key != "last_reset_date") {
                    if (key.length > 11 && key[key.length - 11] == '_') {
                        val datePart = key.substring(key.length - 10)
                        if (datePart.compareTo(limitDateString) < 0) {
                            editor.remove(key)
                        }
                    } else {
                        editor.remove(key)
                    }
                }
            }
            editor.apply()
        } else if (today.compareTo(lastResetDate) < 0) {
            Log.w("SAYNO_LIMIT", "Time travel detected (backward). Reset skipped.")
        }
    }

    private val checkRunnable = object : Runnable {
        override fun run() {
            checkMidnightReset()
            val pkg = activePackage
            if (pkg != null && isTracking) {
                val currentSessionSeconds = (System.currentTimeMillis() - sessionStartTime) / 1000
                val totalUsage = getAccumulatedUsage(pkg) + currentSessionSeconds
                val limit = configManager.getAppLimit(pkg)

                if (limit != -1L && totalUsage >= limit) {
                    val mode = configManager.getRestrictionMode(pkg)
                    if (mode == "utility" || mode == "focus") {
                        // Utility/Focus: Accumulate usage, notify intervention manager to draw viewport overlay,
                        // and continue checking loop so background tracking is not halted.
                        interventionManager?.startLimitReachedIntervention(pkg)
                        SayNoAccessibilityService.instance?.triggerSelectiveFrictionCheck()
                        handler.postDelayed(this, 1000L)
                    } else {
                        // Time Limit / Monk: Standard eject and block, stop check loop.
                        interventionManager?.startLimitReachedIntervention(pkg)
                        stopChecking()
                    }
                } else {
                    handler.postDelayed(this, 1000L)
                }
            }
        }
    }

    fun startSession(packageName: String) {
        checkMidnightReset()
        if (activePackage == packageName) return
        
        endSession()

        activePackage = packageName
        sessionStartTime = System.currentTimeMillis()
        isTracking = true

        val currentUsage = getAccumulatedUsage(packageName)
        val limit = configManager.getAppLimit(packageName)
        if (limit != -1L && currentUsage >= limit) {
            val mode = configManager.getRestrictionMode(packageName)
            if (mode == "utility" || mode == "focus") {
                // Utility/Focus: Start session and tracking even if already over limit,
                // so that we continue accumulating usage in background while selective friction is drawn.
                interventionManager?.startLimitReachedIntervention(packageName)
                SayNoAccessibilityService.instance?.triggerSelectiveFrictionCheck()
            } else {
                // Time Limit / Monk: Instantly block and reject.
                interventionManager?.startLimitReachedIntervention(packageName)
                isTracking = false
                return
            }
        }

        handler.removeCallbacks(checkRunnable)
        handler.post(checkRunnable)
    }

    fun endSession() {
        val pkg = activePackage
        if (pkg != null && isTracking) {
            val sessionSeconds = (System.currentTimeMillis() - sessionStartTime) / 1000
            val newTotal = getAccumulatedUsage(pkg) + sessionSeconds
            saveAccumulatedUsage(pkg, newTotal)
        }
        stopChecking()
        activePackage = null
        sessionStartTime = 0L
    }

    private fun stopChecking() {
        isTracking = false
        handler.removeCallbacks(checkRunnable)
    }

    fun getAccumulatedUsage(packageName: String): Long {
        return usagePrefs.getLong("${packageName}_${getCurrentDateString()}", 0L)
    }

    fun saveAccumulatedUsage(packageName: String, seconds: Long) {
        usagePrefs.edit().putLong("${packageName}_${getCurrentDateString()}", seconds).apply()
    }

    fun getUsage(packageName: String): Long {
        checkMidnightReset()
        return getAccumulatedUsage(packageName)
    }

    fun getUsageForPackageOnDate(packageName: String, dateStr: String): Long {
        return usagePrefs.getLong("${packageName}_${dateStr}", 0L)
    }

    fun getAllUsage(): Map<String, Long> {
        checkMidnightReset()
        val suffix = "_${getCurrentDateString()}"
        val all = usagePrefs.all
        val usageMap = mutableMapOf<String, Long>()
        for ((key, value) in all) {
            if (key.endsWith(suffix) && value is Long) {
                val pkgName = key.substring(0, key.length - suffix.length)
                usageMap[pkgName] = value
            }
        }
        return usageMap
    }
}
