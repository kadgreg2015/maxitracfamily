class AppConfig {
  // Serveur Traccar (protocole OsmAnd, port 5055 par défaut)
  static const String defaultServerUrl = 'http://107.152.36.10:5055';

  static const int defaultTrackingInterval = 30; // secondes
  static const String defaultAdminPin = '1234';
  static const String defaultSecretCode = '*#0000#';
  static const String defaultNotificationTitle = 'Service Système';
  static const String defaultNotificationContent = 'En cours d\'exécution';

  static const int foregroundNotificationId = 888;
  static const String notificationChannelId = 'maxitrack_bg';

  static const int adminLongPressDuration = 5; // secondes

  // Clés SharedPreferences
  static const String keyServerUrl = 'server_url';
  static const String keyDeviceId = 'device_id';
  static const String keyDeviceName = 'device_name';
  static const String keyTrackingInterval = 'tracking_interval';
  static const String keyAdminPin = 'admin_pin';
  static const String keySosPhone = 'sos_phone';
  static const String keyIsConfigured = 'is_configured';
  static const String keyNotificationTitle = 'notification_title';
  static const String keyNotificationContent = 'notification_content';
  static const String keyIconHidden = 'icon_hidden';
  static const String keyTrackingEnabled = 'tracking_enabled';
  static const String keySecretCode = 'secret_code';

  // MethodChannel Android pour masquer l'icône
  static const String iconChannel = 'com.maxitrack.family/icon';
}
