//
//  ARBaseballTrackerView.swift
//  BLU-v2
//
//  Unified AR tracking system for baseball field and ball tracking
//

import SwiftUI
import ARKit
import UIKit
import CoreLocation

struct ARBaseballTrackerView: View {
    @StateObject private var arTrackingService = ARTrackingService()
    @EnvironmentObject var sessionManager: SessionManager
    @AppStorage("lastSessionCode") private var lastSessionCode: String = ""
    @Environment(\.dismiss) private var dismiss
    
    @State private var showPositioningControls = false
    @State private var isTracking = false
    @State private var currentSpeed: Double = 0.0
    @State private var showFieldLines = true
    @State private var showTooltips = false
    @State private var showSessionInfo = false
    @State private var showWebView = false
    
    let lightBlueColor = Color(red: 0.5, green: 0.7, blue: 1.0)
    
    var body: some View {
        ZStack {
            // AR View Layer - Single unified AR session
            ARViewRepresentable(
                arTrackingService: arTrackingService,
                showFieldLines: showFieldLines,
                onTap: handleTap
            )
            .ignoresSafeArea()
            
            // Top Bar (Back Button + Session Code)
            topBar
            
            // Green Pentagon Placement UI (only when home plate not placed)
            if !arTrackingService.isHomePlatePlaced {
                greenPentagonPlacementView
            }
            
            // Positioning Controls Overlay
            if showPositioningControls {
                positioningControlsOverlay
            }
            
            // Session Info Card (slide-up)
            if showSessionInfo {
                sessionInfoCardOverlay
            }
            
            // Control Buttons
            controlButtons
            
            // Ball Speed Display (when tracking)
            if arTrackingService.trackingState == .trackingSpeed {
                ballSpeedDisplay
            }
            
        }
        .fullScreenCover(isPresented: $showWebView) {
            if let url = URL(string: "https://blu-baseball.web.app") {
                WebViewScreen(url: url)
            }
        }
        // Optimize sheet presentation to prevent hangs
        .transaction { transaction in
            transaction.animation = transaction.animation?.speed(1.0)
        }
        .task {
            await initializeAR()
            // Ensure session is initialized if not already created
            await ensureSessionInitialized()
        }
        .onAppear {
            // Ensure landscape orientation is locked
            AppDelegate.orientationLock = .landscape
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UpdateSessionLocation"))) { notification in
            guard let fieldLocation = notification.userInfo?["fieldLocation"] as? FieldLocation else { return }
            Task { @MainActor in
                sessionManager.updateSessionLocation(fieldLocation)
            }
        }
        .onDisappear {
            // Clean up when view disappears
            arTrackingService.stopTracking()
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        VStack(spacing: 0) {
            HStack {
                // Back Button (left)
                Button(action: { dismiss() }) {
                    HStack {
                        Image(systemName: "chevron.left")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // Session Code (right)
                if let sessionCode = sessionCode {
                    sessionCodeDisplay(sessionCode: sessionCode)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 8)
            
            Spacer()
        }
        .padding(.top) // Safe area top padding
    }
    
    // MARK: - Session Code Display
    
    private func sessionCodeDisplay(sessionCode: String) -> some View {
        Button(action: {
            // Tap session code to show session info card
            // Use async to prevent blocking main thread
            Task { @MainActor in
                showSessionInfo = true
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "number")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text("Session:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(sessionCode)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
        }
    }
    
    // MARK: - Green Pentagon Placement View
    
    private var greenPentagonPlacementView: some View {
        ZStack {
            // Semi-transparent card
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.3))
                .frame(width: 350, height: 350)
            
            // Centered content: Green pentagon background with white pentagon and text
            ZStack {
                // Green Home Plate Icon (background layer)
                HomePlateIcon(size: 300, strokeWidth: 4, color: .green)
                    .opacity(0.6)
                    .shadow(color: .green.opacity(0.8), radius: 12)
                    .padding(.bottom, 70)
                
                // White Home Plate Icon and text (foreground layer)
                VStack(spacing: 12) {
                    HomePlateIcon(size: 100, strokeWidth: 3, color: .white)
                        .shadow(color: .green.opacity(0.6), radius: 8)
                    
                    Text("Tap to Place Home Plate")
                        .foregroundColor(.white)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 70)
            }
        }
        .allowsHitTesting(false) // Allow taps to pass through to AR view
    }
    
    // MARK: - Ball Speed Display
    
    private var ballSpeedDisplay: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                VStack(spacing: 8) {
                    Text("Ball Speed")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("\(String(format: "%.1f", currentSpeed)) mph")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                
                Spacer()
            }
            .padding(.bottom, 100) // Already provides spacing from bottom
        }
    }
    
    
    // MARK: - Positioning Controls Overlay
    
    private var positioningControlsOverlay: some View {
        ARPositionControlsView(
            arTrackingService: arTrackingService,
            showFieldLines: $showFieldLines,
            onDone: {
                hidePositioningControls()
            },
            onCancel: {
                hidePositioningControls()
            }
        )
    }
    
    // MARK: - Session Info Card Overlay
    
    private var sessionInfoCardOverlay: some View {
        ZStack {
            // Semi-transparent background - optimized for performance
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissSessionInfo()
                }
            
            // Slide-up card - optimized presentation
            VStack {
                Spacer()
                
                if let id = sessionCode {
                    // Get location from session's stored fieldLocation, fallback to current location
                    let sessionLocation: CLLocation? = {
                        if let session = sessionManager.currentSession,
                           let fieldLocation = session.fieldLocation {
                            return CLLocation(
                                latitude: fieldLocation.latitude,
                                longitude: fieldLocation.longitude
                            )
                        }
                        return arTrackingService.currentLocation
                    }()
                    
                    SessionInfoCardView(
                        sessionCode: id,
                        sessionName: sessionManager.currentSession?.name,
                        location: sessionLocation,
                        onDismiss: {
                            dismissSessionInfo()
                        }
                    )
                    .padding(.bottom)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                } else {
                    // No session available
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("No Active Session")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Start a session to share your Session Code")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                        
                        Button("Close") {
                            dismissSessionInfo()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(40)
                    .padding(.bottom)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
            }
        }
        // Use explicit animation only when showing (not when hiding to prevent hang)
        .animation(showSessionInfo ? .spring(response: 0.35, dampingFraction: 0.85) : nil, value: showSessionInfo)
    }
    
    private func dismissSessionInfo() {
        // Dismiss immediately without animation to prevent hang
        showSessionInfo = false
    }
    
    private var sessionCode: String? {
        // Get session Code from current session (now stores the 6-digit code directly)
        if let session = sessionManager.currentSession {
            // Session Code should now be a 6-digit code (matches reference project pattern)
            return session.id
        }
        // Fallback: Check connection status if session isn't available yet
        if sessionManager.isHosting {
            let components = sessionManager.connectionStatus.components(separatedBy: ": ")
            if components.count > 1 {
                let code = components.last ?? ""
                return code.count == 6 ? code : nil
            }
        }
        return nil
    }
    
    // MARK: - Control Buttons
    
    private var controlButtons: some View {
        HStack {
            // Left Controls
            VStack(alignment: .leading, spacing: 36) {
                
                Spacer()
                // Adjust Orientation Button
                createSimpleStatusButton(
                    icon: "location.viewfinder",
                    tooltip: "AR Tracking",
                    action: showPositioningControlsView,
                    isDisabled: !arTrackingService.isHomePlatePlaced,
                    isActive: showPositioningControls
                )
                
                // Show Hide Lines Button (toggles 3D geometry)
                createSimpleStatusButton(
                    icon: "field.of.view.wide",
                    tooltip: "Overlay",
                    action: showHideLines,
                    isActive: showFieldLines
                )
                
                // Info Button
                createSimpleStatusButton(
                    icon: "info.circle",
                    tooltip: "Tooltips",
                    action: showInfo,
                    isActive: showTooltips
                )
            }
            .padding(.leading, 10)
            .padding(.top, 10)
            .padding(.bottom, 10)
       
            Spacer()
            
            // Right Controls
            VStack(alignment: .trailing, spacing: 36) {
                
                Spacer()
                
                // Tracking Ball Button
                createSimpleStatusButton(
                    icon: "figure.baseball",
                    tooltip: "Track ball",
                    action: trackingBall,
                    isDisabled: !arTrackingService.isHomePlatePlaced,
                    isActive: arTrackingService.trackingState == .trackingSpeed
                )
                
                // Camera Button
                createSimpleStatusButton(
                    icon: "camera",
                    tooltip: "Record",
                    action: captureScreenshot,
                    isDisabled: !arTrackingService.isHomePlatePlaced,
                    isActive: false
                )
                
                // Connection Settings Button
                createSimpleStatusButton(
                    icon: "network",
                    tooltip: "Network",
                    action: connectionSettings,
                    isActive: false
                )
            }
            .padding(.trailing, 10)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
    }
    
    // MARK: - Button Factory
    
    private func createSimpleStatusButton(
        icon: String,
        tooltip: String,
        action: @escaping () -> Void,
        isDisabled: Bool = false,
        isActive: Bool = false
    ) -> some View {
        VStack(spacing: 4) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(isActive ? lightBlueColor  : .white) // Blue when active, white when inactive
                    .frame(width: 60, height: 60)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
            .disabled(isDisabled)
            
            // Always render text with fixed height to prevent jumping
            Text(tooltip)
                .font(.caption2)
                .foregroundColor(.black.opacity(1.0))
                .lineLimit(1)
                .frame(height: 18)
                .frame(width: 70)
                .background(.white.opacity(0.4))
                .cornerRadius(5)
                .opacity(showTooltips ? 1.0 : 0.0)
        }
        .frame(height: 72) // Fixed height: 50 (button) + 4 (spacing) + 18 (text) = 72
    }
    
    // MARK: - Actions
    
    private func ensureSessionInitialized() async {
        // Check if session already exists (created from Host Game)
        if sessionManager.currentSession != nil {
            // Session already exists, ensure it's stored
            if let sessionId = sessionManager.currentSession?.id {
                await MainActor.run {
                    lastSessionCode = sessionId
                }
            }
            return
        }
        
        // If no session exists but we have a last session code, try to rejoin
        if !lastSessionCode.isEmpty {
            let success = await sessionManager.rejoinSession(sessionCode: lastSessionCode)
            if success {
                print("✅ Rejoined session: \(lastSessionCode)")
                return
            }
        }
        
        // No session available - create a new one
        do {
            let sessionCode = try await sessionManager.startHostingSession(name: UIDevice.current.name)
            await MainActor.run {
                lastSessionCode = sessionCode
            }
            print("✅ Created new session: \(sessionCode)")
        } catch {
            print("❌ Failed to create session: \(error)")
        }
    }
    
    private func initializeAR() async {
        await arTrackingService.initialize()
        do {
            try await arTrackingService.startTracking()
            isTracking = true
        } catch {
            print("Failed to start AR: \(error)")
        }
    }
    
    private func handleTap(at location: CGPoint) {
        if !arTrackingService.isHomePlatePlaced {
            Task {
                await arTrackingService.placeHomePlate(at: location)
                // Start ball tracking after home plate is placed
                await arTrackingService.startBallTracking()
            }
        }
    }
    
    private func showPositioningControlsView() {
        showPositioningControls = true
        arTrackingService.displayPositioningControls()
    }
    
    private func showHideLines() {
        showFieldLines.toggle()
    }
    
    private func hidePositioningControls() {
        showPositioningControls = false
        arTrackingService.hidePositioningControls()
    }
    
    private func trackingBall() {
        // TODO: Implement info display
        print("ℹ️ Tracking Ball")
    }
    
    private func captureScreenshot() {
        // TODO: Implement screenshot capture
        print("📸 Capturing screenshot")
    }
    
    private func showInfo() {
        showTooltips.toggle()
    }
    
    private func connectionSettings() {
        // Navigate to web view - ensure async to prevent blocking
        Task { @MainActor in
            showWebView = true
        }
    }
}

// MARK: - AR View Representable

struct ARViewRepresentable: UIViewControllerRepresentable {
    @ObservedObject var arTrackingService: ARTrackingService
    let showFieldLines: Bool
    let onTap: (CGPoint) -> Void
    
    func makeUIViewController(context: Context) -> ARViewController {
        let controller = ARViewController()
        controller.arTrackingService = arTrackingService
        controller.showFieldLines = showFieldLines
        controller.onTap = onTap
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        let previousValue = uiViewController.showFieldLines
        uiViewController.showFieldLines = showFieldLines
        
        // Only update visibility if the value actually changed
        if previousValue != showFieldLines {
            uiViewController.updateFieldLinesVisibility()
        }
    }
}

// MARK: - AR View Controller

class ARViewController: UIViewController {
    var arTrackingService: ARTrackingService?
    var showFieldLines: Bool = true
    var onTap: ((CGPoint) -> Void)?
    var arView: ARSCNView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup ARView
        arView = ARSCNView(frame: view.bounds)
        guard let arView = arView else { return }
        
        view.addSubview(arView)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        configuration.isLightEstimationEnabled = true
        
        // Start AR session
        arView.session.run(configuration)
        
        // Set up AR tracking service
        arTrackingService?.setSceneView(arView)
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)
        onTap?(location)
    }
    
    func updateFieldLinesVisibility() {
        // Update field lines visibility through the AR tracking service
        arTrackingService?.setFieldLinesVisibility(showFieldLines)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ensure AR session is running - don't restart if already running
        if arView?.session.delegate == nil {
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal]
            arView?.session.run(configuration)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView?.session.pause()
    }
}

// MARK: - Preview

#Preview {
    ARBaseballTrackerView()
}
