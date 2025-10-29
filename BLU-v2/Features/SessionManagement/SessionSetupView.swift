//
//  SessionSetupView.swift
//  BLU-v2
//
//  Modern session setup interface using SwiftUI
//

import SwiftUI

struct SessionSetupView: View {
    // MARK: - State Management
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sessionManager = SessionManager()
    @State private var sessionName = ""
    @State private var sessionCode = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                backgroundView
                
                // Content
                VStack(spacing: 30) {
                    // Header
                    headerView
                    
                    // Session Setup Form
                    sessionSetupForm
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Session Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Session Setup", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - View Components
    
    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.2, blue: 0.1),
                Color(red: 0.2, green: 0.3, blue: 0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Image("Hey-Blu-title")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: UIScreen.main.bounds.height/2)
                .shadow(color: .black.opacity(0.5), radius: 3, x: 2, y: 2)

            Text("Create or Join Session")
                .font(.system(size:35))
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.top, 20)
    }
    
    private var sessionSetupForm: some View {
        VStack(spacing: 24) {
            // Host Session Section
            VStack(spacing: 16) {
                Text("Host New Session")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("Session Name", text: $sessionName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.words)
                
                Button(action: hostSession) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "person.2.fill")
                        }
                        Text("Host Session")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(sessionName.isEmpty ? Color.gray : Color.green)
                    .cornerRadius(12)
                }
                .disabled(sessionName.isEmpty || isLoading)
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Join Session Section
            VStack(spacing: 16) {
                Text("Join Existing Session")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("Session Code", text: $sessionCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .onChange(of: sessionCode) { _, newValue in
                        sessionCode = String(newValue.prefix(6).filter { $0.isNumber })
                    }
                
                Button(action: joinSession) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "wifi")
                        }
                        Text("Join Session")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(sessionCode.count != 6 ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(sessionCode.count != 6 || isLoading)
                .padding(10)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Actions
    
    private func hostSession() {
        guard !sessionName.isEmpty else { return }
        
        isLoading = true
        
        Task {
            do {
                let sessionCode = try await sessionManager.startHostingSession(name: sessionName)
                
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Session created! Code: \(sessionCode)"
                    showingAlert = true
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Failed to create session: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func joinSession() {
        guard sessionCode.count == 6 else { return }
        
        isLoading = true
        
        Task {
            do {
                try await sessionManager.joinSession(code: sessionCode)
                
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Successfully joined session!"
                    showingAlert = true
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Failed to join session: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SessionSetupView()
}
