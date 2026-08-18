package com.maxitrack.family

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val ICON_CHANNEL = "com.maxitrack.family/icon"
    private val ALIAS = "com.maxitrack.family.LauncherAlias"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ICON_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hideIcon" -> {
                        try {
                            packageManager.setComponentEnabledSetting(
                                ComponentName(packageName, ALIAS),
                                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                PackageManager.DONT_KILL_APP
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("HIDE_ERROR", e.message, null)
                        }
                    }
                    "showIcon" -> {
                        try {
                            packageManager.setComponentEnabledSetting(
                                ComponentName(packageName, ALIAS),
                                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                                PackageManager.DONT_KILL_APP
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SHOW_ERROR", e.message, null)
                        }
                    }
                    "isIconHidden" -> {
                        val state = packageManager.getComponentEnabledSetting(
                            ComponentName(packageName, ALIAS)
                        )
                        result.success(state == PackageManager.COMPONENT_ENABLED_STATE_DISABLED)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
