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

