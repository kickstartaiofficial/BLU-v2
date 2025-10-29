//
//  ARPositionControlsView.swift
//  BLU-v2
//
//  UI Controls for placing and orienting AR objects
//

import SwiftUI

struct ARPositionControlsView: View {
    // MARK: - Bindings
    
    @Binding var xRange: ClosedRange<Double>
    @Binding var yRange: ClosedRange<Double>
    @Binding var angleRange: ClosedRange<Double>
    @Binding var showFieldLines: Bool
    
    @State private var guiSize: Double = 350
    @State private var angleDegrees: Double = 89
    @State private var xMeters: Double = 0.04
    @State private var yMeters: Double = 0.0
    
    // MARK: - Body
    
    var body: some View {
        ZStack() {
            // Center Content
            arPositionControls
            
            HStack(spacing: 15) {
                // Left Side Controls
                leftSideControls
                
                Spacer()
                
                // Right Side Controls
                rightSideControls
            }
            .padding()
        }
    }
    
    // MARK: - Left Side Controls
    
    private var leftSideControls: some View {
        VStack(spacing: 5) {
            // Scan/Place Button
            ARControlButton(
                icon: "location",
                label: "Scan for Home Plate",
                isHighlighted: true,
                color: .green
            )
            
            Spacer()
            
            // Adjust Orientation Button
            ARControlButton(
                icon: "location.north.line.fill",
                label: "Adjust orientation",
                color: .green
            )
            
            Spacer()
            
            // Show Field Lines Toggle
            ARControlButton(
                icon: "grid",
                label: "Show Field Lines",
                color: showFieldLines ? .green : .gray,
                action: {
                    showFieldLines.toggle()
                }
            )
            
            Spacer()
            
            // Reset Tracking
            ARControlButton(
                icon: "arrow.clockwise",
                label: "Reset Tracking",
                color: .red
            )
        }
        .frame(maxWidth: 150)
    }
    
    // MARK: - Center Controls
    private var arPositionControls: some View {
        
        ZStack(alignment: .center) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial) // nice translucent effect
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 16) {
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
                            valueText: "\(Int(angleDegrees))°",
                            value: $angleDegrees,
                            range: angleRange
                        )
                        .frame(minHeight: guiSize/12)
                        .padding(8)

                        // Pentagram
                        Image(systemName: "pentagon")
                            .font(Font.system(size: 80, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .frame(alignment: .center)
                            .rotationEffect(.degrees(-180))
                        
                        // Left/Right slider
                        LabeledSliderRow(
                            icon: Image(systemName: "arrow.left.and.right.circle"),
                            title: "",
                            valueText: String(format: "", xMeters),
                            value: $xMeters,
                            range: xRange
                        )
                        .frame(minHeight: guiSize/12)
                        .padding(8)
                    }
                    
                    HStack(alignment: .bottom) {
                
                        // Up/Down slider
                        VStack {
                            Slider(value: $yMeters, in: yRange)
                                .tint(.white)
                                .rotationEffect(.degrees(-90))
                                .frame(width: 180, height: 44)
                        }
                        .frame(width: 44, height: 150)
                                                
                        // Up/Down Icon
                        VStack {
                            Image(systemName: "arrow.up.and.down.circle")
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
                    .tint(.orange)

                    Button(action: acceptPosition) {
                        Text("Done")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(.white)
                    .tint(.green)
                }
                .padding(8)

            }
            HStack(alignment: .top, spacing: 16) {
                
            }
            .padding(12)
        }
        .padding(24)
        .frame(width: guiSize, height: guiSize)
    }
    
    // MARK: - Actions
    private func resetAll() {
        angleDegrees = 89
        xMeters = 0.04
        yMeters = 0.0
    }

    private func acceptPosition() {
        // Hook for dismissing or applying changes
        // e.g., notify a view model or environment
        print("Angle: \(angleDegrees), LR: \(xMeters), Height: \(yMeters)")
    }
    
    // MARK: - Labeled horizontal slider row
    private struct LabeledSliderRow: View {
        let icon: Image
        let title: String
        let valueText: String
        @Binding var value: Double
        let range: ClosedRange<Double>

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

                Slider(value: $value, in: range)
                    .tint(.white)
            }
        }
    }
    
    // MARK: - Right Side Controls
    private var rightSideControls: some View {
        VStack(spacing: 5) {
            // Track Ball Button
            ARControlButton(
                icon: "figure.baseball",
                label: "Track Ball",
                color: .red
            )
            
            Spacer()
            
            // Record Session Button
            ARControlButton(
                icon: "camera.fill",
                label: "Record Session",
                color: .red
            )
            
            Spacer()
            
            // Info Button
            ARControlButton(
                icon: "info.circle",
                label: "Toggle Tooltips",
                color: .green
            )
        }
        .frame(maxWidth: 150)
    }
    
    // MARK: - Helper Views
    
    private func positionSlider(label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white)
            
            Slider(value: value, in: range)
                .tint(.blue)
                .frame(width: 80)
            
            Text(String(format: "%.2f", value.wrappedValue))
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - AR Control Button

struct ARControlButton: View {
    let icon: String
    let label: String
    var isHighlighted: Bool = false
    var color: Color = .blue
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            action?()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.white)
            }
            .frame(width: 60, height: 60)
            .background(.ultraThinMaterial)
            .cornerRadius(30)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(isHighlighted ? Color.yellow : color, lineWidth: isHighlighted ? 3 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        
        Text(label)
            .font(.caption2)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Status Slider

struct StatusSlider: View {
    let value: Double
    let activeColor: Color
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 20)
                    
                    // Active fill
                    RoundedRectangle(cornerRadius: 6)
                        .fill(activeColor)
                        .frame(width: 20, height: geometry.size.height * value)
                    
                    // Indicator dot
                    Circle()
                        .fill(activeColor)
                        .frame(width: 16, height: 16)
                        .offset(y: -geometry.size.height * value)
                }
            }
            .frame(height: 100)
            
            // Status label
            Text(value >= 0.8 ? "Good" : "Poor")
                .font(.caption2)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        
        ARPositionControlsView(
            xRange: .constant(-0.5...0.5),
            yRange: .constant(-0.2...0.2),
            angleRange: .constant(-90...90),
            showFieldLines: .constant(true)
        )
    }
}

