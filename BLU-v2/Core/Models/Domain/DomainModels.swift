//
//  DomainModels.swift
//  BLU-v2
//
//  Core domain models for the baseball tracking application
//

import Foundation
import SwiftData
import CoreLocation

// MARK: - Game Session Model

@Model
final class GameSession {
    @Attribute(.unique) var id: String
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var isActive: Bool
    var fieldLocation: FieldLocation?
    var pitches: [PitchData]
    var statistics: GameStatistics
    
    init(
        id: String = UUID().uuidString,
        name: String,
        fieldLocation: FieldLocation? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isActive = true
        self.fieldLocation = fieldLocation
        self.pitches = []
        self.statistics = GameStatistics()
    }
}

// MARK: - Pitch Data Model

@Model
final class PitchData {
    @Attribute(.unique) var id: String
    var sessionCode: String
    var timestamp: Date
    var speed: Double // mph
    var isStrike: Bool
    var ballPosition: BallPosition
    var trajectory: [BallPosition]
    var screenshotData: Data?
    var confidence: Double
    
    init(
        id: String = UUID().uuidString,
        sessionCode: String,
        speed: Double,
        isStrike: Bool,
        ballPosition: BallPosition,
        trajectory: [BallPosition] = [],
        screenshotData: Data? = nil,
        confidence: Double
    ) {
        self.id = id
        self.sessionCode = sessionCode
        self.timestamp = Date()
        self.speed = speed
        self.isStrike = isStrike
        self.ballPosition = ballPosition
        self.trajectory = trajectory
        self.screenshotData = screenshotData
        self.confidence = confidence
    }
}

// MARK: - Supporting Models

struct FieldLocation: Codable, Sendable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let name: String?
    
    init(location: CLLocation, name: String? = nil) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.accuracy = location.horizontalAccuracy
        self.name = name
    }
}

struct BallPosition: Sendable {
    let x: Double
    let y: Double
    let z: Double
    let timestamp: Date
    
    init(x: Double, y: Double, z: Double, timestamp: Date = Date()) {
        self.x = x
        self.y = y
        self.z = z
        self.timestamp = timestamp
    }
}

// MARK: - BallPosition Codable Extension
extension BallPosition: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y, z, timestamp
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.x = try container.decode(Double.self, forKey: .x)
        self.y = try container.decode(Double.self, forKey: .y)
        self.z = try container.decode(Double.self, forKey: .z)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(z, forKey: .z)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

@Model
final class GameStatistics {
    var totalPitches: Int
    var strikes: Int
    var balls: Int
    var averageSpeed: Double
    var maxSpeed: Double
    var minSpeed: Double
    
    init() {
        self.totalPitches = 0
        self.strikes = 0
        self.balls = 0
        self.averageSpeed = 0.0
        self.maxSpeed = 0.0
        self.minSpeed = Double.infinity
    }
    
    func update(with pitch: PitchData) {
        totalPitches += 1
        
        if pitch.isStrike {
            strikes += 1
        } else {
            balls += 1
        }
        
        // Update speed statistics
        maxSpeed = max(maxSpeed, pitch.speed)
        minSpeed = min(minSpeed, pitch.speed)
        
        // Calculate average speed
        let totalSpeed = averageSpeed * Double(totalPitches - 1) + pitch.speed
        averageSpeed = totalSpeed / Double(totalPitches)
    }
}



// MARK: - AR Tracking State

enum ARTrackingState: String, CaseIterable, Sendable {
    case initializing = "Initializing AR..."
    case searchingForHomePlate = "Searching for Home Plate"
    case aligningHomePlate = "Aligning Home Plate"
    case fieldPlaced = "Field Placed"
    case trackingSpeed = "Tracking Speed"
    case error = "Error"
    
    var displayText: String {
        return self.rawValue
    }
    
    var isActive: Bool {
        switch self {
        case .trackingSpeed, .fieldPlaced:
            return true
        default:
            return false
        }
    }
}

// MARK: - Ball Detection Result

struct BallDetectionResult: Sendable {
    let position: BallPosition
    let confidence: Double
    let speed: Double?
    let isStrike: Bool?
    let timestamp: Date
    
    init(
        position: BallPosition,
        confidence: Double,
        speed: Double? = nil,
        isStrike: Bool? = nil
    ) {
        self.position = position
        self.confidence = confidence
        self.speed = speed
        self.isStrike = isStrike
        self.timestamp = Date()
    }
}

// MARK: - Field Configuration

struct FieldConfiguration: Codable, Sendable {
    let homePlatePosition: BallPosition
    let strikeZoneBounds: StrikeZoneBounds
    let pitcherMoundPosition: BallPosition?
    let fieldDimensions: FieldDimensions
    
    init(
        homePlatePosition: BallPosition,
        strikeZoneBounds: StrikeZoneBounds,
        pitcherMoundPosition: BallPosition? = nil,
        fieldDimensions: FieldDimensions = FieldDimensions.standard
    ) {
        self.homePlatePosition = homePlatePosition
        self.strikeZoneBounds = strikeZoneBounds
        self.pitcherMoundPosition = pitcherMoundPosition
        self.fieldDimensions = fieldDimensions
    }
}

struct StrikeZoneBounds: Codable, Sendable {
    let min: BallPosition
    let max: BallPosition
    
    func contains(_ position: BallPosition) -> Bool {
        return position.x >= min.x && position.x <= max.x &&
               position.y >= min.y && position.y <= max.y &&
               position.z >= min.z && position.z <= max.z
    }
}

struct FieldDimensions: Codable, Sendable {
    let strikeZoneWidth: Double
    let strikeZoneHeight: Double
    let homePlateWidth: Double
    let homePlateHeight: Double
    
    static let standard = FieldDimensions(
        strikeZoneWidth: 1.0,
        strikeZoneHeight: 1.5,
        homePlateWidth: 0.43,
        homePlateHeight: 0.22
    )
}
