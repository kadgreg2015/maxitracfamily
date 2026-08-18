import 'dart:async';
import 'dart:ui';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'traccar_api.dart';

// ---------- Handlers isolat background ----------

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final battery = Battery();

  // Écoute des commandes depuis l'UI
  service.on('stopService').listen((_) => service.stopSelf());

  service.on('sendSos').listen((data) async {
    await _sendSosFromBackground(battery);
  });

  // Boucle de tracking récursive (respecte l'intervalle configuré)
  _trackingLoop(service, battery);
}

void _trackingLoop(ServiceInstance service, Battery battery) {
  SharedPreferences.getInstance().then((prefs) async {
    final enabled = prefs.getBool(AppConfig.keyTrackingEnabled) ?? true;
    final interval = prefs.getInt(AppConfig.keyTrackingInterval) ?? AppConfig.defaultTrackingInterval;

    if (enabled) {
      await _sendPosition(service, prefs, battery);
    }

    Future.delayed(Duration(seconds: interval), () {
      _trackingLoop(service, battery);
    });
  });
}

Future<void> _sendPosition(
  ServiceInstance service,
  SharedPreferences prefs,
  Battery battery,
) async {
  try {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );

    int? batteryLevel;
    try {
      batteryLevel = await battery.batteryLevel;
    } catch (_) {}

    final success = await TraccarApi.sendPosition(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      speed: position.speed,
      heading: position.heading,
      accuracy: position.accuracy,
      battery: batteryLevel,
    );

    // Mise à jour notification Android (titre discret)
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: prefs.getString(AppConfig.keyNotificationTitle) ?? AppConfig.defaultNotificationTitle,
        content: prefs.getString(AppConfig.keyNotificationContent) ?? AppConfig.defaultNotificationContent,
      );
    }

    // Notifie l'UI
    service.invoke('locationUpdate', {
      'lat': position.latitude,
      'lon': position.longitude,
      'accuracy': position.accuracy,
      'battery': batteryLevel,
      'success': success,
      'timestamp': DateTime.now().toIso8601String(),
    });
  } catch (_) {
    service.invoke('locationUpdate', {
      'success': false,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}

Future<void> _sendSosFromBackground(Battery battery) async {
  try {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
    int? batteryLevel;
    try {
      batteryLevel = await battery.batteryLevel;
    } catch (_) {}

    await TraccarApi.sendSos(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      accuracy: position.accuracy,
      battery: batteryLevel,
    );
  } catch (_) {}
}

// ---------- Classe utilitaire pour l'UI ----------

class TrackingService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const channel = AndroidNotificationChannel(
      AppConfig.notificationChannelId,
      'MaxiTrack',
      description: 'Service de suivi en arrière-plan',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    final prefs = await SharedPreferences.getInstance();
    final notifTitle = prefs.getString(AppConfig.keyNotificationTitle) ?? AppConfig.defaultNotificationTitle;
    final notifContent = prefs.getString(AppConfig.keyNotificationContent) ?? AppConfig.defaultNotificationContent;

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: AppConfig.notificationChannelId,
        initialNotificationTitle: notifTitle,
        initialNotificationContent: notifContent,
        foregroundServiceNotificationId: AppConfig.foregroundNotificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static Future<void> start() async {
    await FlutterBackgroundService().startService();
  }

  static Future<void> stop() async {
    final svc = FlutterBackgroundService();
    if (await svc.isRunning()) {
      svc.invoke('stopService');
    }
  }

  static Future<bool> isRunning() => FlutterBackgroundService().isRunning();

  static void triggerSos() {
    FlutterBackgroundService().invoke('sendSos');
  }

  static Stream<Map<String, dynamic>?> get locationStream =>
      FlutterBackgroundService().on('locationUpdate');
}
