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
    @Environment(\.dismiss) private var dismiss
    
    @State private var showPositioningControls = false
    @State private var isTracking = false
    @State private var currentSpeed: Double = 0.0
    @State private var showFieldLines = true
    
    // Positioning control values
    @State private var orientationAngle: Double = 0.0
    @State private var positionX: Double = 0.0
    @State private var positionY: Double = 0.0
    @State private var positionZ: Double = 0.0
    
    var body: some View {
        ZStack {
            // AR View Layer - Single unified AR session
            ARViewRepresentable(
                arTrackingService: arTrackingService,
                showFieldLines: showFieldLines,
                onTap: handleTap
            )
            .ignoresSafeArea()
            
            // Status Bar
            statusBar
            
            // Green Pentagon Placement UI (only when home plate not placed)
            if !arTrackingService.isHomePlatePlaced {
                greenPentagonPlacementView
            }
            
            // Field Lines Toggle (only when home plate is placed)
            if arTrackingService.isHomePlatePlaced {
                fieldLinesToggle
            }
            
            // Positioning Controls Overlay
            if showPositioningControls {
                positioningControlsOverlay
            }
            
            // Control Buttons
            controlButtons
            
            // Ball Speed Display (when tracking)
            if arTrackingService.trackingState == .trackingSpeed {
                ballSpeedDisplay
            }
        }
        .task {
            await initializeAR()
        }
        .onAppear {
            // Ensure landscape orientation is locked
            AppDelegate.orientationLock = .landscape
        }
        .onDisappear {
            // Clean up when view disappears
            arTrackingService.stopTracking()
        }
    }
    
    // MARK: - Status Bar
    
    private var statusBar: some View {
        VStack {
            HStack {
                // Back Button
                Button(action: { dismiss() }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // Tracking Status
                VStack(alignment: .trailing) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Text(arTrackingService.trackingState.displayText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
            }
            .padding(.top, 50)
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    // MARK: - Green Pentagon Placement View
    
    private var greenPentagonPlacementView: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                VStack(spacing: 20) {
                    // Green Pentagon Shape
                    ZStack {
                        // Semi-transparent green pentagon background
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.7))
                            .frame(width: 200, height: 120)
                        
                        VStack(spacing: 12) {
                            // Home Plate Icon
                            HomePlateIcon(size: 60, strokeWidth: 3, color: .white)
                                .shadow(color: .green.opacity(0.6), radius: 8)
                            
                            Text("Tap to Place Home Plate")
                                .foregroundColor(.white)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Green Pentagon Outline (extends beyond the card)
                    HomePlateIcon(size: 120, strokeWidth: 4, color: .green)
                        .opacity(0.6)
                        .shadow(color: .green.opacity(0.8), radius: 12)
                }
                
                Spacer()
            }
            
            Spacer()
        }
        .allowsHitTesting(false) // Allow taps to pass through to AR view
    }
    
    // MARK: - Field Lines Toggle
    
    private var fieldLinesToggle: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button(action: { showFieldLines.toggle() }) {
                    VStack(spacing: 8) {
                        Image(systemName: showFieldLines ? "eye.fill" : "eye.slash.fill")
                            .font(.title2)
                        Text(showFieldLines ? "Hide Lines" : "Show Lines")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(12)
                    .background(showFieldLines ? Color.green.opacity(0.8) : Color.gray.opacity(0.8))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            
            Spacer()
        }
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
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Positioning Controls Overlay
    
    private var positioningControlsOverlay: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                // Title
                Text("Adjust Field Position")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Orientation Control
                VStack(spacing: 8) {
                    Text("Orientation")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        Text("-180°")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Slider(value: $orientationAngle, in: -180...180, step: 1)
                            .accentColor(.green)
                        
                        Text("180°")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text("\(String(format: "%.0f", orientationAngle))°")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                // Position Controls
                VStack(spacing: 12) {
                    HStack {
                        Text("X")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 20)
                        
                        Slider(value: $positionX, in: -2...2, step: 0.1)
                            .accentColor(.blue)
                        
                        Text("\(String(format: "%.1f", positionX))")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Y")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 20)
                        
                        Slider(value: $positionY, in: -1...1, step: 0.1)
                            .accentColor(.red)
                        
                        Text("\(String(format: "%.1f", positionY))")
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("Z")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 20)
                        
                        Slider(value: $positionZ, in: -2...2, step: 0.1)
                            .accentColor(.purple)
                        
                        Text("\(String(format: "%.1f", positionZ))")
                            .font(.caption)
                            .foregroundColor(.purple)
                            .frame(width: 40)
                    }
                }
                
                // Action Buttons
                HStack(spacing: 20) {
                    Button("Cancel") {
                        hidePositioningControls()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(12)
                    
                    Button("Done") {
                        confirmPositioning()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(12)
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .padding(.horizontal, 40)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Control Buttons
    
    private var controlButtons: some View {
        VStack {
            Spacer()
            
            HStack {
                // Left Side Controls
                VStack(spacing: 16) {
                    // Adjust Orientation Button
                    Button(action: showPositioningControlsView) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(12)
                    }
                    .disabled(!arTrackingService.isHomePlatePlaced)
                    
                    // Reset Tracking Button
                    Button(action: resetTracking) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(12)
                    }
                }
                
                Spacer()
                
                // Right Side Controls
                VStack(spacing: 16) {
                    // Camera Button
                    Button(action: captureScreenshot) {
                        Image(systemName: "camera")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(12)
                    }
                    .disabled(!arTrackingService.isHomePlatePlaced)
                    
                    // Info Button
                    Button(action: showInfo) {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
    }
    
    // MARK: - Actions
    
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
    
    private func hidePositioningControls() {
        showPositioningControls = false
        arTrackingService.hidePositioningControls()
    }
    
    private func confirmPositioning() {
        arTrackingService.adjustOrientation(orientationAngle)
        arTrackingService.adjustPosition(x: positionX, y: positionY, z: positionZ)
        arTrackingService.confirmPositioning()
        hidePositioningControls()
    }
    
    private func resetTracking() {
        arTrackingService.resetTracking()
        showPositioningControls = false
        orientationAngle = 0.0
        positionX = 0.0
        positionY = 0.0
        positionZ = 0.0
        showFieldLines = true
    }
    
    private func captureScreenshot() {
        // TODO: Implement screenshot capture
        print("📸 Capturing screenshot")
    }
    
    private func showInfo() {
        // TODO: Implement info display
        print("ℹ️ Showing info")
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
        uiViewController.showFieldLines = showFieldLines
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