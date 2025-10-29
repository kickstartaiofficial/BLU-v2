//
//  AppDelegate.swift
//  BLU-v2
//
//  App delegate for handling orientation and lifecycle events
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    
    // MARK: - Orientation Control
    
    static var orientationLock = UIInterfaceOrientationMask.landscape
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
    
    // MARK: - App Lifecycle
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Lock orientation to landscape
        lockOrientationToLandscape()
        
        // Configure app-wide settings
        configureAppearance()
        configureNotifications()
        
        return true
    }
    
    // MARK: - Configuration Methods
    
    private func configureAppearance() {
        // Configure global UI appearance
        UINavigationBar.appearance().prefersLargeTitles = true
        UINavigationBar.appearance().tintColor = UIColor.systemBlue
    }
    
    private func configureNotifications() {
        // Configure local notifications for game events
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    // MARK: - Orientation Management
    
    private func lockOrientationToLandscape() {
        AppDelegate.orientationLock = .landscape
        
        // Force device orientation update for iOS 16+
        if #available(iOS 16.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)
                windowScene.requestGeometryUpdate(geometryPreferences)
            }
        } else {
            // Fallback for earlier iOS versions
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")
        }
    }
}
