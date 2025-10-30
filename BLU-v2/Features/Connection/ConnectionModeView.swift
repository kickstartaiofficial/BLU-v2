//
//  ConnectionModeView.swift
//  BLU-v2
//
//  Connection mode selection screen
//

import SwiftUI

struct ConnectionModeView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Optional callback for mode selection (can be used by parent view)
    var onModeSelected: ((ConnectionMode) -> Void)? = nil
    
    enum ConnectionMode: String, CaseIterable {
        case hostGame = "Umpire Mode"
        case rejoinSession = "Rejoin Session"
        case joinGame = "Spectator Mode"
        
        var icon: String {
            switch self {
            case .hostGame:
                return "wifi.router"
            case .rejoinSession:
                return "arrow.clockwise.circle"
            case .joinGame:
                return "wifi"
            }
        }
        
        var description: String {
            switch self {
            case .hostGame:
                return "Start a new session and invite others to join"
            case .rejoinSession:
                return "Resume hosting an existing session"
            case .joinGame:
                return "Connect to a game as a spectator session"
            }
        }
    }
    
    var body: some View {
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
        VStack(alignment: .center, spacing: 20) {
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
                ForEach(ConnectionMode.allCases, id: \.self) { mode in
                    connectionModeRow(mode: mode)
                    
                    if mode != ConnectionMode.allCases.last {
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.rawValue)
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
    
    private func selectMode(_ mode: ConnectionMode) {
        // Call parent callback if provided
        onModeSelected?(mode)
        
        // Dismiss the view
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    ConnectionModeView()
}
