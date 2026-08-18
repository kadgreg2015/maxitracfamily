import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class IconManager {
  static const _channel = MethodChannel(AppConfig.iconChannel);

  /// Masque l'icône de l'application (Android uniquement)
  static Future<bool> hideIcon() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('hideIcon');
      if (result == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(AppConfig.keyIconHidden, true);
      }
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Affiche l'icône de l'application (Android uniquement)
  static Future<bool> showIcon() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('showIcon');
      if (result == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(AppConfig.keyIconHidden, false);
      }
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Vérifie si l'icône est actuellement masquée
  static Future<bool> isIconHidden() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isIconHidden');
      return result ?? false;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(AppConfig.keyIconHidden) ?? false;
    }
  }

  /// Bascule entre masqué et visible
  static Future<bool> toggleIcon() async {
    final hidden = await isIconHidden();
    return hidden ? showIcon() : hideIcon();
  }
}
