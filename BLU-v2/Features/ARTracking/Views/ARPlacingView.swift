//
//  ARPlacingView.swift
//  BLU-v2
//
//  Initial AR placement UI for home plate and field setup
//

import SwiftUI
import ARKit

struct ARPlacingView: View {
    @ObservedObject var arTrackingService: ARTrackingService
    @State private var showHomePlatePrompt = true
    @State private var isPlacingField = false
    
    var body: some View {
        ZStack {
            // Background AR content would go here
            
            // Placement Instructions
            if showHomePlatePrompt && arTrackingService.trackingState == .searchingForField {
                placementPrompt
            }
            
            // Field Mapping Indicator
            if isPlacingField {
                fieldMappingIndicator
            }
        }
    }
    
    // MARK: - Placement Prompt
    
    private var placementPrompt: some View {
        VStack(spacing: 20) {
            // Home Plate Icon
            Image(systemName: "square.and.arrow.down.fill")
                .font(.system(size: 60))
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                Text("Tap to Place Home Plate")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Point your device at the home plate area")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(30)
        .background(Color.black.opacity(0.7))
        .cornerRadius(20)
        .shadow(radius: 10)
    }
    
    // MARK: - Field Mapping Indicator
    
    private var fieldMappingIndicator: some View {
        VStack(spacing: 15) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .green))
                .scaleEffect(1.5)
            
            Text("Mapping Field...")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Scanning your environment")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(20)
        .background(Color.black.opacity(0.8))
        .cornerRadius(15)
    }
    
    // MARK: - Actions
    
    func handleTap(at location: CGPoint) {
        if showHomePlatePrompt {
            // Start field mapping
            Task {
                isPlacingField = true
                do {
                    try await arTrackingService.calibrateField()
                    showHomePlatePrompt = false
                    isPlacingField = false
                } catch {
                    isPlacingField = false
                    print("Failed to calibrate field: \(error)")
                }
            }
        }
    }
}

// MARK: - Field Lines Overlay

struct FieldLinesOverlay: View {
    let showLines: Bool
    let fieldConfiguration: FieldConfiguration?
    
    var body: some View {
        if showLines, let _ = fieldConfiguration {
            ZStack {
                // Strike Zone Visualization
                strikeZoneOverlay
                
                // Field Boundaries
                fieldBoundariesOverlay
            }
        }
    }
    
    private var strikeZoneOverlay: some View {
        VStack {
            // This would render 3D strike zone in AR
            // For now, show a simplified 2D representation
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.green, lineWidth: 3)
                .frame(width: 100, height: 150)
                .opacity(0.6)
        }
    }
    
    private var fieldBoundariesOverlay: some View {
        VStack {
            // Field outline would go here
            Path { path in
                // Draw infield diamond
                path.move(to: CGPoint(x: 0, y: 150))
                path.addLine(to: CGPoint(x: 150, y: 0))
                path.addLine(to: CGPoint(x: 300, y: 150))
                path.addLine(to: CGPoint(x: 150, y: 300))
                path.closeSubpath()
            }
            .stroke(Color.green.opacity(0.5), lineWidth: 2)
        }
    }
}

// MARK: - Preview

#Preview {
    ARPlacingView(arTrackingService: ARTrackingService())
        .background(Color.black)
}

