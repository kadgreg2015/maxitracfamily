import UIKit
import Flutter
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Requis pour le background location sur iOS
        if #available(iOS 14.0, *) {
            // Rien de spécial ici, géré par le plugin geolocator
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Permet au service Flutter de tourner en arrière-plan
    override func applicationDidEnterBackground(_ application: UIApplication) {
        // flutter_background_service gère ceci via BGTaskScheduler
    }
}
