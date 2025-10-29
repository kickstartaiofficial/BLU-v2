//
//  CoachDashboardView.swift
//  BLU-v2
//
//  Modern coach dashboard using SwiftUI and Charts
//

import SwiftUI
import Charts

struct CoachDashboardView: View {
    // MARK: - State Management
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sessionManager = SessionManager()
    @State private var sessionCode = ""
    @State private var showingCodeEntry = true
    @State private var isLoading = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                backgroundView
                
                // Content
                if showingCodeEntry {
                    codeEntryView
                } else {
                    dashboardView
                }
            }
            .navigationTitle("Coach Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
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
    
    private var codeEntryView: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 16) {
                Image("Hey-Blu-title")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: UIScreen.main.bounds.height/2)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 2, y: 2)

                Text("Join as Coach")
                    .font(.system(size:35))
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            // Code Entry Form
            VStack(spacing: 20) {
                Text("Enter Session Code")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("000000", text: $sessionCode)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .onChange(of: sessionCode) { oldValue, newValue in
                        sessionCode = String(newValue.prefix(6).filter { $0.isNumber })
                        if newValue.count == 6 {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
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
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .padding()
    }
    
    private var dashboardView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Connection Status
                connectionStatusView
                
                // Statistics Summary
                statisticsSummaryView
                
                // Speed Chart
                speedChartView
                
                // Recent Pitches
                recentPitchesView
            }
            .padding()
        }
    }
    
    private var connectionStatusView: some View {
        HStack {
            Image(systemName: sessionManager.isJoined ? "wifi" : "wifi.slash")
                .foregroundColor(sessionManager.isJoined ? .green : .red)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(sessionManager.isJoined ? "Connected" : "Disconnected")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(sessionManager.connectionStatus)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var statisticsSummaryView: some View {
        VStack(spacing: 16) {
            Text("Session Statistics")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                StatCard(title: "Pitches", value: "\(sessionManager.currentSession?.pitches.count ?? 0)", color: .blue)
                StatCard(title: "Strikes", value: "\(sessionManager.currentSession?.pitches.filter { $0.isStrike }.count ?? 0)", color: .green)
                StatCard(title: "Balls", value: "\(sessionManager.currentSession?.pitches.filter { !$0.isStrike }.count ?? 0)", color: .red)
            }
            
            if let avgSpeed = sessionManager.currentSession?.statistics.averageSpeed, avgSpeed > 0 {
                HStack {
                    Text("Average Speed:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(String(format: "%.1f", avgSpeed)) mph")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var speedChartView: some View {
        VStack(spacing: 16) {
            Text("Speed Over Time")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let pitches = sessionManager.currentSession?.pitches, !pitches.isEmpty {
                Chart(pitches.enumerated().map { index, pitch in
                    ChartData(index: index, speed: pitch.speed, timestamp: pitch.timestamp)
                }) { data in
                    LineMark(
                        x: .value("Pitch", data.index),
                        y: .value("Speed", data.speed)
                    )
                    .foregroundStyle(.blue)
                    
                    PointMark(
                        x: .value("Pitch", data.index),
                        y: .value("Speed", data.speed)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 200)
            } else {
                Text("No pitch data available")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var recentPitchesView: some View {
        VStack(spacing: 16) {
            Text("Recent Pitches")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let pitches = sessionManager.currentSession?.pitches.suffix(5), !pitches.isEmpty {
                ForEach(Array(pitches.reversed()), id: \.id) { pitch in
                    PitchRowView(pitch: pitch)
                }
            } else {
                Text("No recent pitches")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Actions
    
    private func joinSession() {
        guard sessionCode.count == 6 else { return }
        
        isLoading = true
        
        Task {
            do {
                try await sessionManager.joinSession(code: sessionCode)
                
                await MainActor.run {
                    isLoading = false
                    showingCodeEntry = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // Handle error
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct PitchRowView: View {
    let pitch: PitchData
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(pitch.isStrike ? "STRIKE" : "BALL")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(pitch.isStrike ? .green : .red)
                    
                    Spacer()
                    
                    Text(formatTime(pitch.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("\(String(format: "%.1f", pitch.speed)) mph")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Chart Data

struct ChartData: Identifiable {
    let id = UUID()
    let index: Int
    let speed: Double
    let timestamp: Date
}

// MARK: - Preview

#Preview {
    CoachDashboardView()
}
