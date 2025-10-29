//
//  BLU_v2App.swift
//  BLU-v2
//
//  Modern SwiftUI app entry point with iOS 17+ features
//

import SwiftUI
import SwiftData

@main
struct BLU_v2App: App {
    // MARK: - App Configuration
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MARK: - SwiftData Model Container
    let modelContainer: ModelContainer
    
    // MARK: - Initialization
    
    init() {
        // Configure SwiftData models
        do {
            modelContainer = try ModelContainer(for: GameSession.self, PitchData.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    // MARK: - App Body
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Force landscape orientation on launch
        lockOrientationToLandscape()
        
        // Configure app-wide settings
        configureAppearance()
        configureNotifications()
        
        return true
    }
    
    // MARK: - Orientation Lock
    
    static var orientationLock = UIInterfaceOrientationMask.landscape
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
    
    private func lockOrientationToLandscape() {
        AppDelegate.orientationLock = .landscape
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
}
