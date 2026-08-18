package com.maxitrack.family

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Démarre le service de tracking automatiquement après un redémarrage du téléphone.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) return

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isConfigured = prefs.getBoolean("flutter.${AppKeys.IS_CONFIGURED}", false)
        val trackingEnabled = prefs.getBoolean("flutter.${AppKeys.TRACKING_ENABLED}", false)

        if (isConfigured && trackingEnabled) {
            // Lance l'app en arrière-plan pour démarrer le service Flutter
            val launch = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                putExtra("boot_start", true)
            }
            context.startActivity(launch)
        }
    }
}
