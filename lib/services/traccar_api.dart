import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class TraccarApi {
  /// Envoie une position via le protocole OsmAnd de Traccar
  static Future<bool> sendPosition({
    required double latitude,
    required double longitude,
    required double altitude,
    required double speed, // m/s → converti en km/h
    required double heading,
    required double accuracy,
    int? battery,
    String? alarm,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString(AppConfig.keyServerUrl) ?? AppConfig.defaultServerUrl;
    final deviceId = prefs.getString(AppConfig.keyDeviceId) ?? '';

    if (deviceId.isEmpty) return false;

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final speedKmh = (speed * 3.6).toStringAsFixed(2);

    final params = <String, String>{
      'id': deviceId,
      'lat': latitude.toStringAsFixed(6),
      'lon': longitude.toStringAsFixed(6),
      'timestamp': timestamp.toString(),
      'speed': speedKmh,
      'heading': heading.toStringAsFixed(1),
      'altitude': altitude.toStringAsFixed(1),
      'accuracy': accuracy.toStringAsFixed(1),
      if (battery != null) 'batt': battery.toString(),
      if (alarm != null) 'alarm': alarm,
    };

    final uri = Uri.parse(serverUrl).replace(queryParameters: params);

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Envoie une alerte SOS avec la position actuelle
  static Future<bool> sendSos({
    required double latitude,
    required double longitude,
    double altitude = 0,
    double accuracy = 0,
    int? battery,
  }) async {
    return sendPosition(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      speed: 0,
      heading: 0,
      accuracy: accuracy,
      battery: battery,
      alarm: 'sos',
    );
  }

  /// Teste la connexion au serveur
  static Future<bool> testConnection(String serverUrl) async {
    try {
      final uri = Uri.parse(serverUrl);
      final testUri = uri.replace(
        queryParameters: {
          'id': 'test_connection',
          'lat': '0',
          'lon': '0',
          'timestamp': '0',
        },
      );
      final response = await http.get(testUri).timeout(const Duration(seconds: 5));
      // Traccar renvoie 200 même pour des données invalides si le serveur répond
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}
