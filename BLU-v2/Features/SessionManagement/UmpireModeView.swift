//
//  UmpireModeView.swift
//  BLU-v2
//
//  Umpire Mode screen with Create New Session and Rejoin Session options
//

import SwiftUI

struct UmpireModeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionManager: SessionManager
    @AppStorage("lastSessionCode") private var lastSessionCode: String = ""
    @AppStorage("lastSessionName") private var lastSessionName: String = ""
    
    @State private var showingRejoinEntry = false
    @State private var isCreatingSession = false
    @State private var sessionCode: String = ""
    
    var onNavigateToAR: () -> Void
    
    var body: some View {
        ZStack {
            // Background Image
            backgroundImageView
            
            // Content Overlay
            HStack(spacing: 20) {
                // Left Side - Title
                leftSideTitle
                
                Spacer()
                
                // Right Side - Options Modal
                if showingRejoinEntry {
                    rejoinSessionModal
                } else {
                    umpireModeOptionsModal
                }
            }
            .padding(20)
            
            // Custom Back Button
            VStack {
                HStack {
                    Button(action: { 
                        if showingRejoinEntry {
                            showingRejoinEntry = false
                        } else {
                            dismiss()
                        }
                    }) {
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
                }
                .padding(8)
                
                Spacer()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Pre-populate with last session code if available
            if !lastSessionCode.isEmpty {
                sessionCode = lastSessionCode
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
            Image("Hey-Blu-title")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: UIScreen.main.bounds.height/2)
                .shadow(color: .black.opacity(0.5), radius: 3, x: 2, y: 2)

            Text("Umpire operMode")
                .font(.system(size: 35))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .padding(.leading, 80)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Umpire Mode Options Modal
    
    private var umpireModeOptionsModal: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Umpire Mode")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.bottom, 24)
            
            VStack(spacing: 0) {
                // Create New Session Option
                Button(action: {
                    createNewSession()
                }) {
                    umpireModeRow(
                        icon: "plus.circle.fill",
                        title: "Create New Session",
                        description: "Start a new session and go to AR",
                        color: .green
                    )
                }
                .disabled(isCreatingSession)
                
                Divider()
                    .padding(.vertical, 5)
                
                // Rejoin Session Option
                Button(action: {
                    showingRejoinEntry = true
                }) {
                    umpireModeRow(
                        icon: "arrow.clockwise.circle.fill",
                        title: "Rejoin Session",
                        description: "Resume hosting an existing session",
                        color: .blue
                    )
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .frame(width: 320)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    private func umpireModeRow(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.blue)
                .font(.caption)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .background(Color.clear)
    }
    
    // MARK: - Rejoin Session Modal
    
    private var rejoinSessionModal: some View {
        VStack(spacing: 24) {
            Text("Enter Your Session Code")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.top, 20)
            
            Text("Resume hosting your existing session")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Session Code Entry
            TextField("000000", text: $sessionCode)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .frame(maxWidth: 300)
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .onChange(of: sessionCode) { _, newValue in
                    sessionCode = String(newValue.prefix(6).filter { $0.isNumber })
                    if newValue.count == 6 {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            
            // Rejoin Session Button
            Button(action: rejoinSession) {
                HStack {
                    if isCreatingSession {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise.circle")
                    }
                    Text("Rejoin Session")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: 300)
                .padding()
                .background(sessionCode.count == 6 && !isCreatingSession ? Color.blue : Color.gray)
                .cornerRadius(12)
            }
            .disabled(sessionCode.count != 6 || isCreatingSession)
            .padding(.bottom, 20)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .frame(width: 320)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Actions
    
    private func createNewSession() {
        guard !isCreatingSession else { return }
        isCreatingSession = true
        
        Task {
            do {
                let sessionCode = try await sessionManager.startHostingSession(name: UIDevice.current.name)
                
                await MainActor.run {
                    lastSessionCode = sessionCode
                    lastSessionName = UIDevice.current.name
                    isCreatingSession = false
                    
                    // Navigate to AR tracking
                    onNavigateToAR()
                    print("✅ Session created: \(sessionCode) - Navigating to AR tracking")
                }
            } catch {
                    await MainActor.run {
                    isCreatingSession = false
                    print("❌ Failed to create session: \(error)")
                }
            }
        }
    }
    
    private func rejoinSession() {
        guard sessionCode.count == 6, !isCreatingSession else { return }
        
        isCreatingSession = true
        
        Task {
            let success = await sessionManager.rejoinSession(sessionCode: sessionCode)
            
            await MainActor.run {
                isCreatingSession = false
                
                if success {
                    // Store the session code for future use
                    lastSessionCode = sessionCode
                    
                    // Navigate to AR tracking
                    onNavigateToAR()
                    print("✅ Rejoined session: \(sessionCode) - Navigating to AR tracking")
                } else {
                    print("❌ Failed to rejoin session: \(sessionCode)")
                    // Could show an alert here
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    UmpireModeView(onNavigateToAR: {})
        .environmentObject(SessionManager())
}

