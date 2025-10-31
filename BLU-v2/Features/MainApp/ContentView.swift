//
//  ContentView.swift
//  BLU-v2
//
//  Main app screen with Connection Mode selection
//

import SwiftUI
import ARKit

struct ContentView: View {
    // MARK: - State Management
    
    @StateObject private var arTrackingService = ARTrackingService()
    @StateObject private var sessionManager = SessionManager()
    @State private var showingSessionSetup = false
    @State private var showingCoachDashboard = false
    @State private var showingARTracking = false
    @State private var showingJoinSession = false
    @State private var showingUmpireMode = false
    @AppStorage("hasCompletedPermissions") private var hasCompletedPermissions = false
    @AppStorage("lastSessionCode") private var lastSessionCode: String = ""
    @AppStorage("lastSessionName") private var lastSessionName: String = ""
    @State private var isCreatingSession = false
    
    enum ConnectionMode: String, CaseIterable {
        case umpireMode = "Umpire Mode"
        case spectatorMode = "Spectator Mode"
        
        var title: String {
            return rawValue
        }
        
        var description: String {
            switch self {
            case .umpireMode:
                return "Start a new session and invite others to join"
            case .spectatorMode:
                return "Connect to another player's session"
            }
        }
        
        var icon: String {
            switch self {
            case .umpireMode:
                return "wifi.router"
            case .spectatorMode:
                return "wifi"
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if hasCompletedPermissions {
                mainContentView
            } else {
                PermissionsView()
            }
        }
    }
    
    private var mainContentView: some View {
        ZStack {
            // Background Image
            backgroundImageView
            
            // Content Overlay
            HStack(spacing: 20) {
                // Left Side - Title
                leftSideTitle
                
                Spacer()
                
                // Right Side - Connection Mode Modal
                connectionModeModal
            }
            .padding(20)
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showingSessionSetup) {
            SessionSetupView()
        }
        .sheet(isPresented: $showingCoachDashboard) {
            CoachDashboardView()
        }
        .sheet(isPresented: $showingJoinSession) {
            JoinSessionView()
                .environmentObject(sessionManager)
        }
        .fullScreenCover(isPresented: $showingUmpireMode) {
            UmpireModeView(onNavigateToAR: {
                showingUmpireMode = false
                showingARTracking = true
            })
            .environmentObject(sessionManager)
        }
        .fullScreenCover(isPresented: $showingARTracking) {
            ARBaseballTrackerView()
                .environmentObject(sessionManager)
        }
        .task {
            await initializeApp()
        }
        .onAppear {
            // Force landscape orientation
            if #available(iOS 16.0, *) {
                setOrientationLock(to: .landscape)
            }
        }
    }
    
    // MARK: - Background Image
    
    private var backgroundImageView: some View {
        GeometryReader { geometry in
            if let imagePath = Bundle.main.path(forResource: "baseball_field_bg", ofType: "jpg"),
               let image = UIImage(contentsOfFile: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .blur(radius: 8)
                    .overlay(
                        Color.black.opacity(0.3)
                    )
            } else {
                // Fallback gradient if image not found
                LinearGradient(
                    colors: [
                        Color.green.opacity(0.6),
                        Color.brown.opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    // MARK: - Left Side Title
    
    private var leftSideTitle: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Home Plate Icon
            //HomePlateIcon(size: 100, strokeWidth: 4, color: .white)
            
            // Hey Blu Title Image
            Image("Hey-Blu-title")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: UIScreen.main.bounds.height/2)
                .shadow(color: .black.opacity(0.5), radius: 3, x: 2, y: 2)

            Text("Multi-Device Setup")
                .font(.system(size:35))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .padding(.leading, 80)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Connection Mode Modal
    
    private var connectionModeModal: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            Text("Connection Mode")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.bottom, 24)
            
            // Mode Options - navigate immediately on tap
            VStack(spacing: 0) {
                ForEach(Array(ConnectionMode.allCases.enumerated()), id: \.element) { index, mode in
                    connectionModeRow(mode: mode)
                    
                    if index < ConnectionMode.allCases.count - 1 {
                        Divider()
                            .padding(.vertical, 5)
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .frame(width: 320)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Connection Mode Row
    
    private func connectionModeRow(mode: ConnectionMode) -> some View {
        Button(action: {
            // Navigate immediately on tap - no delay, no checkbox needed
            selectMode(mode)
        }) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
                
                // Title and Description
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Navigation arrow - indicates immediate navigation
                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle()) // Make entire row tappable
            .background(Color.clear)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func initializeApp() async {
        // Services are already initialized through @StateObject
        // Perform any additional setup if needed
        print("App initialized - Services ready")
    }
    
    private func selectMode(_ mode: ConnectionMode) {
        // Navigate immediately based on selected mode - no delay
        switch mode {
        case .hostGame:
            // Create session before navigating to AR tracking
            createHostSession()
        case .joinGame:
            // Navigate to join session screen
            showingJoinSession = true
        case .rejoinSession:
            // Navigate to rejoin session screen
            showingRejoinSession = true
        }
    }
    
    private func createHostSession() {
        guard !isCreatingSession else { return }
        isCreatingSession = true
        
        Task {
            do {
                // Create session with device name
                let sessionCode = try await sessionManager.startHostingSession(name: UIDevice.current.name)
                
                // Store session code for rejoin functionality
                await MainActor.run {
                    lastSessionCode = sessionCode
                    lastSessionName = UIDevice.current.name
                    isCreatingSession = false
                    
                    // Navigate to AR tracking after session is created
                    showingARTracking = true
                    print("✅ Session created: \(sessionCode) - Navigating to AR tracking")
                }
            } catch {
                await MainActor.run {
                    isCreatingSession = false
                    print("❌ Failed to create session: \(error)")
                    // Could show an alert here
                }
            }
        }
    }
    
    // MARK: - Orientation Control
    
    private func setOrientationLock(to orientation: UIInterfaceOrientationMask) {
        AppDelegate.orientationLock = orientation
        
        // Force device orientation update for iOS 16+
        if #available(iOS 16.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: orientation)
                windowScene.requestGeometryUpdate(geometryPreferences)
            }
        } else {
            // Fallback for earlier iOS versions
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
