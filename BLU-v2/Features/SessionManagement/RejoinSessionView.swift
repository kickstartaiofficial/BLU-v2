//
//  RejoinSessionView.swift
//  BLU-v2
//
//  Screen for rejoining a previously hosted session
//

import SwiftUI

struct RejoinSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sessionManager = SessionManager()
    @AppStorage("lastSessionCode") private var lastSessionCode: String = ""
    
    @State private var sessionCode: String = ""
    @State private var errorMessage: String = ""
    @State private var isLoading: Bool = false
    
    var body: some View {
        ZStack {
            // Background Image
            backgroundImageView
            
            // Content Overlay
            HStack(spacing: 20) {
                // Left Side - Title
                leftSideTitle
                
                Spacer()
                
                // Right Side - Session Code Modal
                sessionCodeModal
            }
            .padding(20)
            
            // Custom Back Button
            VStack {
                HStack {
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
                }
                .padding(8)
                //.padding(.top, 50)
                //.padding(.leading, 20)
                
                Spacer()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Pre-populate with last session code if available
            if sessionCode.isEmpty && !lastSessionCode.isEmpty {
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
            // Hey Blu Title Image
            Image("Hey-Blu-title")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: UIScreen.main.bounds.height/2)
                .shadow(color: .black.opacity(0.5), radius: 3, x: 2, y: 2)

            Text("Rejoin Session")
                .font(.system(size:35))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .padding(.leading, 80)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Session Code Modal
    
    private var sessionCodeModal: some View {
        VStack(spacing: 24) {
            // Title
            Text("Enter Your Session Code")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.top, 20)
            
            // Subtitle
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
                    errorMessage = ""
                    if newValue.count == 6 {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            
            // Error Message
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            // Rejoin Session Button
            Button(action: rejoinSession) {
                HStack {
                    if isLoading {
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
                .background(sessionCode.count == 6 && !isLoading ? Color.blue : Color.gray)
                .cornerRadius(12)
            }
            .disabled(sessionCode.count != 6 || isLoading)
            .padding(.bottom, 20)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .frame(width: 320)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Actions
    
    private func rejoinSession() {
        guard sessionCode.count == 6 else { return }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let success = await sessionManager.rejoinSession(sessionCode: sessionCode)
                
                await MainActor.run {
                    isLoading = false
                    
                    if success {
                        // Successfully rejoined session
                        dismiss()
                    } else {
                        errorMessage = "Session not found or you don't have permission to rejoin. Please check the code and try again."
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RejoinSessionView()
}
