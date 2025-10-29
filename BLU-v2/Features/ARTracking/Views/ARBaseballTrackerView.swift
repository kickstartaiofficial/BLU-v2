//
//  ARBaseballTrackerView.swift
//  BLU-v2
//
//  Main AR view for baseball tracking with UI controls
//

import SwiftUI
import ARKit

struct ARBaseballTrackerView: View {
    @StateObject private var arTrackingService = ARTrackingService()
    @StateObject private var ballTracker = BallTrackerService()
    
    @State private var xRange: ClosedRange<Double> = -2.0...2.0
    @State private var yRange: ClosedRange<Double> = -1.0...1.0
    @State private var angleRange: ClosedRange<Double> = -180.0...180.0
    @State private var showFieldLines = true
    @State private var isTracking = false
    
    var body: some View {
        ZStack {
            // AR View Layer
            ARViewRepresentable(
                arTrackingService: arTrackingService,
                showFieldLines: showFieldLines
            )
            .ignoresSafeArea()
            
            bottomControls
        
        }
        .task {
            await startAR()
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

    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        ARPositionControlsView(
            xRange: $xRange,
            yRange: $yRange,
            angleRange: $angleRange,
            showFieldLines: $showFieldLines
        )
        //.background(.ultraThinMaterial)
    }
    
    // MARK: - Actions
    
    private func startAR() async {
        do {
            try await arTrackingService.startTracking()
            isTracking = true
        } catch {
            print("Failed to start AR: \(error)")
        }
    }
}

// MARK: - AR View Representable

struct ARViewRepresentable: UIViewControllerRepresentable {
    @ObservedObject var arTrackingService: ARTrackingService
    let showFieldLines: Bool
    
    func makeUIViewController(context: Context) -> ARViewController {
        let controller = ARViewController()
        controller.arTrackingService = arTrackingService
        controller.showFieldLines = showFieldLines
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        // Update any properties if needed
    }
}

// MARK: - AR View Controller

import UIKit

class ARViewController: UIViewController {
    var arTrackingService: ARTrackingService?
    var showFieldLines: Bool = false
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
        
        arView.session.run(configuration)
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

