//
//  SessionInfoCardView.swift
//  BLU-v2
//
//  High-end session info card with built-in iOS share sheet and map
//

import SwiftUI
import MapKit
import CoreLocation
import UIKit

struct SessionInfoCardView: View {
    let sessionCode: String
    let sessionName: String?
    let location: CLLocation?
    let onDismiss: () -> Void
    
    @State private var showShareSheet = false
    @State private var showCopiedFeedback = false
    @State private var mapRegion: MapCameraPosition?
    
    var body: some View {
        VStack(spacing: 0) {
                    
            // Header with title and close button
            HStack {
                Text("Session Info")
                    .font(.title)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 5)
            
            // Two-column layout: Map (left) | Session Code & Controls (right)
            HStack(spacing: 0) {
                // LEFT SIDE: Map with Lat/Long
                leftSideMapView
                    .frame(maxWidth: 270)
                
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1)
                
                // RIGHT SIDE: Session Code & Buttons
                rightSideControls
                    .frame(maxWidth: 270)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.65)
        .frame(height: 360)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: -10)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareText])
        }
    }
    
    // MARK: - Drag Handle
    
    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.white.opacity(0.5))
            .frame(width: 40, height: 5)
            .padding(.bottom, 12)
    }
    
    // MARK: - Left Side: Map View
    
    private var leftSideMapView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Field Location")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)
                .padding(.leading, 20)
            
            // Map - iOS 17+ API
            if let location = location, let region = mapRegion {
                Map(position: Binding(
                    get: { region },
                    set: { mapRegion = $0 }
                )) {
                    Marker("Field Location", coordinate: location.coordinate)
                        .tint(.green)
                }
                .mapStyle(.standard)
                .frame(width: 260, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                //.padding(.horizontal, 20)
                .padding(.top, 8)
            } else {
                // Placeholder when location unavailable
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.6))
                        Text("Location unavailable")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            
            // Lat/Long coordinates under map
            if let location = location {
                VStack(spacing: 4) {
                    Text(String(format: "Lat: %.6f", location.coordinate.latitude))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(String(format: "Lng: %.6f", location.coordinate.longitude))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.top, 12)
                .padding(.horizontal, 20)
            } else {
                Text("Location unavailable")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 12)
                    .padding(.leading, 20)
            }
        }
        .onAppear {
            updateMapRegion()
        }
        .onChange(of: location) { _, _ in
            updateMapRegion()
        }
    }
    
    // MARK: - Right Side: Controls
    
    private var rightSideControls: some View {
        VStack(spacing: 20) {
            // Session Code with Copy Button
            VStack(alignment: .leading, spacing: 12) {
                Text("Session Code")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)
                
                HStack(spacing: 12) {
                    Text(sessionCode)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    // Copy Button
                    Button(action: copySessionCode) {
                        Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(showCopiedFeedback ? .green : .white.opacity(0.9))
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(showCopiedFeedback ? Color.green.opacity(0.3) : Color.white.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(
                                                showCopiedFeedback ? Color.green.opacity(0.5) : Color.white.opacity(0.3),
                                                lineWidth: 1
                                            )
                                    )
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showCopiedFeedback)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
                        
            // Action Buttons
            VStack(spacing: 12) {
                // Share Button
                Button(action: {
                    showShareSheet = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Share")
                            .font(.system(size: 17, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.blue.opacity(0.85))
                    )
                }
                
                // Go to Website Button
                Button(action: {
                    if let url = URL(string: "https://blu-baseball.app") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "safari")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Website")
                            .font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Map Helper
    
    private func updateMapRegion() {
        guard let location = location else {
            mapRegion = nil
            return
        }
        
        // Set map region to center on session location with ~500m view (iOS 17+)
        let coordinateRegion = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        mapRegion = .region(coordinateRegion)
    }
    
    // MARK: - Share Text
    
    private var shareText: String {
        let message = """
        Join my baseball AR session!
        
        Session Code: \(sessionCode)
        
        Use this ID to join the session in the BLU Baseball AR app.
        """
        
        if let sessionName = sessionName, !sessionName.isEmpty {
            return "Session: \(sessionName)\n\n" + message
        }
        
        return message
    }
    
    // MARK: - Actions
    
    private func copySessionCode() {
        UIPasteboard.general.string = sessionCode
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopiedFeedback = true
        }
        
        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showCopiedFeedback = false
            }
        }
    }
}

// MARK: - Map Annotation Helper


// MARK: - Share Sheet (iOS Built-in)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            
            SessionInfoCardView(
                sessionCode: "123456",
                sessionName: "My Game Session",
                location: CLLocation(latitude: 37.7749, longitude: -122.4194),
                onDismiss: {}
            )
        }
    }
}

