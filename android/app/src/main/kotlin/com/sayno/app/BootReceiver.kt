package com.sayno.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        val action = intent?.action ?: return
        Log.i("SayNoBootReceiver", "Boot completed event received: $action")

        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_LOCKED_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON"
        ) {
            context?.let { ctx ->
                val offsetPrefs = ctx.getSharedPreferences("sayno_monotonic_offset", Context.MODE_PRIVATE)
                val configPrefs = ctx.getSharedPreferences("sayno_config", Context.MODE_PRIVATE)
                
                val accumulated = offsetPrefs.getLong("accumulated_monotonic_time", 0L)
                val lastWall = offsetPrefs.getLong("last_wall_clock_timestamp", 0L)
                val bootWallTime = System.currentTimeMillis()

                val editOffset = offsetPrefs.edit()
                editOffset.putLong("monotonic_offset_base", accumulated)
                
                // Rollback detection during reboot
                val isActiveContract = configPrefs.getBoolean("active_contract_status", false)
                if (isActiveContract && lastWall > 0 && bootWallTime < lastWall) {
                    Log.w("SayNoBootReceiver", "Time rollback detected during boot! lastWall: $lastWall, bootWallTime: $bootWallTime")
                    editOffset.putBoolean("clock_manipulated_flag", true)
                }
                
                editOffset.putLong("last_wall_clock_timestamp", bootWallTime)
                editOffset.apply()

                Log.i("SayNoBootReceiver", "Restored monotonic offset base: $accumulated. Boot wall clock: $bootWallTime")
            }
        }
    }
}
