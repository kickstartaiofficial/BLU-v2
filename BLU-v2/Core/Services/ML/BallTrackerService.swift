//
//  BallTrackerService.swift
//  BLU-v2
//
//  Modern ML-powered ball tracking service using Vision framework
//

import Foundation
import Vision
import CoreML
import ARKit
import Combine

// MARK: - Ball Tracker Delegate Protocol

protocol BallTrackerDelegate: AnyObject {
    func didDetectBall(_ result: BallDetectionResult)
}

// MARK: - Ball Tracker Service Protocol

protocol BallTrackerServiceProtocol: ObservableObject {
    var isTracking: Bool { get }
    var detectionConfidence: Double { get }
    
    func startTracking() async throws
    func stopTracking()
    func processFrame(_ frame: ARFrame) async // Legacy - will be deprecated
    func processFrameData(pixelBuffer: CVPixelBuffer, cameraTransform: simd_float4x4, timestamp: TimeInterval) async
}

// MARK: - Ball Tracker Service Implementation

@MainActor
final class BallTrackerService: NSObject, BallTrackerServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published var isTracking: Bool = false
    @Published var detectionConfidence: Double = 0.0
    
    // MARK: - Public Properties
    
    weak var delegate: BallTrackerDelegate?
    
    // MARK: - Private Properties
    
    private var objectDetectionModel: VNCoreMLModel?
    private var ballStrikeModel: VNCoreMLModel?
    // Serial processing queue to prevent frame accumulation
    private let processingQueue = DispatchQueue(label: "com.blu.balltracking", qos: .userInitiated)
    private var isProcessingFrame = false
    private var lastProcessTime: TimeInterval = 0
    private let processingInterval: TimeInterval = 0.033 // ~30 FPS processing (skip every other frame if needed)
    
    // Ball tracking history
    private var ballPositions: [(position: BallPosition, timestamp: Date)] = []
    private let maxTrackingHistory = 10
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        loadMLModels()
    }
    
    // MARK: - Public Methods
    
    func startTracking() async throws {
        guard objectDetectionModel != nil else {
            throw BallTrackingError.modelNotLoaded
        }
        
        isTracking = true
        ballPositions.removeAll()
        print("🎾 Ball tracking started")
    }
    
    func stopTracking() {
        isTracking = false
        ballPositions.removeAll()
        print("🎾 Ball tracking stopped")
    }
    
    func processFrame(_ frame: ARFrame) async {
        // Legacy method - extract data immediately to avoid retaining ARFrame
        await processFrameData(
            pixelBuffer: frame.capturedImage,
            cameraTransform: frame.camera.transform,
            timestamp: frame.timestamp
        )
    }
    
    func processFrameData(pixelBuffer: CVPixelBuffer, cameraTransform: simd_float4x4, timestamp: TimeInterval) async {
        guard isTracking else { return }
        
        // Skip if already processing or too soon since last process
        let currentTime = CACurrentMediaTime()
        guard !isProcessingFrame,
              currentTime - lastProcessTime > processingInterval else {
            return // Skip this frame
        }
        
        // Set processing flag immediately to prevent accumulation
        isProcessingFrame = true
        lastProcessTime = currentTime
        
        // Process frame on background queue to avoid blocking and frame retention
        Task.detached { [weak self] in
            guard let self = self else {
                // Reset flag if self is nil
                await MainActor.run {
                    // Set flag back if service was deallocated
                }
                return
            }
            
            await self.performBallDetection(
                pixelBuffer: pixelBuffer,
                cameraTransform: cameraTransform,
                timestamp: timestamp
            )
            
            // Reset processing flag after completion
            await MainActor.run {
                self.isProcessingFrame = false
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadMLModels() {
        Task {
            do {
                // Load object detection model (BLU18 equivalent)
                if let modelURL = Bundle.main.url(forResource: "BLU18", withExtension: "mlmodel") {
                    let model = try MLModel(contentsOf: modelURL)
                    objectDetectionModel = try VNCoreMLModel(for: model)
                    print("✅ Object detection model loaded")
                }
                
                // Load ball/strike classification model (BLU_ML_JULY_2024 equivalent)
                if let modelURL = Bundle.main.url(forResource: "BLU_ML_JULY_2024", withExtension: "mlmodel") {
                    let model = try MLModel(contentsOf: modelURL)
                    ballStrikeModel = try VNCoreMLModel(for: model)
                    print("✅ Ball/strike model loaded")
                }
                
            } catch {
                print("❌ Failed to load ML models: \(error)")
            }
        }
    }
    
    private func performBallDetection(
        pixelBuffer: CVPixelBuffer,
        cameraTransform: simd_float4x4,
        timestamp: TimeInterval
    ) async {
        guard let objectDetectionModel = objectDetectionModel else { return }
        
        // Get orientation from current device orientation (not from frame)
        let orientation = getImageOrientation()
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
        
        do {
            // Don't capture frame - pass only the data we need
            let request = VNCoreMLRequest(model: objectDetectionModel) { [weak self] request, error in
                Task { @MainActor in
                    await self?.handleObjectDetection(
                        request: request,
                        error: error,
                        cameraTransform: cameraTransform,
                        timestamp: timestamp
                    )
                }
            }
            
            request.imageCropAndScaleOption = .scaleFill
            try requestHandler.perform([request])
            
        } catch {
            print("❌ Ball detection error: \(error)")
        }
    }
    
    private func handleObjectDetection(
        request: VNRequest,
        error: Error?,
        cameraTransform: simd_float4x4,
        timestamp: TimeInterval
    ) async {
        if let error = error {
            print("❌ Object detection error: \(error)")
            return
        }
        
        guard let observations = request.results as? [VNRecognizedObjectObservation] else {
            return
        }
        
        // Look for baseballs with high confidence
        for observation in observations {
            guard observation.labels.first?.identifier == "baseball",
                  observation.confidence > 0.3 else {
                continue
            }
            
            // Use camera transform for world position calculation (frame not needed)
            let ballPosition = await getWorldPosition(
                from: observation,
                cameraTransform: cameraTransform
            )
            let confidence = observation.confidence
            
            if let position = ballPosition {
                let ballPos = BallPosition(
                    x: position.x,
                    y: position.y,
                    z: position.z
                )
                
                // Track ball position
                trackBallPosition(ballPos)
                
                // Calculate speed if we have enough history
                let speed = calculateSpeed()
                
                // Determine if it's a strike (simplified logic)
                let isStrike = determineStrike(ballPosition: ballPos)
                
                let result = BallDetectionResult(
                    position: ballPos,
                    confidence: Double(confidence),
                    speed: speed,
                    isStrike: isStrike
                )
                
                delegate?.didDetectBall(result)
                detectionConfidence = Double(confidence)
            }
        }
    }
    
    private func getWorldPosition(
        from observation: VNRecognizedObjectObservation,
        cameraTransform: simd_float4x4
    ) async -> (x: Double, y: Double, z: Double)? {
        // Convert Vision coordinates to world coordinates
        let visionRect = observation.boundingBox
        _ = CGPoint(x: visionRect.midX, y: visionRect.midY)
        
        // Use camera transform for world position calculation
        // This would need proper AR raycast/hit testing implementation
        // For now, return a simulated position based on camera transform
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        
        // Simulated position (would use actual raycast in production)
        return (
            x: Double(cameraPosition.x + Float.random(in: -1...1)),
            y: Double(cameraPosition.y + Float.random(in: 0...2)),
            z: Double(cameraPosition.z + Float.random(in: -1...1))
        )
    }
    
    private func trackBallPosition(_ position: BallPosition) {
        ballPositions.append((position: position, timestamp: Date()))
        
        if ballPositions.count > maxTrackingHistory {
            ballPositions.removeFirst()
        }
    }
    
    private func calculateSpeed() -> Double? {
        guard ballPositions.count >= 2 else { return nil }
        
        let latest = ballPositions.last!
        let previous = ballPositions[ballPositions.count - 2]
        
        let distance = sqrt(
            pow(latest.position.x - previous.position.x, 2) +
            pow(latest.position.y - previous.position.y, 2) +
            pow(latest.position.z - previous.position.z, 2)
        )
        
        let timeDifference = latest.timestamp.timeIntervalSince(previous.timestamp)
        guard timeDifference > 0 else { return nil }
        
        let speedMPS = distance / timeDifference
        let speedMPH = speedMPS * 2.237 // Convert m/s to mph
        
        return speedMPH > 5.0 && speedMPH < 120.0 ? speedMPH : nil
    }
    
    private func determineStrike(ballPosition: BallPosition) -> Bool {
        // Simplified strike zone logic
        // In a real implementation, this would use the field configuration
        let strikeZoneBounds = StrikeZoneBounds(
            min: BallPosition(x: -0.5, y: 0.5, z: -0.5),
            max: BallPosition(x: 0.5, y: 2.0, z: 0.5)
        )
        
        return strikeZoneBounds.contains(ballPosition)
    }
    
    private func getImageOrientation() -> CGImagePropertyOrientation {
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .portrait: return .right
        case .portraitUpsideDown: return .left
        case .landscapeLeft: return .up
        case .landscapeRight: return .down
        default: return .right
        }
    }
}

// MARK: - Ball Tracking Errors

enum BallTrackingError: LocalizedError {
    case modelNotLoaded
    case detectionFailed
    case processingError
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "ML models not loaded"
        case .detectionFailed:
            return "Ball detection failed"
        case .processingError:
            return "Frame processing error"
        }
    }
}
