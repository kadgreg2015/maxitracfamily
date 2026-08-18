package com.maxitrack.family

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager

/**
 * Intercepte les appels sortants.
 * Si le numéro composé correspond au code secret configuré, ouvre l'app
 * et annule l'appel (pour ne pas déclencher un vrai appel).
 *
 * Le code secret est stocké dans SharedPreferences Flutter :
 *   clé = "flutter.secret_code", valeur ex: "*#0000#"
 *
 * L'utilisateur compose ce code dans le numéroteur → l'app s'ouvre.
 */
class SecretCodeReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_NEW_OUTGOING_CALL) return

        val dialedNumber = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER) ?: return

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        // Flutter stocke les clés avec le préfixe "flutter."
        val secretCode = prefs.getString("flutter.${AppKeys.SECRET_CODE}", "*#0000#") ?: "*#0000#"

        if (dialedNumber == secretCode) {
            // Annule l'appel
            resultData = null

            // Re-active l'alias si masqué (nécessaire pour ouvrir l'activité)
            val alias = ComponentName(context, "com.maxitrack.family.LauncherAlias")
            val state = context.packageManager.getComponentEnabledSetting(alias)
            if (state == PackageManager.COMPONENT_ENABLED_STATE_DISABLED) {
                context.packageManager.setComponentEnabledSetting(
                    alias,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
            }

            // Lance l'activité principale
            val launch = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            context.startActivity(launch)
        }
    }
}
