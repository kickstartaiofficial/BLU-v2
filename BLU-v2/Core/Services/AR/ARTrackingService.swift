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
    func setFieldLinesVisibility(_ visible: Bool)
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
    private var fieldContainerNode: SCNNode? // Parent node to hold everything
    private var homePlateNode: SCNNode?
    private var fieldNode: SCNNode?
    private var strikeZoneNode: SCNNode? // Separate node for strike zone (always visible)
    private var fieldAnchor: ARAnchor?
    private var geoAnchor: ARGeoAnchor?
    
    // Positioning Controls
    private var fieldOrientationAngle: Double = 0.0
    private var fieldOffsetX: Double = 0.0
    private var fieldOffsetY: Double = 0.0
    private var fieldOffsetZ: Double = 0.0
    
    // Location Properties
    public var currentLocation: CLLocation?
    private var originalCompassHeading: Double = 0.0
    private var lastLocationUpdate: Date = Date()
    private var lastHeadingUpdate: Date = Date()
    private let locationUpdateInterval: TimeInterval = 2.0 // Update every 2 seconds max
    private let headingUpdateInterval: TimeInterval = 1.0 // Update every 1 second max
    
    // Debug Properties
    private var debugFieldLinesEnabled: Bool = true
    
    // Field Lines Visibility State
    private var fieldLinesVisible: Bool = true // Default to visible
    
    // Performance optimization - use DispatchWorkItem for better coalescing
    private var orientationUpdateWorkItem: DispatchWorkItem?
    private var positionUpdateWorkItem: DispatchWorkItem?
    private let updateQueue = DispatchQueue(label: "com.blu.ar.updates", qos: .userInteractive)
    private var originalHomePlatePosition: SCNVector3?
    private var updateDebounceDelay: TimeInterval = 0.15 // Increased for smoother performance
    
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
        
        // Stop location updates to reduce memory usage
        locationManager?.stopUpdatingLocation()
        locationManager?.stopUpdatingHeading()
        
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
        
        // Clear container node (removes all children)
        fieldContainerNode?.removeFromParentNode()
        fieldContainerNode = nil
        
        homePlateNode = nil
        fieldNode = nil
        strikeZoneNode = nil
        
        // Reset state
        isHomePlatePlaced = false
        showPositioningControls = false
        fieldConfiguration = nil
        trackingState = .searchingForHomePlate
        
        // Clear timers to prevent memory leaks
        orientationUpdateWorkItem?.cancel()
        orientationUpdateWorkItem = nil
        positionUpdateWorkItem?.cancel()
        positionUpdateWorkItem = nil
        
        // Reset positioning values
        fieldOrientationAngle = 0.0
        fieldOffsetX = 0.0
        fieldOffsetY = 0.0
        fieldOffsetZ = 0.0
        originalHomePlatePosition = nil
        
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
        
        // Cancel previous work item to prevent accumulation
        orientationUpdateWorkItem?.cancel()
        
        // Create new work item with debounce delay
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateFieldPosition()
            }
        }
        
        orientationUpdateWorkItem = workItem
        
        // Schedule on main queue after debounce delay - use asyncAfter for better coalescing
        DispatchQueue.main.asyncAfter(deadline: .now() + updateDebounceDelay, execute: workItem)
    }
    
    func adjustPosition(x: Double, y: Double, z: Double) {
        // Ensure Y is always 0 (no vertical movement on ground plane)
        fieldOffsetX = x
        fieldOffsetY = 0.0  // Always 0 - only move on ground plane (X and Z)
        fieldOffsetZ = z
        
        // Cancel previous work item to prevent accumulation
        positionUpdateWorkItem?.cancel()
        
        // Create new work item with debounce delay
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateFieldPosition()
            }
        }
        
        positionUpdateWorkItem = workItem
        
        // Schedule on main queue after debounce delay - use asyncAfter for better coalescing
        DispatchQueue.main.asyncAfter(deadline: .now() + updateDebounceDelay, execute: workItem)
    }
    
    func confirmPositioning() {
        hidePositioningControls()
        
        // CRITICAL: Cancel any pending debounced updates to prevent race conditions
        orientationUpdateWorkItem?.cancel()
        positionUpdateWorkItem?.cancel()
        
        // Calculate final position DIRECTLY from current slider values
        // This ensures anchor matches exactly what user sees, not a potentially stale container position
        guard let container = fieldContainerNode,
              let originalPosition = originalHomePlatePosition else {
            print("⚠️ Cannot confirm positioning - container or original position missing")
            return
        }
        
        // Use exact slider values (not container position which might be outdated due to debouncing)
        let localOffset = simd_float3(
            Float(fieldOffsetX),  // Current slider X value
            0.0,                  // Always 0 (no vertical movement)
            Float(fieldOffsetZ)   // Current slider Z value
        )
        
        let rotationAngle = Float(-fieldOrientationAngle * .pi / 180.0)
        let rotationQuaternion = simd_quatf(angle: rotationAngle, axis: simd_float3(0, 1, 0))
        
        // Transform local offset to world space
        let worldOffset = simd_act(rotationQuaternion, localOffset)
        
        // Calculate final world position
        let finalPosition = SCNVector3(
            originalPosition.x + worldOffset.x,
            originalPosition.y + worldOffset.y,  // Should be same as originalPosition.y
            originalPosition.z + worldOffset.z
        )
        
        // Apply to container IMMEDIATELY to ensure visual consistency (no jump)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        container.eulerAngles = SCNVector3(0, rotationAngle, 0)
        container.position = finalPosition
        CATransaction.commit()
        
        // Update AR anchor with calculated position (this locks it in AR space)
        updateARAnchor(position: finalPosition, rotationAngle: rotationAngle)
        
        // Update original position for future adjustments
        originalHomePlatePosition = finalPosition
        
        // Update GPS coordinates and store with session
        updateSessionLocation()
        
        print("✅ Positioning confirmed - anchor updated from slider values: X=\(fieldOffsetX), Z=\(fieldOffsetZ), Rot=\(fieldOrientationAngle)°")
    }
    
    // MARK: - GPS Coordinates
    
    func getCurrentGPSCoordinates() -> (latitude: Double, longitude: Double)? {
        guard let location = currentLocation else { return nil }
        return (location.coordinate.latitude, location.coordinate.longitude)
    }
    
    /// Update session location with current GPS coordinates
    /// Called when user confirms positioning with sliders
    /// Posts notification for SessionManager to handle
    private func updateSessionLocation() {
        guard let location = currentLocation else {
            print("⚠️ Cannot update session location: GPS unavailable")
            return
        }
        
        // Create FieldLocation from current GPS coordinates
        let fieldLocation = FieldLocation(location: location)
        
        // Post notification to update session location
        // This avoids tight coupling between ARTrackingService and SessionManager
        NotificationCenter.default.post(
            name: NSNotification.Name("UpdateSessionLocation"),
            object: nil,
            userInfo: ["fieldLocation": fieldLocation]
        )
        
        print("📍 GPS coordinates ready for session update: \(fieldLocation.latitude), \(fieldLocation.longitude)")
    }
    
    // MARK: - Field Lines and Ball Tracking
    
    private func createFieldLines(at homePlatePosition: SCNVector3) async {
        guard let container = fieldContainerNode else { return }
        
        // Create field node to group all field elements (relative to container)
        let fieldNode = SCNNode()
        fieldNode.name = "fieldLines"
        fieldNode.position = SCNVector3(0, 0, 0) // Relative to container
        container.addChildNode(fieldNode)
        
        // Store field node reference
        self.fieldNode = fieldNode
        
        // Create axis locator at anchor position (origin)
        let axisLocator = createAxisLocator()
        fieldNode.addChildNode(axisLocator)
        
        // Create infield diamond lines (relative to container)
        let diamondLines = createInfieldDiamond(at: homePlatePosition)
        fieldNode.addChildNode(diamondLines)
        
        // Note: Strike zone is now created separately and always visible
        // (moved to createHomePlateNode to be separate from fieldNode)
        
        // Create batter's box lines (relative to container)
        createBasePlateLines(for: fieldNode, homePlatePosition: homePlatePosition)
        
        // Apply the stored visibility state
        fieldNode.isHidden = !fieldLinesVisible
        fieldNode.childNodes.forEach { $0.isHidden = !fieldLinesVisible }
        
        print("✅ Field lines created (visible: \(fieldLinesVisible))")
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
        strikeZoneNode.name = "strikeZone"
        
        // Strike zone dimensions (in meters)
        // Width: 17 inches (0.4318m) - matches home plate width
        let width: Float = 17 * 0.0254 // 0.4318 meters
        // Height: Typical strike zone from knee hollow to shoulder (1.5-2 feet)
        // Using 1.8 feet (0.54864m) for average adult
        let height: Float = 1.8 * 0.3048 // 0.54864 meters
        // Depth: Extends over the length of home plate (about 17 inches front to back)
        let depth: Float = 17 * 0.005
        
        let kneeHeight: Float = 18 * 0.0254
        
        // Create strike zone box - purple and semi-transparent
        let boxGeometry = SCNBox(
            width: CGFloat(width),
            height: CGFloat(height),
            length: CGFloat(depth),
            chamferRadius: 0
        )
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.purple.withAlphaComponent(0.7)
        material.isDoubleSided = true
        boxGeometry.materials = [material]
        
        let boxNode = SCNNode(geometry: boxGeometry)
        // Position box right above home plate (centered vertically)
        // Home plate is at y=0, so strike zone starts slightly above it
        boxNode.position = SCNVector3(
            position.x,
            position.y + kneeHeight, // 1cm above plate + half height
            position.z
        )
        strikeZoneNode.addChildNode(boxNode)
        
        // Strike zone is always visible (not part of fieldNode toggle)
        strikeZoneNode.isHidden = false
        
        print("✅ Strike zone created: \(width)m x \(height)m x \(depth)m (purple)")
        
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
    
    private func createBasePlateLines(for fieldNode: SCNNode, homePlatePosition: SCNVector3) {
        guard debugFieldLinesEnabled else { return }
        // Dimensions in meters
        let ft: Float = 0.3048
        let inch: Float = 0.0254
        let plateWidth: Float = 17 * inch // 0.4318 m
        let plateFront: Float = 6 * inch // From center to front of plate
        let boxWidth: Float = 4 * ft // 4 ft
        let boxDepth: Float = 6 * ft // 6 ft
        let boxY: Float = homePlatePosition.y + 0.005 // Slightly above home plate
        let lineThickness: Float = 0.03 // 3 cm wide lines
        
        // Rectangular batter's box left
        let leftBoxRight = SCNBox(width: CGFloat(lineThickness), height: 0.01, length: CGFloat(boxDepth), chamferRadius: 0)
        leftBoxRight.firstMaterial?.diffuse.contents = UIColor.white
        let leftBoxRightNode = SCNNode(geometry: leftBoxRight)
        leftBoxRightNode.position = SCNVector3(homePlatePosition.x - ((plateWidth/2) + plateFront + (lineThickness/2)), boxY, homePlatePosition.z)
        leftBoxRightNode.name = "DebugBasePlateLine"
        fieldNode.addChildNode(leftBoxRightNode)
        
        let leftBoxLeft = SCNBox(width: CGFloat(lineThickness), height: 0.01, length: CGFloat(boxDepth), chamferRadius: 0)
        leftBoxLeft.firstMaterial?.diffuse.contents = UIColor.white
        let leftBoxLeftNode = SCNNode(geometry: leftBoxLeft)
        leftBoxLeftNode.position = SCNVector3(homePlatePosition.x - ((plateWidth/2) + plateFront + (lineThickness/2) + boxWidth), boxY, homePlatePosition.z)
        leftBoxLeftNode.name = "DebugBasePlateLine"
        fieldNode.addChildNode(leftBoxLeftNode)
        
        let leftBoxTop = SCNBox(width: CGFloat(boxWidth), height: 0.01, length: CGFloat(lineThickness), chamferRadius: 0)
        leftBoxTop.firstMaterial?.diffuse.contents = UIColor.white
        let leftBoxTopNode = SCNNode(geometry: leftBoxTop)
        leftBoxTopNode.position = SCNVector3(homePlatePosition.x - ((plateWidth/2) + plateFront + boxWidth/2), boxY, homePlatePosition.z + boxDepth/2)
        leftBoxTopNode.name = "DebugBasePlateLine"
        fieldNode.addChildNode(leftBoxTopNode)
        
        let leftBoxBottom = SCNBox(width: CGFloat(boxWidth), height: 0.01, length: CGFloat(lineThickness), chamferRadius: 0)
        leftBoxBottom.firstMaterial?.diffuse.contents = UIColor.white
        let leftBoxBottomNode = SCNNode(geometry: leftBoxBottom)
        leftBoxBottomNode.position = SCNVector3(homePlatePosition.x - ((plateWidth/2) + plateFront + boxWidth/2), boxY, homePlatePosition.z - boxDepth/2)
        leftBoxBottomNode.name = "DebugBasePlateLine"
        fieldNode.addChildNode(leftBoxBottomNode)
        
        // Rectangular batter's box right
        let rightBoxRight = SCNBox(width: CGFloat(lineThickness), height: 0.01, length: CGFloat(boxDepth), chamferRadius: 0)
        rightBoxRight.firstMaterial?.diffuse.contents = UIColor.white
        let rightBoxRightNode = SCNNode(geometry: rightBoxRight)
        rightBoxRightNode.position = SCNVector3(homePlatePosition.x + (plateWidth/2) + plateFront + (lineThickness/2), boxY, homePlatePosition.z)
        rightBoxRightNode.name = "DebugBasePlateLine"
        fieldNode.addChildNode(rightBoxRightNode)
        
        let rightBoxLeft = SCNBox(width: CGFloat(lineThickness), height: 0.01, length: CGFloat(boxDepth), chamferRadius: 0)
        rightBoxLeft.firstMaterial?.diffuse.contents = UIColor.white
        let rightBoxLeftNode = SCNNode(geometry: rightBoxLeft)
        rightBoxLeftNode.position = SCNVector3(homePlatePosition.x + (plateWidth/2) + plateFront + (lineThickness/2) + boxWidth, boxY, homePlatePosition.z)
        rightBoxLeftNode.name = "DebugBasePlateLine"
        fieldNode.addChildNode(rightBoxLeftNode)
        
        let rightBoxTop = SCNBox(width: CGFloat(boxWidth), height: 0.01, length: CGFloat(lineThickness), chamferRadius: 0)
        rightBoxTop.firstMaterial?.diffuse.contents = UIColor.white
        let rightBoxTopNode = SCNNode(geometry: rightBoxTop)
        rightBoxTopNode.position = SCNVector3(homePlatePosition.x + (plateWidth/2) + plateFront + boxWidth/2, boxY, homePlatePosition.z + boxDepth/2)
        rightBoxTopNode.name = "DebugBasePlateLine"
        fieldNode.addChildNode(rightBoxTopNode)
        
        let rightBoxBottom = SCNBox(width: CGFloat(boxWidth), height: 0.01, length: CGFloat(lineThickness), chamferRadius: 0)
        rightBoxBottom.firstMaterial?.diffuse.contents = UIColor.white
        let rightBoxBottomNode = SCNNode(geometry: rightBoxBottom)
        rightBoxBottomNode.position = SCNVector3(homePlatePosition.x + (plateWidth/2) + plateFront + boxWidth/2, boxY, homePlatePosition.z - boxDepth/2)
        rightBoxBottomNode.name = "DebugBasePlateLine"
        fieldNode.addChildNode(rightBoxBottomNode)
        
        //Bottom Box
        
        let boxBottomLeft = SCNBox(width: CGFloat(lineThickness), height: 0.01, length: CGFloat(boxDepth), chamferRadius: 0)
        boxBottomLeft.firstMaterial?.diffuse.contents = UIColor.white
        let boxBottomLeftNode = SCNNode(geometry: boxBottomLeft)
        boxBottomLeftNode.position = SCNVector3(homePlatePosition.x - boxWidth/2, boxY, homePlatePosition.z + boxDepth)
        boxBottomLeftNode.name = "DebugBasePlateLine"
        fieldNode.addChildNode(boxBottomLeftNode)
        
        let boxBottomRight = SCNBox(width: CGFloat(lineThickness), height: 0.01, length: CGFloat(boxDepth), chamferRadius: 0)
        boxBottomRight.firstMaterial?.diffuse.contents = UIColor.white
        let boxBottomRightNode = SCNNode(geometry: boxBottomRight)
        boxBottomRightNode.position = SCNVector3(homePlatePosition.x + boxWidth/2, boxY, homePlatePosition.z + boxDepth)
        boxBottomRightNode.name = "DebugBasePlateLine"
        fieldNode.addChildNode(boxBottomRightNode)
        
        let boxBottom = SCNBox(width: CGFloat(boxWidth), height: 0.01, length: CGFloat(lineThickness), chamferRadius: 0)
        boxBottom.firstMaterial?.diffuse.contents = UIColor.white
        let boxBottomNode = SCNNode(geometry: boxBottom)
        boxBottomNode.position = SCNVector3(homePlatePosition.x, boxY, homePlatePosition.z + (boxDepth/2) + boxDepth)
        boxBottomNode.name = "DebugBasePlateLine"
        fieldNode.addChildNode(boxBottomNode)
        
    }
    
    // MARK: - Axis Locator
    
    private func createAxisLocator() -> SCNNode {
        let axisNode = SCNNode()
        axisNode.name = "axisLocator"
        
        // Axis length (in meters) - visible but not too long
        let axisLength: Float = 0.15 // 15cm
        let axisThickness: Float = 0.005 // 5mm
        
        // X-Axis (Red) - pointing right
        let xAxis = SCNCylinder(radius: CGFloat(axisThickness), height: CGFloat(axisLength))
        let xMaterial = SCNMaterial()
        xMaterial.diffuse.contents = UIColor.red
        xMaterial.emission.contents = UIColor.red.withAlphaComponent(0.5)
        xAxis.materials = [xMaterial]
        
        let xAxisNode = SCNNode(geometry: xAxis)
        xAxisNode.position = SCNVector3(axisLength / 2, 0, 0)
        xAxisNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2) // Rotate to horizontal
        xAxisNode.name = "xAxis"
        axisNode.addChildNode(xAxisNode)
        
        // Arrow head for X-axis
        let xArrow = SCNCone(topRadius: 0, bottomRadius: CGFloat(axisThickness * 3), height: CGFloat(axisThickness * 6))
        let xArrowMaterial = SCNMaterial()
        xArrowMaterial.diffuse.contents = UIColor.red
        xArrow.materials = [xArrowMaterial]
        
        let xArrowNode = SCNNode(geometry: xArrow)
        xArrowNode.position = SCNVector3(axisLength, 0, 0)
        xArrowNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        xArrowNode.name = "xArrow"
        axisNode.addChildNode(xArrowNode)
        
        // Y-Axis (Green) - pointing up
        let yAxis = SCNCylinder(radius: CGFloat(axisThickness), height: CGFloat(axisLength))
        let yMaterial = SCNMaterial()
        yMaterial.diffuse.contents = UIColor.green
        yMaterial.emission.contents = UIColor.green.withAlphaComponent(0.5)
        yAxis.materials = [yMaterial]
        
        let yAxisNode = SCNNode(geometry: yAxis)
        yAxisNode.position = SCNVector3(0, axisLength / 2, 0)
        yAxisNode.name = "yAxis"
        axisNode.addChildNode(yAxisNode)
        
        // Arrow head for Y-axis
        let yArrow = SCNCone(topRadius: 0, bottomRadius: CGFloat(axisThickness * 3), height: CGFloat(axisThickness * 6))
        let yArrowMaterial = SCNMaterial()
        yArrowMaterial.diffuse.contents = UIColor.green
        yArrow.materials = [yArrowMaterial]
        
        let yArrowNode = SCNNode(geometry: yArrow)
        yArrowNode.position = SCNVector3(0, axisLength, 0)
        yArrowNode.name = "yArrow"
        axisNode.addChildNode(yArrowNode)
        
        // Z-Axis (Blue) - pointing forward (toward pitcher)
        let zAxis = SCNCylinder(radius: CGFloat(axisThickness), height: CGFloat(axisLength))
        let zMaterial = SCNMaterial()
        zMaterial.diffuse.contents = UIColor.blue
        zMaterial.emission.contents = UIColor.blue.withAlphaComponent(0.5)
        zAxis.materials = [zMaterial]
        
        let zAxisNode = SCNNode(geometry: zAxis)
        zAxisNode.position = SCNVector3(0, 0, axisLength / 2)
        zAxisNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0) // Rotate to forward
        zAxisNode.name = "zAxis"
        axisNode.addChildNode(zAxisNode)
        
        // Arrow head for Z-axis
        let zArrow = SCNCone(topRadius: 0, bottomRadius: CGFloat(axisThickness * 3), height: CGFloat(axisThickness * 6))
        let zArrowMaterial = SCNMaterial()
        zArrowMaterial.diffuse.contents = UIColor.blue
        zArrow.materials = [zArrowMaterial]
        
        let zArrowNode = SCNNode(geometry: zArrow)
        zArrowNode.position = SCNVector3(0, 0, axisLength)
        zArrowNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        zArrowNode.name = "zArrow"
        axisNode.addChildNode(zArrowNode)
        
        // Center sphere at origin to mark the anchor point
        let centerSphere = SCNSphere(radius: CGFloat(axisThickness * 2))
        let centerMaterial = SCNMaterial()
        centerMaterial.diffuse.contents = UIColor.white
        centerMaterial.emission.contents = UIColor.white.withAlphaComponent(0.3)
        centerSphere.materials = [centerMaterial]
        
        let centerNode = SCNNode(geometry: centerSphere)
        centerNode.position = SCNVector3(0, 0, 0)
        centerNode.name = "center"
        axisNode.addChildNode(centerNode)
        
        print("✅ Axis locator created")
        
        return axisNode
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
    
    // MARK: - Field Lines Visibility
    
    func setFieldLinesVisibility(_ visible: Bool) {
        // Store the visibility preference
        fieldLinesVisible = visible
        
        guard let fieldNode = fieldNode else {
            // Field lines haven't been created yet, but we've stored the preference
            // It will be applied when field lines are created
            return
        }
        
        // Toggle visibility of field lines (not the home plate)
        fieldNode.isHidden = !visible
        
        // Also hide/show all child nodes of fieldNode (base plate lines, diamond, strike zone)
        fieldNode.childNodes.forEach { $0.isHidden = !visible }
        
        print(visible ? "✅ Field lines shown" : "⏸️ Field lines hidden")
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
        
        // Throttle updates to reduce memory pressure
        locationManager?.distanceFilter = 5.0 // Only update when moved 5 meters
        locationManager?.headingFilter = 5.0 // Only update when heading changed 5 degrees
        
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
        guard let sceneView = sceneView else { return }
        
        // Create container node to hold home plate and field lines together
        let container = SCNNode()
        container.position = position
        container.name = "fieldContainer"
        sceneView.scene.rootNode.addChildNode(container)
        self.fieldContainerNode = container
        
        // Create home plate geometry
        let homePlateGeometry = createHomePlateGeometry()
        
        // Create home plate node (relative to container, at origin)
        let node = SCNNode(geometry: homePlateGeometry)
        node.position = SCNVector3(0, 0, 0) // Relative to container
        node.name = "homePlate"
        
        // Add home plate to container
        container.addChildNode(node)
        homePlateNode = node
        
        // Store original position for positioning controls
        originalHomePlatePosition = position
        
        // Reset positioning offsets
        fieldOrientationAngle = 0.0
        fieldOffsetX = 0.0
        fieldOffsetY = 0.0
        fieldOffsetZ = 0.0
        
        // Create strike zone (always visible, separate from field lines)
        let strikeZone = createStrikeZone(at: SCNVector3(0, 0, 0)) // Relative to container
        container.addChildNode(strikeZone)
        self.strikeZoneNode = strikeZone
        
        // Create field lines after home plate is placed
        await createFieldLines(at: SCNVector3(0, 0, 0)) // Relative to container
        
        print("✅ Home plate node created at: \(position)")
    }
    
    private func createHomePlateGeometry() -> SCNGeometry {
        // Home plate dimensions (adjusted to match visual reticle - less pointed)
        // Scale to meters: 1 inch = 0.0254 meters
        let width: Float = 17 * 0.0254  // 0.4318 meters (17 inches wide)
        let sideHeight: Float = 8.5 * 0.0254  // 0.2159 meters (8.5 inches)
        let bottomPoint: Float = 8.5 * 0.0254  // 0.2159 meters (reduced from 12" to match reticle proportions)
        
        // Create home plate with correct orientation - point should face toward pitcher
        let vertices: [SCNVector3] = [
            SCNVector3(-width/2, 0, -sideHeight),     // Top left (back toward catcher)
            SCNVector3(width/2, 0, -sideHeight),      // Top right (back toward catcher)
            SCNVector3(width/2, 0, 0),                // Middle right
            SCNVector3(0, 0, bottomPoint),            // Bottom point (toward pitcher)
            SCNVector3(-width/2, 0, 0),               // Middle left
        ]
        
        let indices: [Int32] = [
            0, 1, 2,  // Top triangle
            0, 2, 4,  // Left triangle
            2, 3, 4   // Bottom triangle
        ]
        
        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        
        let geometry = SCNGeometry(sources: [source], elements: [element])
        geometry.firstMaterial?.diffuse.contents = UIColor.white
        geometry.firstMaterial?.isDoubleSided = true
        
        return geometry
    }
    
    @MainActor
    private func updateFieldPosition() {
        guard let container = fieldContainerNode,
              let originalPosition = originalHomePlatePosition else { return }
        
        // Ensure we're on the main thread for SceneKit updates
        assert(Thread.isMainThread, "updateFieldPosition must be called on main thread")
        
        // Use CATransaction to batch SceneKit updates and prevent blocking AR
        CATransaction.begin()
        CATransaction.setDisableActions(true) // Disable animations for instant updates
        
        // Local space offsets (along container's X and Z axes, which rotate with the container)
        // X = Red axis (left/right relative to container's local orientation)
        // Z = Blue axis (forward/backward relative to container's local orientation)
        // Y = Green axis (up/down, always 0 - no vertical movement)
        let localOffset = simd_float3(
            Float(fieldOffsetX),  // Red axis (X) - moves left/right along container's local X
            0.0,                   // Green axis (Y) - always 0, no vertical movement
            Float(fieldOffsetZ)   // Blue axis (Z) - moves forward/backward along container's local Z
        )
        
        // Create rotation transform around Y axis (green axis) to match container's orientation
        let rotationAngle = Float(-fieldOrientationAngle * .pi / 180.0)
        let rotationQuaternion = simd_quatf(angle: rotationAngle, axis: simd_float3(0, 1, 0))
        
        // Transform local offset to world space by rotating it
        // This ensures offsets move along the container's rotated axes (red and blue)
        let worldOffset = simd_act(rotationQuaternion, localOffset)
        
        // Calculate new world position
        let newPosition = SCNVector3(
            originalPosition.x + worldOffset.x,
            originalPosition.y + worldOffset.y,  // Should stay at originalPosition.y since localOffset.y = 0
            originalPosition.z + worldOffset.z
        )
        
        // Apply rotation and position to container atomically
        container.eulerAngles = SCNVector3(0, rotationAngle, 0)
        container.position = newPosition
        
        CATransaction.commit()
        
        // Note: We do NOT update AR anchor on every slider change to prevent tracking drift
        // Anchor updates happen only when user confirms position (in confirmPositioning)
        // This keeps AR tracking stable while allowing smooth live preview
        
        // Reduced logging to prevent spam
        // print("🔄 Field position updated: orientation=\(fieldOrientationAngle)°, local offset=(\(fieldOffsetX), 0.0, \(fieldOffsetZ)), world offset=(\(worldOffset.x), \(worldOffset.y), \(worldOffset.z))")
    }
    
    /// Update AR anchor to match SceneKit node position - called only on confirmation to prevent drift
    @MainActor
    private func updateARAnchor(position: SCNVector3, rotationAngle: Float) {
        guard let arSession = arSession else { return }
        
        // Remove old anchor if it exists
        if let fieldAnchor = fieldAnchor {
            arSession.remove(anchor: fieldAnchor)
        }
        
        // Create new transform matrix with updated position and rotation
        var transform = matrix_identity_float4x4
        
        // Set translation
        transform.columns.3 = simd_float4(position.x, position.y, position.z, 1.0)
        
        // Set rotation around Y axis (green axis)
        let cosAngle = cos(rotationAngle)
        let sinAngle = sin(rotationAngle)
        transform.columns.0 = simd_float4(cosAngle, 0, -sinAngle, 0)  // X axis (red)
        transform.columns.1 = simd_float4(0, 1, 0, 0)                  // Y axis (green/up)
        transform.columns.2 = simd_float4(sinAngle, 0, cosAngle, 0)   // Z axis (blue)
        
        // Create new anchor with updated transform - this locks in the position
        let newAnchor = ARAnchor(name: "homePlate", transform: transform)
        arSession.add(anchor: newAnchor)
        self.fieldAnchor = newAnchor
        
        // Update geo anchor if location is available
        // This helps with persistent tracking across AR session interruptions
        if let location = currentLocation {
            // Remove old geo anchor if exists
            if let geoAnchor = geoAnchor {
                arSession.remove(anchor: geoAnchor)
            }
            
            // Create new geo anchor at current location
            let newGeoAnchor = ARGeoAnchor(coordinate: location.coordinate)
            arSession.add(anchor: newGeoAnchor)
            self.geoAnchor = newGeoAnchor
            
            print("🌍 Updated geo anchor for persistent tracking")
        }
        
        print("✅ AR anchor updated with final position")
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
        // CRITICAL: Extract data immediately and release the frame reference
        // Don't capture the ARFrame in async tasks - extract only what we need
        guard ballTracker != nil else { return }
        
        // Extract pixel buffer and camera data immediately (don't retain the frame)
        let pixelBuffer = frame.capturedImage
        let cameraTransform = frame.camera.transform
        let timestamp = frame.timestamp
        
        // Process frame data asynchronously without retaining the ARFrame
        Task { [weak self] in
            await self?.processFrameData(
                pixelBuffer: pixelBuffer,
                cameraTransform: cameraTransform,
                timestamp: timestamp
            )
        }
    }
    
    /// Process frame data without retaining the ARFrame
    private func processFrameData(
        pixelBuffer: CVPixelBuffer,
        cameraTransform: simd_float4x4,
        timestamp: TimeInterval
    ) async {
        // Pass only extracted data to ball tracker
        await ballTracker?.processFrameData(
            pixelBuffer: pixelBuffer,
            cameraTransform: cameraTransform,
            timestamp: timestamp
        )
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
        
        // Throttle location updates to reduce memory pressure
        let now = Date()
        guard now.timeIntervalSince(lastLocationUpdate) >= locationUpdateInterval else { return }
        
        currentLocation = location
        lastLocationUpdate = now
        // Reduced logging - only log every 10 seconds to reduce memory pressure
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if originalCompassHeading == 0 {
            originalCompassHeading = newHeading.trueHeading
        }
        
        // Throttle heading updates to reduce memory pressure
        let now = Date()
        guard now.timeIntervalSince(lastHeadingUpdate) >= headingUpdateInterval else { return }
        
        lastHeadingUpdate = now
        // Remove excessive heading prints - they're spamming the console
        // Only log if it's a significant change (>10 degrees)
        let headingChange = abs(newHeading.trueHeading - originalCompassHeading)
        if headingChange > 10.0 {
            print("🧭 Heading updated: \(newHeading.trueHeading)°")
        }
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
