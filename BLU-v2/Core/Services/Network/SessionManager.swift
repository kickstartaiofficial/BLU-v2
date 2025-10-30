//
//  SessionManager.swift
//  BLU-v2
//
//  Modern session management service using async/await
//

import Foundation
import Combine

// MARK: - Session Manager Protocol

protocol SessionManagerProtocol: ObservableObject {
    var isHosting: Bool { get }
    var isJoined: Bool { get }
    var currentSession: GameSession? { get }
    var connectionStatus: String { get }
    
    func startHostingSession(name: String) async throws -> String
    func joinSession(code: String) async throws
    func leaveSession()
    func broadcastPitch(_ pitch: PitchData) async throws
}

// MARK: - Session Manager Implementation

@MainActor
final class SessionManager: NSObject, SessionManagerProtocol {
    
    // MARK: - Published Properties
    
    @Published var isHosting: Bool = false
    @Published var isJoined: Bool = false
    @Published var currentSession: GameSession?
    @Published var connectionStatus: String = "Not Connected"
    
    // MARK: - Private Properties
    
    private var sessionListener: Any?
    private var pitchListener: Any?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    // Protocol requirement
    func startHostingSession(name: String) async throws -> String {
        return try await startHostingSession(name: name, fieldLocation: nil)
    }
    
    // Convenience method with optional field location
    func startHostingSession(name: String, fieldLocation: FieldLocation?) async throws -> String {
        // Generate session code (matches reference project pattern)
        let sessionCode = generateSessionCode()
        
        // Create local session with session code as ID (matches reference project)
        currentSession = GameSession(
            id: sessionCode,  // Use session code as ID
            name: name,
            fieldLocation: fieldLocation
        )
        
        // Update local state
        isHosting = true
        isJoined = false
        connectionStatus = "Hosting: \(sessionCode)"
        
        // Store session code for persistence/rejoin
        UserDefaults.standard.set(sessionCode, forKey: "lastSessionCode")
        UserDefaults.standard.set(name, forKey: "lastSessionName")
        
        // Store coordinates if available
        if let location = fieldLocation {
            UserDefaults.standard.set(location.latitude, forKey: "lastSessionLatitude")
            UserDefaults.standard.set(location.longitude, forKey: "lastSessionLongitude")
        }
        
        print("✅ Started hosting session: \(sessionCode)")
        return sessionCode
    }
    
    func joinSession(code: String) async throws {
        // Simulate session join for now
        // In a real implementation, this would connect to Firebase
        
        isHosting = false
        isJoined = true
        connectionStatus = "Connected to Test Host"
        
        // Create local session
        currentSession = GameSession(name: "Test Host")
        
        print("✅ Joined session: \(code)")
    }
    
    func joinSession(sessionCode: String) async -> Bool {
        // Simulate joining a session
        // In a real implementation, this would connect to Firebase/network
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // For demo purposes, accept any 6-digit code
        if sessionCode.count == 6 && sessionCode.allSatisfy({ $0.isNumber }) {
            isJoined = true
            isHosting = false
            connectionStatus = "Joined Session"
            
            // Create a mock session
            currentSession = GameSession(
                id: sessionCode,
                name: "Joined Session"
            )
            
            print("✅ Joined session: \(sessionCode)")
            return true
        }
        
        print("❌ Failed to join session: \(sessionCode)")
        return false
    }
    
    func rejoinSession(sessionCode: String) async -> Bool {
        // Simulate rejoining a session
        // In a real implementation, this would verify ownership and reconnect
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // For demo purposes, accept any 6-digit code
        if sessionCode.count == 6 && sessionCode.allSatisfy({ $0.isNumber }) {
            isHosting = true
            isJoined = false
            connectionStatus = "Hosting Session"
            
            // Create a mock session
            currentSession = GameSession(
                id: sessionCode,
                name: "Rejoined Session"
            )
            
            print("✅ Rejoined session: \(sessionCode)")
            return true
        }
        
        print("❌ Failed to rejoin session: \(sessionCode)")
        return false
    }
    
    func leaveSession() {
        sessionListener = nil
        pitchListener = nil
        
        isHosting = false
        isJoined = false
        currentSession = nil
        connectionStatus = "Not Connected"
        
        print("👋 Left session")
    }
    
    /// Update the current session's field location with GPS coordinates
    @MainActor
    func updateSessionLocation(_ fieldLocation: FieldLocation) {
        guard let session = currentSession else {
            print("⚠️ Cannot update location: No active session")
            return
        }
        
        // Update session's field location
        session.fieldLocation = fieldLocation
        session.updatedAt = Date()
        
        // Store coordinates in UserDefaults for persistence (for rejoin functionality)
        UserDefaults.standard.set(fieldLocation.latitude, forKey: "lastSessionLatitude")
        UserDefaults.standard.set(fieldLocation.longitude, forKey: "lastSessionLongitude")
        
        print("📍 Updated session location for session \(session.id): \(fieldLocation.latitude), \(fieldLocation.longitude)")
    }
    
    func broadcastPitch(_ pitch: PitchData) async throws {
        guard isHosting,
              let session = currentSession else {
            throw SessionError.notHosting
        }
        
        // Add pitch to current session
        session.pitches.append(pitch)
        session.statistics.update(with: pitch)
        
        print("📤 Broadcasted pitch: \(pitch.isStrike ? "STRIKE" : "BALL") @ \(String(format: "%.1f", pitch.speed)) mph")
    }
    
    // MARK: - Private Methods
    
    private func generateSessionCode() -> String {
        // Match reference project: Generate 6-digit code with leading zeros (000000-999999)
        return String(format: "%06d", Int.random(in: 0...999999))
    }
}

// MARK: - Session Errors

enum SessionError: LocalizedError {
    case firebaseNotConfigured
    case sessionNotFound
    case notHosting
    case connectionFailed
    
    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            return "Firebase not configured"
        case .sessionNotFound:
            return "Session not found"
        case .notHosting:
            return "Not hosting a session"
        case .connectionFailed:
            return "Connection failed"
        }
    }
}
