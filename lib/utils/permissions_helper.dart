import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsHelper {
  /// Demande toutes les permissions nécessaires
  static Future<bool> requestAll() async {
    // Permission de localisation
    LocationPermission locationPerm = await Geolocator.checkPermission();
    if (locationPerm == LocationPermission.denied) {
      locationPerm = await Geolocator.requestPermission();
      if (locationPerm == LocationPermission.denied) return false;
    }
    if (locationPerm == LocationPermission.deniedForever) return false;

    // Localisation en arrière-plan (Android uniquement)
    if (Platform.isAndroid) {
      final bgLocation = await Permission.locationAlways.request();
      if (bgLocation.isDenied) return false;

      // Notifications (Android 13+)
      await Permission.notification.request();

      // Exclure de l'optimisation de batterie
      final batteryOpt = await Permission.ignoreBatteryOptimizations.status;
      if (!batteryOpt.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }

      // Permission d'appel sortant (pour le code secret)
      await Permission.phone.request();
    }

    return true;
  }

  /// Vérifie si les permissions minimales sont accordées
  static Future<bool> hasMinimumPermissions() async {
    final location = await Permission.location.status;
    if (!location.isGranted) return false;

    if (Platform.isAndroid) {
      final bgLocation = await Permission.locationAlways.status;
      return bgLocation.isGranted;
    }

    // iOS : vérifier "Always" via geolocator
    final perm = await Geolocator.checkPermission();
    return perm == LocationPermission.always;
  }

  /// Vérifie si les services de localisation sont activés
  static Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();
}
