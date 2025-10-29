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
    
    func startHostingSession(name: String) async throws -> String {
        // Generate session code
        let sessionCode = generateSessionCode()
        
        // Update local state
        isHosting = true
        isJoined = false
        connectionStatus = "Hosting: \(sessionCode)"
        
        // Create local session
        currentSession = GameSession(name: name)
        
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
        return String(format: "%06d", Int.random(in: 100000...999999))
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
