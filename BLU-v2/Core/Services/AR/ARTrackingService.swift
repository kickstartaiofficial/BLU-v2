//
//  ARTrackingService.swift
//  BLU-v2
//
//  Robust AR tracking service with green pentagon placement and positioning controls
//

import Foundation
import ARKit
import SwiftUI
import Combine
import CoreLocation

// MARK: - AR Tracking Service Protocol

protocol ARTrackingServiceProtocol: ObservableObject {
    var trackingState: ARTrackingState { get }
    var fieldConfiguration: FieldConfiguration? { get }
    var ballDetectionResults: [BallDetectionResult] { get }
    var isTracking: Bool { get }
    var isHomePlatePlaced: Bool { get }
    var showPositioningControls: Bool { get }
    
    func initialize() async
    func startTracking() async throws
    func stopTracking()
    func placeHomePlate(at location: CGPoint) async
    func resetTracking()
    func displayPositioningControls()
    func hidePositioningControls()
    func adjustOrientation(_ angle: Double)
    func adjustPosition(x: Double, y: Double, z: Double)
    func confirmPositioning()
}

// MARK: - AR Tracking Service Implementation

@MainActor
final class ARTrackingService: NSObject, ARTrackingServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published var trackingState: ARTrackingState = .initializing
    @Published var fieldConfiguration: FieldConfiguration?
    @Published var ballDetectionResults: [BallDetectionResult] = []
    @Published var isTracking: Bool = false
    @Published var isHomePlatePlaced: Bool = false
    @Published var showPositioningControls: Bool = false
    
    // MARK: - Private Properties
    
    private var arSession: ARSession?
    private var ballTracker: BallTrackerService?
    private var fieldMapper: FieldMappingService?
    private var locationManager: CLLocationManager?
    private var cancellables = Set<AnyCancellable>()
    
    // AR Scene Properties
    private var sceneView: ARSCNView?
    private var homePlateNode: SCNNode?
    private var fieldAnchor: ARAnchor?
    private var geoAnchor: ARGeoAnchor?
    
    // Positioning Controls
    private var fieldOrientationAngle: Double = 0.0
    private var fieldOffsetX: Double = 0.0
    private var fieldOffsetY: Double = 0.0
    private var fieldOffsetZ: Double = 0.0
    
    // Location Properties
    private var currentLocation: CLLocation?
    private var originalCompassHeading: Double = 0.0
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupServices()
    }
    
    // MARK: - Public Methods
    
    func initialize() async {
        print("🚀 Initializing AR Tracking Service")
        
        // Set up location manager
        setupLocationManager()
        
        // Don't setup AR session here - let ARViewController handle it
        trackingState = .searchingForHomePlate
    }
    
    func startTracking() async throws {
        guard ARWorldTrackingConfiguration.isSupported else {
            throw ARTrackingError.worldTrackingNotSupported
        }
        
        trackingState = .searchingForHomePlate
        isTracking = true
        
        print("✅ AR Tracking Service ready")
    }
    
    func stopTracking() {
        // Don't pause arSession here - let ARViewController handle it
        ballTracker?.stopTracking()
        isTracking = false
        trackingState = .error
        print("⏹️ AR Tracking stopped")
    }
    
    func placeHomePlate(at location: CGPoint) async {
        guard let sceneView = sceneView,
              let arSession = arSession else {
            print("❌ Cannot place home plate - AR session not available")
            return
        }
        
        // Convert screen point to world position using modern raycast API
        let raycastQuery: ARRaycastQuery?
        if #available(iOS 14.0, *) {
            raycastQuery = sceneView.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .horizontal)
        } else {
            // Fallback for older iOS versions
            let hitTestResults = sceneView.hitTest(location, types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane])
            guard let hitResult = hitTestResults.first else {
                print("❌ No suitable plane found for home plate placement")
                return
            }
            let worldPosition = hitResult.worldTransform.columns.3
            await createHomePlateNode(at: SCNVector3(worldPosition.x, worldPosition.y, worldPosition.z))
            return
        }
        
        guard let query = raycastQuery else {
            print("❌ Could not create raycast query")
            return
        }
        
        let raycastResults = sceneView.session.raycast(query)
        
        guard let hitResult = raycastResults.first else {
            print("❌ No suitable plane found for home plate placement")
            return
        }
        
        let worldPosition = hitResult.worldTransform.columns.3
        
        // Create home plate node
        await createHomePlateNode(at: SCNVector3(worldPosition.x, worldPosition.y, worldPosition.z))
        
        // Create field anchor
        let anchor = ARAnchor(name: "homePlate", transform: hitResult.worldTransform)
        arSession.add(anchor: anchor)
        fieldAnchor = anchor
        
        // Create geo anchor if location is available
        if let location = currentLocation {
            let geoAnchor = ARGeoAnchor(coordinate: location.coordinate)
            arSession.add(anchor: geoAnchor)
            self.geoAnchor = geoAnchor
            print("🌍 Added geo anchor for persistent tracking")
        }
        
        // Update state
        isHomePlatePlaced = true
        trackingState = .fieldPlaced
        
        // Create field configuration
        let configuration = FieldConfiguration(
            homePlatePosition: BallPosition(
                x: Double(worldPosition.x),
                y: Double(worldPosition.y),
                z: Double(worldPosition.z)
            ),
            strikeZoneBounds: StrikeZoneBounds(
                min: BallPosition(x: -0.2, y: 0.3, z: -0.2),
                max: BallPosition(x: 0.2, y: 1.5, z: 0.2)
            ),
            fieldDimensions: FieldDimensions.standard
        )
        
        fieldConfiguration = configuration
        
        print("✅ Home plate placed at: \(worldPosition)")
    }
    
    func resetTracking() {
        print("🔄 Resetting AR tracking")
        
        // Clear all anchors
        if let anchor = fieldAnchor {
            arSession?.remove(anchor: anchor)
        }
        if let geoAnchor = geoAnchor {
            arSession?.remove(anchor: geoAnchor)
        }
        
        // Clear nodes
        homePlateNode?.removeFromParentNode()
        homePlateNode = nil
        
        // Reset state
        isHomePlatePlaced = false
        showPositioningControls = false
        fieldConfiguration = nil
        trackingState = .searchingForHomePlate
        
        // Reset positioning values
        fieldOrientationAngle = 0.0
        fieldOffsetX = 0.0
        fieldOffsetY = 0.0
        fieldOffsetZ = 0.0
        
        // Restart AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        configuration.isLightEstimationEnabled = true
        
        if #available(iOS 14.0, *) {
            if ARGeoTrackingConfiguration.isSupported {
                // Geo tracking configuration would be set separately
            }
        }
        
        arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        print("✅ AR tracking reset complete")
    }
    
    func displayPositioningControls() {
        self.showPositioningControls = true
        print("🎛️ Showing positioning controls")
    }
    
    func hidePositioningControls() {
        showPositioningControls = false
        print("🎛️ Hiding positioning controls")
    }
    
    func adjustOrientation(_ angle: Double) {
        fieldOrientationAngle = angle
        updateFieldPosition()
        print("🔄 Adjusted orientation to: \(angle)°")
    }
    
    func adjustPosition(x: Double, y: Double, z: Double) {
        fieldOffsetX = x
        fieldOffsetY = y
        fieldOffsetZ = z
        updateFieldPosition()
        print("📍 Adjusted position to: (\(x), \(y), \(z))")
    }
    
    func confirmPositioning() {
        hidePositioningControls()
        
        // Update field configuration with final values
        // Note: FieldConfiguration doesn't have fieldOrientation property
        // This would be handled by the positioning system separately
        
        print("✅ Positioning confirmed")
    }
    
    // MARK: - Field Lines and Ball Tracking
    
    private func createFieldLines(at homePlatePosition: SCNVector3) async {
        guard let sceneView = sceneView else { return }
        
        // Create infield diamond lines
        let diamondLines = createInfieldDiamond(at: homePlatePosition)
        sceneView.scene.rootNode.addChildNode(diamondLines)
        
        // Create strike zone
        let strikeZone = createStrikeZone(at: homePlatePosition)
        sceneView.scene.rootNode.addChildNode(strikeZone)
        
        print("✅ Field lines created")
    }
    
    private func createInfieldDiamond(at position: SCNVector3) -> SCNNode {
        let diamondNode = SCNNode()
        
        // Diamond dimensions (in meters)
        let baseDistance: Float = 27.43 // 90 feet
        
        // Create lines for the diamond
        let points = [
            position, // Home plate
            SCNVector3(position.x + baseDistance, position.y, position.z), // First base
            SCNVector3(position.x + baseDistance, position.y, position.z + baseDistance), // Second base
            SCNVector3(position.x, position.y, position.z + baseDistance), // Third base
            position // Back to home plate
        ]
        
        for i in 0..<points.count - 1 {
            let line = createLine(from: points[i], to: points[i + 1])
            diamondNode.addChildNode(line)
        }
        
        return diamondNode
    }
    
    private func createStrikeZone(at position: SCNVector3) -> SCNNode {
        let strikeZoneNode = SCNNode()
        
        // Strike zone dimensions (in meters)
        let width: Float = 0.43 // 17 inches
        let height: Float = 1.2 // 4 feet
        
        // Create strike zone box
        let boxGeometry = SCNBox(width: CGFloat(width), height: CGFloat(height), length: 0.01, chamferRadius: 0)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.green.withAlphaComponent(0.3)
        boxGeometry.materials = [material]
        
        let boxNode = SCNNode(geometry: boxGeometry)
        boxNode.position = SCNVector3(position.x, position.y + height/2, position.z)
        strikeZoneNode.addChildNode(boxNode)
        
        return strikeZoneNode
    }
    
    private func createLine(from start: SCNVector3, to end: SCNVector3) -> SCNNode {
        let lineNode = SCNNode()
        
        let distance = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2) + pow(end.z - start.z, 2))
        
        let cylinder = SCNCylinder(radius: 0.01, height: CGFloat(distance))
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white
        cylinder.materials = [material]
        
        let cylinderNode = SCNNode(geometry: cylinder)
        cylinderNode.position = SCNVector3(
            (start.x + end.x) / 2,
            (start.y + end.y) / 2,
            (start.z + end.z) / 2
        )
        
        // Rotate cylinder to align with line direction
        let direction = SCNVector3(end.x - start.x, end.y - start.y, end.z - start.z)
        let angle = atan2(direction.x, direction.z)
        cylinderNode.eulerAngles = SCNVector3(0, angle, 0)
        
        lineNode.addChildNode(cylinderNode)
        return lineNode
    }
    
    // MARK: - Ball Tracking
    
    func startBallTracking() async {
        // Start ball detection and tracking
        do {
            try await ballTracker?.startTracking()
            trackingState = .trackingSpeed
            print("🎯 Ball tracking started")
        } catch {
            print("❌ Failed to start ball tracking: \(error)")
            trackingState = .error
        }
    }
    
    func stopBallTracking() {
        ballTracker?.stopTracking()
        trackingState = .fieldPlaced
        print("⏹️ Ball tracking stopped")
    }
    
    // MARK: - Private Methods
    
    private func setupServices() {
        // Initialize services
        ballTracker = BallTrackerService()
        fieldMapper = FieldMappingService()
        
        // Set up delegates
        ballTracker?.delegate = self
        fieldMapper?.delegate = self
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.startUpdatingLocation()
        locationManager?.startUpdatingHeading()
    }
    
    private func setupARSession() async {
        // Create ARSCNView for SceneKit integration
        let sceneView = ARSCNView()
        self.sceneView = sceneView
        
        // Set up AR session
        let session = ARSession()
        sceneView.session = session
        session.delegate = self
        self.arSession = session
        
        // Configure scene
        sceneView.scene = SCNScene()
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
        
        print("✅ AR Session setup complete")
    }
    
    private func createHomePlateNode(at position: SCNVector3) async {
        // Create home plate geometry
        let homePlateGeometry = createHomePlateGeometry()
        
        // Create node
        let node = SCNNode(geometry: homePlateGeometry)
        node.position = position
        node.name = "homePlate"
        
        // Add to scene
        sceneView?.scene.rootNode.addChildNode(node)
        homePlateNode = node
        
        // Create field lines after home plate is placed
        await createFieldLines(at: position)
        
        print("✅ Home plate node created at: \(position)")
    }
    
    private func createHomePlateGeometry() -> SCNGeometry {
        // Create pentagon shape for home plate
        let path = UIBezierPath()
        
        // Home plate dimensions (in meters)
        let width: Float = 0.43 // 17 inches
        let height: Float = 0.22 // 8.5 inches
        
        // Pentagon points
        let points = [
            CGPoint(x: 0, y: Int(height/2)),           // Top
            CGPoint(x: Int(width/2), y: Int(height/4)),    // Top right
            CGPoint(x: Int(width/2), y: Int(-height/4)),   // Bottom right
            CGPoint(x: 0, y: Int(-height/2)),         // Bottom point
            CGPoint(x: Int(-width/2), y: Int(-height/4)),  // Bottom left
            CGPoint(x: Int(-width/2), y: Int(height/4))     // Top left
        ]
        
        path.move(to: points[0])
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        path.close()
        
        // Create geometry
        let geometry = SCNShape(path: path, extrusionDepth: 0.02)
        
        // Create material
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white
        material.specular.contents = UIColor.white
        material.shininess = 0.8
        geometry.materials = [material]
        
        return geometry
    }
    
    private func updateFieldPosition() {
        guard let homePlateNode = homePlateNode else { return }
        
        // Apply orientation
        homePlateNode.eulerAngles.y = Float(fieldOrientationAngle * .pi / 180)
        
        // Apply position offsets
        homePlateNode.position.x += Float(fieldOffsetX)
        homePlateNode.position.y += Float(fieldOffsetY)
        homePlateNode.position.z += Float(fieldOffsetZ)
    }
    
    // MARK: - Public Interface for SwiftUI
    
    func setSceneView(_ sceneView: ARSCNView) {
        self.sceneView = sceneView
        self.arSession = sceneView.session
        sceneView.session.delegate = self
    }
}

