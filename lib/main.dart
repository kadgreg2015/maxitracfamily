import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'config/app_config.dart';
import 'services/background_service.dart';
import 'utils/permissions_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise le service de tracking en arrière-plan
  await TrackingService.initialize();

  // Démarre automatiquement le suivi si déjà configuré et activé
  final prefs = await SharedPreferences.getInstance();
  final isConfigured = prefs.getBool(AppConfig.keyIsConfigured) ?? false;
  final trackingEnabled = prefs.getBool(AppConfig.keyTrackingEnabled) ?? false;

  if (isConfigured && trackingEnabled) {
    final hasPerms = await PermissionsHelper.hasMinimumPermissions();
    if (hasPerms) {
      final isRunning = await TrackingService.isRunning();
      if (!isRunning) {
        await TrackingService.start();
      }
    }
  }

  runApp(const MaxiTrackChildApp());
}
