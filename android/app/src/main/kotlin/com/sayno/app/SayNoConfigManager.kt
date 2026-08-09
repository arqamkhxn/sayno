package com.sayno.app

import android.content.Context
import android.content.SharedPreferences

class SayNoConfigManager(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val offsetPrefs: SharedPreferences = context.getSharedPreferences(OFFSET_PREFS_NAME, Context.MODE_PRIVATE)

    companion object {
        private const val PREFS_NAME = "sayno_config"
        private const val OFFSET_PREFS_NAME = "sayno_monotonic_offset"
        private const val KEY_MONITORED_PACKAGES = "monitored_packages"
        private const val KEY_HIGH_RISK_PACKAGES = "high_risk_packages"
        private const val KEY_KEYWORDS = "keywords"
        private const val LIMIT_PREFIX = "limit_"
        private const val MODE_PREFIX = "mode_"
        private const val KEY_VERIFIED_TIME = "verified_time_utc"
        private const val KEY_ACTIVE_CONTRACT = "active_contract_status"
        private const val KEY_RELEASE_AUTHORIZED = "is_release_authorized"
    }

    fun saveMonitoredPackages(packages: Set<String>) {
        prefs.edit().putStringSet(KEY_MONITORED_PACKAGES, packages).apply()
    }

    fun getMonitoredPackages(): Set<String> {
        return prefs.getStringSet(KEY_MONITORED_PACKAGES, emptySet()) ?: emptySet()
    }

    fun saveHighRiskPackages(packages: Set<String>) {
        prefs.edit().putStringSet(KEY_HIGH_RISK_PACKAGES, packages).apply()
    }

    fun getHighRiskPackages(): Set<String> {
        return prefs.getStringSet(KEY_HIGH_RISK_PACKAGES, emptySet()) ?: emptySet()
    }

    fun saveKeywords(keywords: List<String>) {
        prefs.edit().putStringSet(KEY_KEYWORDS, keywords.toSet()).apply()
    }

    fun getKeywords(): List<String> {
        return prefs.getStringSet(KEY_KEYWORDS, emptySet())?.toList() ?: emptyList()
    }

    fun saveAppLimit(packageName: String, limitSeconds: Long, restrictionMode: String) {
        prefs.edit()
            .putLong(LIMIT_PREFIX + packageName, limitSeconds)
            .putString(MODE_PREFIX + packageName, restrictionMode)
            .apply()
    }

    fun removeAppLimit(packageName: String) {
        prefs.edit()
            .remove(LIMIT_PREFIX + packageName)
            .remove(MODE_PREFIX + packageName)
            .apply()
    }

    fun getAppLimit(packageName: String): Long {
        return prefs.getLong(LIMIT_PREFIX + packageName, -1L)
    }

    fun getRestrictionMode(packageName: String): String {
        return prefs.getString(MODE_PREFIX + packageName, "time_limit") ?: "time_limit"
    }

    fun getAllLimits(): Map<String, Long> {
        val allEntries = prefs.all
        val limits = mutableMapOf<String, Long>()
        for ((key, value) in allEntries) {
            if (key.startsWith(LIMIT_PREFIX) && value is Long) {
                val packageName = key.substring(LIMIT_PREFIX.length)
                limits[packageName] = value
            }
        }
        return limits
    }

    fun saveVerifiedTime(timeSeconds: Long) {
        prefs.edit().putLong(KEY_VERIFIED_TIME, timeSeconds).apply()
    }

    fun getVerifiedTime(): Long {
        return prefs.getLong(KEY_VERIFIED_TIME, 0L)
    }

    fun saveActiveContractStatus(isActive: Boolean) {
        prefs.edit().putBoolean(KEY_ACTIVE_CONTRACT, isActive).apply()
    }

    fun isActiveContract(): Boolean {
        return prefs.getBoolean(KEY_ACTIVE_CONTRACT, false)
    }

    fun saveReleaseAuthorized(isAuthorized: Boolean) {
        prefs.edit().putBoolean(KEY_RELEASE_AUTHORIZED, isAuthorized).apply()
    }

    fun isReleaseAuthorized(): Boolean {
        return prefs.getBoolean(KEY_RELEASE_AUTHORIZED, false)
    }

    fun getAccumulatedMonotonicTime(): Long {
        return offsetPrefs.getLong("accumulated_monotonic_time", 0L)
    }

    fun saveAccumulatedMonotonicTime(time: Long) {
        offsetPrefs.edit().putLong("accumulated_monotonic_time", time).apply()
    }

    fun getLastWallClockTimestamp(): Long {
        return offsetPrefs.getLong("last_wall_clock_timestamp", 0L)
    }

    fun saveLastWallClockTimestamp(timestamp: Long) {
        offsetPrefs.edit().putLong("last_wall_clock_timestamp", timestamp).apply()
    }

    fun getMonotonicOffsetBase(): Long {
        return offsetPrefs.getLong("monotonic_offset_base", 0L)
    }

    fun saveMonotonicOffsetBase(base: Long) {
        offsetPrefs.edit().putLong("monotonic_offset_base", base).apply()
    }
}
