//
//  ARPositionControlsView.swift
//  BLU-v2
//
//  UI Controls for placing and orienting AR objects
//

import SwiftUI
import CoreLocation

struct ARPositionControlsView: View {
    // MARK: - Properties
    
    @ObservedObject var arTrackingService: ARTrackingService
    @Binding var showFieldLines: Bool
    let onDone: () -> Void
    let onCancel: () -> Void
    
    @State private var guiSize: Double = 350
    @State private var angleDegrees: Double = 0.0
    @State private var xMeters: Double = 0.0
    @State private var zMeters: Double = 0.0
    
    // Ranges (20cm = 0.2m for position, 45 degrees for rotation)
    private let angleRange: ClosedRange<Double> = -45...45
    private let xRange: ClosedRange<Double> = -0.2...0.2  // 20cm left/right
    private let zRange: ClosedRange<Double> = -0.2...0.2  // 20cm forward/backward
    
    // Increments
    private let angleStep: Double = 0.5  // 0.5 degrees
    private let positionStep: Double = 0.005  // 0.5cm = 0.005m
    
    // MARK: - Body
    
    var body: some View {
        arPositionControls
    }
    
    // MARK: - Center Controls
    
    private var arPositionControls: some View {
        
        ZStack() {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.1)) // nice translucent effect
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

            VStack(spacing: 8) {
                // Title
                Text("Field Adjustments")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(minHeight: guiSize/12)
                    .padding(.top, 8)
                
                // Sliders
                HStack(spacing: 5) {
                    // Left column: title + two horizontal sliders + actions
                    VStack(alignment: .center, spacing: 5) {
                        // Angle row
                        LabeledSliderRow(
                            icon: Image(systemName: "arrow.trianglehead.clockwise.rotate.90"),
                            title: "",
                            valueText: String(format: "%.1f°", angleDegrees),
                            value: $angleDegrees,
                            range: angleRange,
                            step: angleStep,
                            onChange: { newValue in
                                // Direct call - debouncing handled in ARTrackingService
                                arTrackingService.adjustOrientation(newValue)
                            }
                        )
                        .frame(minHeight: guiSize/12)
                        .padding(8)
                        
                        ZStack{
                            // Home Plate Icon
                            HomePlateIcon(size: 100, strokeWidth: 3, color: .white)
                                .shadow(color: .green.opacity(0.6), radius: 8)
                                .padding(8)
                                .frame(alignment: .center)
                            
                            Image(systemName: "location.viewfinder")
                                .font(.title)
                        }
                                                
                        // Left/Right slider (X-axis)
                        LabeledSliderRow(
                            icon: Image(systemName: "arrow.left.and.right.circle"),
                            title: "",
                            valueText: String(format: "%.2fcm", xMeters * 100),  // Display in cm
                            value: $xMeters,
                            range: xRange,
                            step: positionStep,
                            onChange: { newValue in
                                // Direct call - debouncing handled in ARTrackingService
                                arTrackingService.adjustPosition(x: newValue, y: 0.0, z: zMeters)
                            }
                        )
                        .frame(minHeight: guiSize/12)
                        .padding(8)
                    }
                    
                    HStack(alignment: .bottom) {
                
                        // Forward/Backward slider (Z-axis)
                        VStack {
                            Slider(value: $zMeters, in: zRange, step: positionStep)
                                .tint(.white)
                                .rotationEffect(.degrees(-90))
                                .frame(width: 180, height: 44)
                                .onChange(of: zMeters) { _, newValue in
                                    // Direct call - debouncing handled in ARTrackingService
                                    arTrackingService.adjustPosition(x: xMeters, y: 0.0, z: -newValue)
                                }
                        }
                        .frame(width: 44, height: 150)
                                                
                        // Forward/Backward Icon
                        VStack {
                            Image(systemName: "arrow.up.and.down.circle")  // This represents forward/backward in AR space
                            Spacer()
                        }
                        
                        Spacer()

                    }
                    .frame(width: 100, height: 150)
                    .foregroundStyle(.white)
                }
                
                // Buttons
                HStack(spacing: 5) {
                    Button(role: .destructive, action: resetAll) {
                        Text("Reset")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red.opacity(0.5))
                    
                    Button(action: cancelScreen) {
                        Text("Cancel")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange.opacity(0.5))

                    Button(action: acceptPosition) {
                        Text("Done")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(.white)
                    .tint(.green.opacity(0.5))
                }
                .padding(8)

                gpsCoordinatesDisplay
                    .padding(.bottom, 15)
            }
        }
        .padding(24)
        .frame(width: guiSize*1.3, height: guiSize)
    }
    
    // MARK: - GPS Coordinates Display
    
    private var gpsCoordinatesDisplay: some View {
        HStack(spacing: 2) {
            if let location = arTrackingService.currentLocation {
                HStack(spacing: 2) {
                    Image(systemName: "location")
                        .foregroundStyle(.white.opacity(0.9))
                    
                    Text("Lat.: \(location.coordinate.latitude, specifier: "%.6f")°")
                        .foregroundStyle(.white)
                        .font(.caption.monospacedDigit())
                    
                    Text("Long.: \(location.coordinate.longitude, specifier: "%.6f")°")
                        .foregroundStyle(.white)
                        .font(.caption.monospacedDigit())
                    
                    if location.altitude != -1 {
                        Text("Alt.: \(location.altitude, specifier: "%.1f")m")
                            .foregroundStyle(.white)
                            .font(.caption.monospacedDigit())
                    }
                }
            } else {
                Text("Location unavailable")
                    .foregroundStyle(.white.opacity(0.6))
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Actions
    private func resetAll() {
        // Reset AR tracking - removes anchoring and closes the slider screen
        arTrackingService.resetTracking()
        
        // Reset local state
        angleDegrees = 0.0
        xMeters = 0.0
        zMeters = 0.0
        
        // Close the positioning controls screen
        onCancel()
    }
    
    private func cancelScreen() {
        // Just close the positioning controls screen without changing anything
        onCancel()
    }
    
    private func acceptPosition() {
        // IMPORTANT: Set slider values first, then confirm immediately
        // The confirmPositioning() method will use these exact values to calculate anchor position
        arTrackingService.adjustOrientation(angleDegrees)
        arTrackingService.adjustPosition(x: xMeters, y: 0.0, z: zMeters)
        
        // Confirm positioning synchronously using the exact slider values we just set
        // This ensures no jump because anchor is calculated from slider values, not container position
        arTrackingService.confirmPositioning()
        onDone()
    }
    
    // MARK: - Labeled horizontal slider row
    private struct LabeledSliderRow: View {
        let icon: Image
        let title: String
        let valueText: String
        @Binding var value: Double
        let range: ClosedRange<Double>
        let step: Double
        let onChange: ((Double) -> Void)?

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    icon
                        .foregroundStyle(.white.opacity(0.9))
                    Text(title)
                        .foregroundStyle(.white.opacity(0.9))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(valueText)
                        .foregroundStyle(.white)
                        .font(.subheadline.monospacedDigit())
                }

                Slider(value: $value, in: range, step: step)
                    .tint(.white)
                    .onChange(of: value) { _, newValue in
                        onChange?(newValue)
                    }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        
        ARPositionControlsView(
            arTrackingService: ARTrackingService(),
            showFieldLines: .constant(true),
            onDone: {},
            onCancel: {}
        )
    }
}

