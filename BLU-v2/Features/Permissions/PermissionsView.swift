//
//  PermissionsView.swift
//  BLU-v2
//
//  Initial permissions screen for camera, location, and photos access
//

import SwiftUI
import AVFoundation
import Photos
import CoreLocation
import UIKit
import Combine

struct PermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedPermissions") private var hasCompletedPermissions = false
    @StateObject private var permissionsManager = PermissionsManager()
    
    @State private var cameraGranted = false
    @State private var locationGranted = false
    @State private var photosGranted = false
    @State private var allPermissionsGranted = false
    @State private var showingConnectionMode = false
    
    var body: some View {
        ZStack {
            // Background Image
            backgroundImageView
            
            // Content Overlay
            HStack(spacing: 20) {
                // Left Side - Title
                leftSideTitle
                
                Spacer()
                
                // Right Side - Permissions Modal
                permissionsModal
            }
            //.padding(.horizontal, 20)
            .padding(20)
        }
        .ignoresSafeArea()
        .task {
            await checkPermissions()
            
            // Auto-proceed if all permissions already granted
            if allPermissionsGranted {
                hasCompletedPermissions = true
                showingConnectionMode = true
            }
        }
        .fullScreenCover(isPresented: $showingConnectionMode) {
            ConnectionModeView()
        }
        .onReceive(permissionsManager.$hasLocationPermission) { hasPermission in
            locationGranted = hasPermission
            checkAllPermissionsAndProceed()
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

            Text("AR Baseball Tracker")
                .font(.system(size:35))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .padding(.leading, 80)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Permissions Modal
    
    private var permissionsModal: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            Text("Permissions")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.bottom, 24)
            
            // Permission List
            VStack(spacing: 12) {
                permissionRow(
                    icon: "camera.fill",
                    title: "Camera Access",
                    description: "Required for AR field tracking",
                    granted: $cameraGranted,
                    action: requestCameraPermission
                )
                
                permissionRow(
                    icon: "location.fill",
                    title: "Location Access",
                    description: "Required for field positioning",
                    granted: $locationGranted,
                    action: requestLocationPermission
                )
                
                permissionRow(
                    icon: "photo.on.rectangle",
                    title: "Photos Access",
                    description: "Required for saving screenshots",
                    granted: $photosGranted,
                    action: requestPhotosPermission
                )
            }
            
            Spacer()
            
            // Continue Button (only shown when all permissions granted)
            if allPermissionsGranted {
                Button(action: {
                    hasCompletedPermissions = true
                    showingConnectionMode = true
                }) {
                    HStack {
                        Image(systemName: "arrow.right")
                        Text("Continue to Setup")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
            } else {
                // Instructions when permissions not all granted
                VStack(spacing: 8) {
                    Text("Tap each permission above to enable access")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("All permissions are required to continue")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .frame(width: 320)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Permission Row
    
    private func permissionRow(icon: String, title: String, description: String, granted: Binding<Bool>, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(granted.wrappedValue ? .green : .blue)
                    .frame(width: 32, height: 32)
                
                // Title and Description
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                if granted.wrappedValue {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(granted.wrappedValue ? Color.green.opacity(0.1) : Color.blue.opacity(0.05))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Actions
    
    private func checkPermissions() async {
        print("Checking permissions...")
        
        // Check camera permission
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        cameraGranted = cameraStatus == .authorized
        print("Camera status: \(cameraStatus.rawValue), granted: \(cameraGranted)")
        
        // Check location permission - using instance method instead of deprecated class method
        let locationStatus = permissionsManager.locationManager.authorizationStatus
        locationGranted = locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways
        print("Location status: \(locationStatus.rawValue), granted: \(locationGranted)")
        
        // Check photos permission
        let photosStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photosGranted = photosStatus == .authorized || photosStatus == .limited
        print("Photos status: \(photosStatus.rawValue), granted: \(photosGranted)")
        
        // Update all permissions flag
        allPermissionsGranted = cameraGranted && locationGranted && photosGranted
        print("All permissions granted: \(allPermissionsGranted)")
    }
    
    private func requestCameraPermission() {
        Task {
            print("Requesting camera permission...")
            await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                cameraGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
                print("Camera permission granted: \(cameraGranted)")
                checkAllPermissionsAndProceed()
            }
        }
    }
    
    private func requestLocationPermission() {
        Task {
            print("Requesting location permission...")
            
            // Request permission on main thread
            await MainActor.run {
                switch permissionsManager.locationManager.authorizationStatus {
                case .notDetermined:
                    permissionsManager.locationManager.requestWhenInUseAuthorization()
                case .denied, .restricted:
                    // Permission denied, show error or open settings
                    print("Location permission denied")
                case .authorizedWhenInUse, .authorizedAlways:
                    // Already granted
                    break
                @unknown default:
                    break
                }
            }
            
            // Wait a moment for the system to process the request
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Update the UI state
            await MainActor.run {
                let status = permissionsManager.locationManager.authorizationStatus
                locationGranted = status == .authorizedWhenInUse || status == .authorizedAlways
                print("Location permission granted: \(locationGranted)")
                checkAllPermissionsAndProceed()
            }
            
            // Fallback: Check again after a longer delay in case the delegate didn't fire
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await MainActor.run {
                let status = permissionsManager.locationManager.authorizationStatus
                let newLocationGranted = status == .authorizedWhenInUse || status == .authorizedAlways
                if newLocationGranted != locationGranted {
                    locationGranted = newLocationGranted
                    print("Location permission updated (fallback): \(locationGranted)")
                    checkAllPermissionsAndProceed()
                }
            }
        }
    }
    
    private func requestPhotosPermission() {
        Task {
            print("Requesting photos permission...")
            await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            await MainActor.run {
                let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                photosGranted = status == .authorized || status == .limited
                print("Photos permission granted: \(photosGranted)")
                checkAllPermissionsAndProceed()
            }
        }
    }
    
    private func checkAllPermissionsAndProceed() {
        allPermissionsGranted = cameraGranted && locationGranted && photosGranted
        print("All permissions granted: \(allPermissionsGranted)")
        
        if allPermissionsGranted {
            print("All permissions granted, showing connection mode")
            // Add a small delay to ensure UI updates are complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                hasCompletedPermissions = true
                showingConnectionMode = true
            }
        }
    }
}

// MARK: - Permissions Manager

class PermissionsManager: NSObject, ObservableObject {
    @Published var hasLocationPermission = false
    let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        hasLocationPermission = locationManager.authorizationStatus == .authorizedWhenInUse || 
                               locationManager.authorizationStatus == .authorizedAlways
    }
    
    func requestLocationPermission() async {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
    }
}

extension PermissionsManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.hasLocationPermission = manager.authorizationStatus == .authorizedWhenInUse || 
                                         manager.authorizationStatus == .authorizedAlways
            print("Location permission changed: \(self.hasLocationPermission)")
        }
    }
}

// MARK: - Preview

#Preview {
    PermissionsView()
}