// MARK: - ARSessionDelegate

extension ARTrackingService: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Process frame for ball detection
        Task {
            await ballTracker?.processFrame(frame)
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("❌ AR Session failed: \(error)")
        trackingState = .error
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("⚠️ AR Session interrupted")
        trackingState = .error
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("✅ AR Session interruption ended")
        // Restart tracking
        Task {
            try? await startTracking()
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let geoAnchor = anchor as? ARGeoAnchor {
                print("🌍 Geo anchor added: \(geoAnchor.coordinate)")
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension ARTrackingService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        print("📍 Location updated: \(location.coordinate)")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if originalCompassHeading == 0 {
            originalCompassHeading = newHeading.trueHeading
        }
        print("🧭 Heading updated: \(newHeading.trueHeading)°")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error)")
    }
}

// MARK: - Ball Tracker Delegate

extension ARTrackingService: BallTrackerDelegate {
    func didDetectBall(_ result: BallDetectionResult) {
        ballDetectionResults.append(result)
        
        // Keep only recent detections
        if ballDetectionResults.count > 50 {
            ballDetectionResults.removeFirst()
        }
        
        // Update tracking state if we're actively tracking
        if trackingState == .fieldPlaced {
            trackingState = .trackingSpeed
        }
    }
}

// MARK: - Field Mapper Delegate

extension ARTrackingService: FieldMappingDelegate {
    func didCompleteFieldMapping(_ configuration: FieldConfiguration) {
        self.fieldConfiguration = configuration
        trackingState = .fieldPlaced
    }
    
    func didFailFieldMapping(_ error: Error) {
        print("❌ Field mapping failed: \(error)")
        trackingState = .error
    }
}

// MARK: - AR Tracking Errors

enum ARTrackingError: LocalizedError {
    case worldTrackingNotSupported
    case sessionNotAvailable
    case fieldCalibrationFailed
    case ballDetectionFailed
    case locationNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .worldTrackingNotSupported:
            return "AR World Tracking is not supported on this device"
        case .sessionNotAvailable:
            return "AR Session is not available"
        case .fieldCalibrationFailed:
            return "Failed to calibrate baseball field"
        case .ballDetectionFailed:
            return "Failed to detect baseball"
        case .locationNotAvailable:
            return "Location services not available"
        }
    }
}
