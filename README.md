# MaxiTrack Child — Application de suivi parental

Application Flutter de contrôle parental qui envoie la position GPS de l'enfant vers MaxiTrack (Traccar).

## Fonctionnalités

- **GPS en temps réel** → envoie la position au serveur Traccar via le protocole OsmAnd
- **Bouton SOS** → envoie une alerte d'urgence avec position + appel automatique au parent
- **Service en arrière-plan** → fonctionne écran éteint, redémarre au boot
- **Icône masquable** (Android) → l'icône disparaît du lanceur, accessible via code secret
- **Panneau admin protégé** → accessible par appui long 5 sec sur le coin supérieur droit + PIN

---

## Installation

### Prérequis

- Flutter SDK ≥ 3.2.0
- Android Studio ou Xcode
- Compte Traccar configuré sur MaxiTrack

### Étapes

```bash
# 1. Générer le squelette Flutter dans le dossier existant
cd /Users/mac/Documents/maxitrack_child
flutter create . --org com.maxitrack --project-name maxitrack_child

# 2. Les fichiers de ce projet remplacent ceux générés
#    (main.dart, lib/, AndroidManifest.xml, MainActivity.kt sont déjà présents)

# 3. Installer les dépendances
flutter pub get

# 4. Android : copier le wrapper Gradle si manquant
flutter build apk --debug
```

---

## Configuration initiale

### 1. Créer l'appareil dans Traccar/MaxiTrack

Avant d'installer l'app, allez dans MaxiTrack → Appareils → Ajouter :
- **Nom** : Téléphone de [prénom enfant]
- **Identifiant** : notez l'identifiant généré par l'app (visible dans Admin)

### 2. Premier lancement

1. Ouvrir l'app → bouton SOS rouge affiché
2. Accéder à l'admin : **appui long 5 sec** sur le **coin supérieur droit**
3. Code PIN par défaut : **1234**
4. Configurer :
   - URL Serveur : `http://107.152.36.10:5055`
   - ID Appareil : copiez l'ID et entrez-le dans Traccar
   - Nom de l'appareil
   - Numéro SOS (numéro du parent)
   - Intervalle de tracking
5. Activer le suivi avec le toggle
6. Sauvegarder

---

## Masquer l'icône (Android)

Dans l'écran Admin :
1. Définir un **code secret** (ex: `*#1234#`)
2. Activer le toggle **"Icône masquée"**
3. Confirmer

**Pour rouvrir l'app** : composer le code secret dans le numéroteur téléphonique.

> **Note iOS** : Apple n'autorise pas le masquage d'icône sans jailbreak.
> Alternative : renommez l'app en quelque chose de neutre dans Xcode
> (ex: "Calculatrice", "Météo") et changez l'icône.

---

## Architecture

```
lib/
├── main.dart                    # Point d'entrée, init service
├── app.dart                     # MaterialApp
├── config/
│   └── app_config.dart          # Constantes & clés
├── services/
│   ├── background_service.dart  # Service GPS arrière-plan
│   └── traccar_api.dart         # Envoi positions vers Traccar (OsmAnd)
├── screens/
│   ├── sos_screen.dart          # Écran principal (bouton SOS)
│   └── admin_screen.dart        # Configuration parent
└── utils/
    ├── icon_manager.dart        # Masquer/afficher icône Android
    └── permissions_helper.dart  # Gestion permissions

android/app/src/main/
├── AndroidManifest.xml                     # Alias launcher + permissions
└── kotlin/com/maxitrack/child/
    ├── MainActivity.kt                     # MethodChannel icône
    ├── SecretCodeReceiver.kt               # Détection code secret
    ├── BootReceiver.kt                     # Démarrage au boot
    └── AppKeys.kt                          # Clés SharedPreferences
```

---

## Protocole Traccar (OsmAnd)

Les positions sont envoyées via GET HTTP :

```
http://SERVER:5055/?id=DEVICE_ID&lat=LAT&lon=LON&timestamp=TS
    &speed=KMH&heading=DEG&altitude=M&accuracy=M&batt=PCT
    [&alarm=sos]  ← ajouté uniquement pour les alertes SOS
```

Le serveur MaxiTrack est à `107.152.36.10`, port OsmAnd : **5055**.

---

## Build production

```bash
# Android (APK signé)
flutter build apk --release

# Android (App Bundle pour Play Store)
flutter build appbundle --release

# iOS (depuis macOS avec Xcode)
flutter build ios --release
```

---

## Permissions Android requises

| Permission | Usage |
|---|---|
| `ACCESS_FINE_LOCATION` | GPS précis |
| `ACCESS_BACKGROUND_LOCATION` | GPS écran éteint |
| `FOREGROUND_SERVICE_LOCATION` | Service en premier plan (Android 14) |
| `RECEIVE_BOOT_COMPLETED` | Redémarrage auto au boot |
| `PROCESS_OUTGOING_CALLS` | Code secret via numéroteur |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Évite la suspension par Android |
| `POST_NOTIFICATIONS` | Notification service (Android 13+) |
