import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../services/background_service.dart';
import '../services/traccar_api.dart';
import '../utils/icon_manager.dart';
import '../utils/permissions_helper.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _isTracking = false;
  bool _testingConnection = false;
  bool _iconHidden = false;

  final _serverUrlCtrl = TextEditingController();
  final _deviceIdCtrl = TextEditingController();
  final _deviceNameCtrl = TextEditingController();
  final _sosPhoneCtrl = TextEditingController();
  final _adminPinCtrl = TextEditingController();
  final _pinConfirmCtrl = TextEditingController();
  final _notifTitleCtrl = TextEditingController();
  final _notifContentCtrl = TextEditingController();
  final _secretCodeCtrl = TextEditingController();

  int _trackingInterval = AppConfig.defaultTrackingInterval;
  final List<int> _intervals = [15, 30, 60, 120, 300];
  final Map<int, String> _intervalLabels = {
    15: '15 sec',
    30: '30 sec',
    60: '1 min',
    120: '2 min',
    300: '5 min',
  };

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    for (final c in [
      _serverUrlCtrl, _deviceIdCtrl, _deviceNameCtrl, _sosPhoneCtrl,
      _adminPinCtrl, _pinConfirmCtrl, _notifTitleCtrl, _notifContentCtrl,
      _secretCodeCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    String deviceId = prefs.getString(AppConfig.keyDeviceId) ?? '';
    if (deviceId.isEmpty) {
      deviceId = await _generateDeviceId();
      await prefs.setString(AppConfig.keyDeviceId, deviceId);
    }

    _serverUrlCtrl.text = prefs.getString(AppConfig.keyServerUrl) ?? AppConfig.defaultServerUrl;
    _deviceIdCtrl.text = deviceId;
    _deviceNameCtrl.text = prefs.getString(AppConfig.keyDeviceName) ?? '';
    _sosPhoneCtrl.text = prefs.getString(AppConfig.keySosPhone) ?? '';
    _adminPinCtrl.text = prefs.getString(AppConfig.keyAdminPin) ?? AppConfig.defaultAdminPin;
    _notifTitleCtrl.text = prefs.getString(AppConfig.keyNotificationTitle) ?? AppConfig.defaultNotificationTitle;
    _notifContentCtrl.text = prefs.getString(AppConfig.keyNotificationContent) ?? AppConfig.defaultNotificationContent;
    _secretCodeCtrl.text = prefs.getString(AppConfig.keySecretCode) ?? AppConfig.defaultSecretCode;
    _trackingInterval = prefs.getInt(AppConfig.keyTrackingInterval) ?? AppConfig.defaultTrackingInterval;

    _isTracking = await TrackingService.isRunning();
    _iconHidden = await IconManager.isIconHidden();

    if (mounted) setState(() => _loading = false);
  }

  Future<String> _generateDeviceId() async {
    final info = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return android.id;
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return ios.identifierForVendor ?? const Uuid().v4();
      }
    } catch (_) {}
    return const Uuid().v4();
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    if (_adminPinCtrl.text.isNotEmpty &&
        _pinConfirmCtrl.text.isNotEmpty &&
        _adminPinCtrl.text != _pinConfirmCtrl.text) {
      _showError('Les codes PIN ne correspondent pas');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.keyServerUrl, _serverUrlCtrl.text.trim());
    await prefs.setString(AppConfig.keyDeviceId, _deviceIdCtrl.text.trim());
    await prefs.setString(AppConfig.keyDeviceName, _deviceNameCtrl.text.trim());
    await prefs.setString(AppConfig.keySosPhone, _sosPhoneCtrl.text.trim());
    await prefs.setInt(AppConfig.keyTrackingInterval, _trackingInterval);
    await prefs.setString(AppConfig.keyNotificationTitle, _notifTitleCtrl.text.trim());
    await prefs.setString(AppConfig.keyNotificationContent, _notifContentCtrl.text.trim());
    await prefs.setString(AppConfig.keySecretCode, _secretCodeCtrl.text.trim());
    await prefs.setBool(AppConfig.keyIsConfigured, true);

    if (_adminPinCtrl.text.isNotEmpty) {
      await prefs.setString(AppConfig.keyAdminPin, _adminPinCtrl.text.trim());
    }

    // Redémarre le service pour appliquer les changements
    if (_isTracking) {
      await TrackingService.stop();
      await Future.delayed(const Duration(milliseconds: 500));
      await TrackingService.initialize();
      await TrackingService.start();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration sauvegardée'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _toggleTracking() async {
    setState(() => _loading = true);

    if (_isTracking) {
      await TrackingService.stop();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConfig.keyTrackingEnabled, false);
    } else {
      final hasPerms = await PermissionsHelper.requestAll();
      if (!hasPerms) {
        if (mounted) _showError('Permissions de localisation requises');
        setState(() => _loading = false);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConfig.keyTrackingEnabled, true);
      await TrackingService.initialize();
      await TrackingService.start();
    }

    _isTracking = await TrackingService.isRunning();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _testConnection() async {
    setState(() => _testingConnection = true);
    final ok = await TraccarApi.testConnection(_serverUrlCtrl.text.trim());
    if (mounted) {
      setState(() => _testingConnection = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Connexion réussie ✓' : 'Connexion échouée ✗'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleIcon() async {
    if (!Platform.isAndroid) {
      _showError('Masquer l\'icône n\'est disponible que sur Android');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          _iconHidden ? 'Afficher l\'icône ?' : 'Masquer l\'icône ?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          _iconHidden
              ? 'L\'icône sera à nouveau visible dans le lanceur.'
              : 'L\'icône disparaîtra du lanceur.\nPour réouvrir l\'app, composez le code secret dans le téléphone : ${_secretCodeCtrl.text}',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    bool success;
    if (_iconHidden) {
      success = await IconManager.showIcon();
    } else {
      success = await IconManager.hideIcon();
    }

    if (success) {
      setState(() => _iconHidden = !_iconHidden);
    } else {
      if (mounted) _showError('Impossible de modifier l\'icône');
    }
  }

  void _copyDeviceId() {
    Clipboard.setData(ClipboardData(text: _deviceIdCtrl.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID copié dans le presse-papier')),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('Configuration Admin', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveConfig,
            tooltip: 'Sauvegarder',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statut du tracking
              _buildTrackingStatus(),
              const SizedBox(height: 24),

              // Section Serveur
              _sectionTitle('Serveur Traccar'),
              _buildTextField(
                controller: _serverUrlCtrl,
                label: 'URL OsmAnd',
                hint: 'http://IP:5055',
                validator: (v) => v!.isEmpty ? 'Requis' : null,
                suffix: IconButton(
                  icon: _testingConnection
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering, color: Colors.grey),
                  onPressed: _testingConnection ? null : _testConnection,
                  tooltip: 'Tester',
                ),
              ),
              const SizedBox(height: 12),

              // Section Appareil
              _sectionTitle('Appareil'),
              _buildTextField(
                controller: _deviceIdCtrl,
                label: 'ID Appareil (dans Traccar)',
                validator: (v) => v!.isEmpty ? 'Requis' : null,
                suffix: IconButton(
                  icon: const Icon(Icons.copy, color: Colors.grey),
                  onPressed: _copyDeviceId,
                  tooltip: 'Copier',
                ),
              ),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _deviceNameCtrl,
                label: 'Nom de l\'appareil',
                hint: 'ex: Téléphone de Marie',
              ),
              const SizedBox(height: 8),

              // Intervalle
              _sectionTitle('Intervalle de suivi'),
              DropdownButtonFormField<int>(
                value: _trackingInterval,
                dropdownColor: Colors.grey[850],
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Intervalle'),
                items: _intervals.map((v) {
                  return DropdownMenuItem(
                    value: v,
                    child: Text(_intervalLabels[v]!),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _trackingInterval = v!),
              ),
              const SizedBox(height: 24),

              // Section Urgence
              _sectionTitle('Contact d\'urgence'),
              _buildTextField(
                controller: _sosPhoneCtrl,
                label: 'Numéro SOS',
                hint: '+33600000000',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),

              // Section Sécurité
              _sectionTitle('Sécurité'),
              _buildTextField(
                controller: _adminPinCtrl,
                label: 'Nouveau code PIN admin',
                hint: 'Laisser vide pour ne pas changer',
                obscure: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _pinConfirmCtrl,
                label: 'Confirmer le PIN',
                obscure: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              const SizedBox(height: 24),

              // Section Discrétion
              _sectionTitle('Discrétion'),
              _buildTextField(
                controller: _notifTitleCtrl,
                label: 'Titre de notification',
                hint: AppConfig.defaultNotificationTitle,
              ),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _notifContentCtrl,
                label: 'Texte de notification',
                hint: AppConfig.defaultNotificationContent,
              ),
              const SizedBox(height: 8),

              // Code secret (Android uniquement)
              if (Platform.isAndroid) ...[
                _buildTextField(
                  controller: _secretCodeCtrl,
                  label: 'Code secret (pour ouvrir l\'app)',
                  hint: AppConfig.defaultSecretCode,
                ),
                const SizedBox(height: 16),
                _buildIconToggle(),
              ],

              if (Platform.isIOS) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'iOS ne permet pas de masquer l\'icône sans jailbreak. Renommez l\'app en quelque chose de neutre dans Xcode.',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Bouton sauvegarder
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveConfig,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'SAUVEGARDER',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isTracking ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isTracking ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isTracking ? 'Suivi actif' : 'Suivi arrêté',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  _isTracking
                      ? 'L\'appareil envoie sa position à MaxiTrack'
                      : 'Appuyez pour démarrer le suivi',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _isTracking,
            onChanged: (_) => _toggleTracking(),
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildIconToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _iconHidden ? Icons.visibility_off : Icons.visibility,
            color: _iconHidden ? Colors.orange : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _iconHidden ? 'Icône masquée' : 'Icône visible',
                  style: const TextStyle(color: Colors.white),
                ),
                if (_iconHidden)
                  Text(
                    'Code: ${_secretCodeCtrl.text}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
              ],
            ),
          ),
          Switch(
            value: _iconHidden,
            onChanged: (_) => _toggleIcon(),
            activeColor: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.grey),
      hintStyle: TextStyle(color: Colors.grey[700]),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey[800]!),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
      fillColor: Colors.grey[900],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscure = false,
    TextInputType? keyboardType,
    int? maxLength,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: _inputDecoration(label, hint: hint).copyWith(
        suffixIcon: suffix,
        counterStyle: TextStyle(color: Colors.grey[700]),
      ),
    );
  }
}
