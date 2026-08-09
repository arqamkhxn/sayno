package com.sayno.app

import android.content.Intent
import android.content.ActivityNotFoundException
import android.provider.Settings
import android.text.TextUtils
import android.accessibilityservice.AccessibilityService
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "sayno/protection"
    private var methodChannel: MethodChannel? = null

    companion object {
        @Volatile
        var instance: MainActivity? = null
    }

    fun dispatchEvent(method: String, arguments: Any?) {
        runOnUiThread {
            methodChannel?.invokeMethod(method, arguments)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        instance = this

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        )
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isClockManipulated" -> {
                    val offsetPrefs = getSharedPreferences("sayno_monotonic_offset", android.content.Context.MODE_PRIVATE)
                    result.success(offsetPrefs.getBoolean("clock_manipulated_flag", false))
                }
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "isScreenOn" -> {
                    val pm = getSystemService(android.content.Context.POWER_SERVICE) as android.os.PowerManager
                    result.success(pm.isInteractive)
                }
                "isDeviceLocked" -> {
                    val km = getSystemService(android.content.Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
                    result.success(km.isKeyguardLocked)
                }
                "openAccessibilitySettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(true)
                    } catch (error: ActivityNotFoundException) {
                        result.success(false)
                    }
                }
                "updateMonitoredApps" -> {
                    @Suppress("UNCHECKED_CAST")
                    val appsList = call.arguments as? List<String>
                    if (appsList != null) {
                        SayNoConfigManager(this).saveMonitoredPackages(appsList.toSet())
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Expected a list of package names", null)
                    }
                }
                "updateHighRiskApps" -> {
                    @Suppress("UNCHECKED_CAST")
                    val appsList = call.arguments as? List<String>
                    if (appsList != null) {
                        SayNoConfigManager(this).saveHighRiskPackages(appsList.toSet())
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Expected a list of package names", null)
                    }
                }
                "updateKeywords" -> {
                    @Suppress("UNCHECKED_CAST")
                    val keywordList = call.arguments as? List<String>
                    if (keywordList != null) {
                        SayNoConfigManager(this).saveKeywords(keywordList)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Expected a list of keywords", null)
                    }
                }
                "setAppLimit" -> {
                    val packageName = call.argument<String>("packageName")
                    val limitSeconds = call.argument<Number>("limitSeconds")?.toLong()
                    val restrictionMode = call.argument<String>("restrictionMode") ?: "time_limit"
                    if (packageName != null && limitSeconds != null) {
                        SayNoConfigManager(this).saveAppLimit(packageName, limitSeconds, restrictionMode)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Expected packageName and limitSeconds", null)
                    }
                }
                "removeAppLimit" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        SayNoConfigManager(this).removeAppLimit(packageName)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Expected packageName", null)
                    }
                }
                "getUsage" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val service = SayNoAccessibilityService.instance
                        if (service != null) {
                            result.success(service.limitManager.getUsage(packageName))
                        } else {
                            val config = SayNoConfigManager(this)
                            val tempLimitManager = SayNoLimitManager(this, config, null)
                            result.success(tempLimitManager.getUsage(packageName))
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Expected packageName", null)
                    }
                }
                "getUsageForPackageOnDateUtc" -> {
                    val packageName = call.argument<String>("packageName")
                    val dateUtc = call.argument<String>("dateUtc")
                    if (packageName != null && dateUtc != null) {
                        val service = SayNoAccessibilityService.instance
                        if (service != null) {
                            result.success(service.limitManager.getUsageForPackageOnDate(packageName, dateUtc))
                        } else {
                            val config = SayNoConfigManager(this)
                            val tempLimitManager = SayNoLimitManager(this, config, null)
                            result.success(tempLimitManager.getUsageForPackageOnDate(packageName, dateUtc))
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Expected packageName and dateUtc", null)
                    }
                }
                "getAllUsage" -> {
                    val service = SayNoAccessibilityService.instance
                    if (service != null) {
                        result.success(service.limitManager.getAllUsage())
                    } else {
                        val config = SayNoConfigManager(this)
                        val tempLimitManager = SayNoLimitManager(this, config, null)
                        result.success(tempLimitManager.getAllUsage())
                    }
                }
                "performBack" -> {
                    val service = SayNoAccessibilityService.instance
                    if (service != null) {
                        val success = service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK)
                        result.success(success)
                    } else {
                        result.success(false)
                    }
                }
                "performHome" -> {
                    val service = SayNoAccessibilityService.instance
                    if (service != null) {
                        val success = service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
                        result.success(success)
                    } else {
                        result.success(false)
                    }
                }
                "triggerRescan" -> {
                    val service = SayNoAccessibilityService.instance
                    if (service != null) {
                        val root = service.rootInActiveWindow
                        if (root != null) {
                            val pkg = root.packageName?.toString() ?: ""
                            root.recycle()
                            service.performKeywordScan(pkg)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "updateVerifiedTime" -> {
                    val epochSeconds = call.argument<Number>("epochSeconds")?.toLong()
                    if (epochSeconds != null) {
                        val config = SayNoConfigManager(this)
                        config.saveVerifiedTime(epochSeconds)
                        
                        val currentWallSec = System.currentTimeMillis() / 1000L
                        val delta = Math.abs(currentWallSec - epochSeconds)
                        if (delta < 30L) {
                            val offsetPrefs = getSharedPreferences("sayno_monotonic_offset", android.content.Context.MODE_PRIVATE)
                            offsetPrefs.edit().putBoolean("clock_manipulated_flag", false).apply()
                            
                            SayNoAccessibilityService.instance?.let { service ->
                                service.overlayManager.hideOverlay()
                            }
                            Log.i("MainActivity", "Clock manipulation flag cleared via NTP MethodChannel sync.")
                        }
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Expected epochSeconds", null)
                    }
                }
                "updateActiveContractStatus" -> {
                    val isActive = call.argument<Boolean>("isActive")
                    if (isActive != null) {
                        val config = SayNoConfigManager(this)
                        config.saveActiveContractStatus(isActive)
                        
                        if (!isActive) {
                            config.saveReleaseAuthorized(false)
                            val offsetPrefs = getSharedPreferences("sayno_monotonic_offset", android.content.Context.MODE_PRIVATE)
                            offsetPrefs.edit().putBoolean("clock_manipulated_flag", false).apply()
                            SayNoAccessibilityService.instance?.let { service ->
                                service.overlayManager.hideOverlay()
                            }
                        }
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Expected isActive", null)
                    }
                }
                "updateReleaseAuthorization" -> {
                    val isAuthorized = call.argument<Boolean>("isAuthorized")
                    if (isAuthorized != null) {
                        val config = SayNoConfigManager(this)
                        config.saveReleaseAuthorized(isAuthorized)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Expected isAuthorized", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        SayNoAccessibilityService.listener = { eventData ->
            dispatchEvent("onAccessibilityEvent", eventData)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        SayNoAccessibilityService.listener = null
        methodChannel = null
        instance = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedServiceName = "${packageName}/${SayNoAccessibilityService::class.java.name}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabledServices)

        for (enabledService in splitter) {
            if (enabledService.equals(expectedServiceName, ignoreCase = true)) {
                return true
            }
        }

        return false
    }
}
