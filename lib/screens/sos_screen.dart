import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../services/background_service.dart';
import '../services/traccar_api.dart';
import 'admin_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  bool _isTracking = false;
  bool _sosSent = false;
  bool _sosSending = false;
  double? _lastLat;
  double? _lastLon;
  DateTime? _lastUpdate;
  bool _gpsAvailable = false;

  // Animation SOS
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Timer secret admin (long press coin supérieur droit)
  Timer? _adminTimer;
  int _adminPressSeconds = 0;

  StreamSubscription? _locationSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initState();
  }

  Future<void> _initState() async {
    _isTracking = await TrackingService.isRunning();
    _gpsAvailable = await Geolocator.isLocationServiceEnabled();

    _locationSub = TrackingService.locationStream.listen((data) {
      if (!mounted || data == null) return;
      setState(() {
        if (data['lat'] != null) _lastLat = (data['lat'] as num).toDouble();
        if (data['lon'] != null) _lastLon = (data['lon'] as num).toDouble();
        _lastUpdate = DateTime.now();
        _isTracking = true;
      });
    });

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _adminTimer?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  Future<void> _sendSos() async {
    if (_sosSending) return;

    setState(() {
      _sosSending = true;
      _sosSent = false;
    });

    HapticFeedback.heavyImpact();

    try {
      // Envoie via le service en arrière-plan
      TrackingService.triggerSos();

      // Envoie direct aussi (si service pas encore démarré)
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      await TraccarApi.sendSos(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        accuracy: position.accuracy,
      );

      // Appel d'urgence si configuré
      final prefs = await SharedPreferences.getInstance();
      final sosPhone = prefs.getString(AppConfig.keySosPhone) ?? '';
      if (sosPhone.isNotEmpty) {
        final uri = Uri.parse('tel:$sosPhone');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }

      setState(() {
        _sosSent = true;
        _sosSending = false;
      });

      // Réinitialise après 5 secondes
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _sosSent = false);
      });
    } catch (_) {
      setState(() => _sosSending = false);
    }
  }

  // Accès admin : appui long 5 secondes sur coin supérieur droit
  void _startAdminTimer() {
    _adminPressSeconds = 0;
    _adminTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _adminPressSeconds++;
      if (_adminPressSeconds >= AppConfig.adminLongPressDuration) {
        t.cancel();
        _showPinDialog();
      }
    });
  }

  void _cancelAdminTimer() {
    _adminTimer?.cancel();
    _adminTimer = null;
    _adminPressSeconds = 0;
  }

  void _showPinDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Code Admin', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Code PIN',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final pin = prefs.getString(AppConfig.keyAdminPin) ?? AppConfig.defaultAdminPin;
              if (controller.text == pin) {
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  );
                }
              } else {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code incorrect')),
                  );
                  Navigator.pop(ctx);
                }
              }
            },
            child: const Text('Entrer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fond avec dégradé subtil
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [
                  Colors.grey[900]!,
                  Colors.black,
                ],
              ),
            ),
          ),

          // Zone admin cachée (coin supérieur droit, 60x60)
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTapDown: (_) => _startAdminTimer(),
              onTapUp: (_) => _cancelAdminTimer(),
              onTapCancel: _cancelAdminTimer,
              child: Container(
                width: 60,
                height: 60,
                color: Colors.transparent,
              ),
            ),
          ),

          // Contenu principal
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Barre de statut
                _buildStatusBar(),

                const Spacer(),

                // Bouton SOS central
                _buildSosButton(),

                const SizedBox(height: 16),

                // Texte d'instruction
                Text(
                  _sosSent
                      ? 'Alerte envoyée !'
                      : 'Appuyez en cas d\'urgence',
                  style: TextStyle(
                    color: _sosSent ? Colors.green : Colors.grey[500],
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),

                const Spacer(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // GPS status
          Row(
            children: [
              Icon(
                _gpsAvailable ? Icons.gps_fixed : Icons.gps_off,
                color: _gpsAvailable ? Colors.green : Colors.red,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                _lastLat != null
                    ? '${_lastLat!.toStringAsFixed(4)}, ${_lastLon!.toStringAsFixed(4)}'
                    : 'GPS...',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),

          // Tracking status
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isTracking ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _lastUpdate != null
                    ? '${_lastUpdate!.hour.toString().padLeft(2, '0')}:${_lastUpdate!.minute.toString().padLeft(2, '0')}'
                    : '--:--',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSosButton() {
    return GestureDetector(
      onTap: _sendSos,
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Halo extérieur
            Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _sosSent
                    ? Colors.green.withOpacity(0.15)
                    : Colors.red.withOpacity(0.15),
              ),
            ),
            // Cercle intermédiaire
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _sosSent
                    ? Colors.green.withOpacity(0.25)
                    : Colors.red.withOpacity(0.25),
              ),
            ),
            // Bouton principal
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _sosSent ? Colors.green : Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: (_sosSent ? Colors.green : Colors.red).withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: _sosSending
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _sosSent ? Icons.check : Icons.emergency,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _sosSent ? 'ENVOYÉ' : 'AIDE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
