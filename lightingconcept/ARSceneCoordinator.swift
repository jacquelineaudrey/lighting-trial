import Foundation
import ARKit
import RealityKit
import UIKit

@MainActor
final class ARSceneCoordinator: NSObject, ARSessionDelegate, ARCoachingOverlayViewDelegate {
    private let viewModel: ARSceneViewModel
    private weak var arView: ARView?
    private var coachingOverlay: ARCoachingOverlayView?

    private var sceneAnchor: AnchorEntity?
    private var objectEntity: ModelEntity?
    private var lightEntities: [UUID: LightSceneEntities] = [:]

    private let projectionRenderer = ProjectionLineRenderer()
    private let annotationManager = ShadowAnnotationManager()
    private let receiverManager = ShadowReceiverManager()
    private let collisionManager = CollisionManager()

    /// Fixed identity for the single learning object obstacle, so
    /// CollisionManager can tell it apart from light obstacles.
    private let objectObstacleID = UUID()

    /// Approximate footprint used for light-vs-light and light-vs-object
    /// collision checks. Lights are small marker spheres, not real geometry.
    private static let lightObstacleRadius: Float = 0.04

    private var lastObjectType: LearningObjectType?
    private var lastTexture: MaterialTexture?
    private var lastSceneRevision = -1
    private var lastResetObjectFlag = false
    private var lastResetSceneFlag = false
    private var lastRescanFlag = false
    private var defaultObjectPosition = SIMD3<Float>(0, 0, 0)
    private var verticalLightPanStartHeight: Float?

    init(viewModel: ARSceneViewModel) {
        self.viewModel = viewModel
    }

    func configure(arView: ARView) {
        self.arView = arView
        arView.automaticallyConfigureSession = false
        arView.environment.lighting.intensityExponent = 0
        arView.renderOptions.insert(.disableMotionBlur)
        arView.renderOptions.insert(.disableDepthOfField)
        arView.renderOptions.insert(.disablePersonOcclusion)
        arView.environment.sceneUnderstanding.options.insert(.receivesLighting)
        arView.environment.sceneUnderstanding.options.insert(.collision)
        arView.environment.sceneUnderstanding.options.insert(.physics)

        arView.session.delegate = self
        addCoachingOverlay(to: arView)
        addGestures(to: arView)
        runSession(resetTracking: true)
        viewModel.debugLog("AR session start")
    }

    func synchronizeScene() {
        guard arView != nil else { return }

        if lastResetObjectFlag != viewModel.pendingResetObject {
            lastResetObjectFlag = viewModel.pendingResetObject
            resetObjectPosition()
        }

        if lastResetSceneFlag != viewModel.pendingResetScene {
            lastResetSceneFlag = viewModel.pendingResetScene
            resetScene()
        }

        if lastRescanFlag != viewModel.pendingRescanSurface {
            lastRescanFlag = viewModel.pendingRescanSurface
            rescanSurface()
        }

        guard let anchor = sceneAnchor else { return }

        if lastObjectType != viewModel.selectedObjectType || lastTexture != viewModel.selectedTexture {
            replaceObject(on: anchor)
            lastObjectType = viewModel.selectedObjectType
            lastTexture = viewModel.selectedTexture
        } else if let objectEntity {
            applyObjectTransform(to: objectEntity, groundPosition: defaultObjectPosition)
        }

        syncLights(on: anchor)
        updateEducationalOverlays()
        updateShadowInfo()
        lastSceneRevision = viewModel.sceneRevision
    }

    private func addCoachingOverlay(to arView: ARView) {
        let overlay = ARCoachingOverlayView()
        overlay.session = arView.session
        overlay.goal = .horizontalPlane
        overlay.activatesAutomatically = true
        overlay.delegate = self
        overlay.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: arView.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: arView.bottomAnchor)
        ])
        coachingOverlay = overlay
    }

    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        resetScene()
        viewModel.surfaceState = .scanning
        runSession(resetTracking: true)
        viewModel.debugLog("Coaching overlay requested a full session reset")
    }
    
    private func addGestures(to arView: ARView) {
        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))

        let horizontalPan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        horizontalPan.minimumNumberOfTouches = 1
        horizontalPan.maximumNumberOfTouches = 1
        arView.addGestureRecognizer(horizontalPan)

        let verticalPan = UIPanGestureRecognizer(target: self, action: #selector(handleVerticalLightPan(_:)))
        verticalPan.minimumNumberOfTouches = 2
        verticalPan.maximumNumberOfTouches = 2
        arView.addGestureRecognizer(verticalPan)
    }

    private func runSession(resetTracking: Bool) {
        guard let arView else { return }
        guard ARWorldTrackingConfiguration.isSupported else {
            viewModel.debugLog("ARWorldTrackingConfiguration is not supported on this device")
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
            viewModel.debugLog("LiDAR scene reconstruction enabled")
        } else {
            viewModel.debugLog("LiDAR scene reconstruction unavailable")
        }

        let options: ARSession.RunOptions = resetTracking ? [.resetTracking, .removeExistingAnchors] : []
        arView.session.run(configuration, options: options)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView else { return }
        let location = gesture.location(in: arView)

        if viewModel.interactionMode == .exploreShadow,
           let entity = arView.entity(at: location),
           entity.name.hasPrefix("Label: ") {
            let conceptName = entity.name.replacingOccurrences(of: "Label: ", with: "")
            viewModel.selectedConcept = ShadowConcept.allCases.first { $0.rawValue == conceptName }
            return
        }

        guard let result = raycastPlane(from: location) else { return }

        if sceneAnchor == nil {
            placeScene(at: result)
        } else if viewModel.interactionMode == .moveObject {
            moveObject(to: result)
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let arView else { return }
        let location = gesture.location(in: arView)
        guard let result = raycastPlane(from: location) else { return }

        switch viewModel.interactionMode {
        case .moveObject:
            moveObject(to: result)
        case .moveLight:
            moveSelectedLight(to: result)
        case .exploreShadow:
            break
        }
    }

    @objc private func handleVerticalLightPan(_ gesture: UIPanGestureRecognizer) {
        guard let arView, viewModel.interactionMode == .moveLight else { return }

        switch gesture.state {
        case .began:
            verticalLightPanStartHeight = viewModel.selectedLight.position.y
        case .changed:
            guard let startHeight = verticalLightPanStartHeight else { return }
            let translation = gesture.translation(in: arView)
            // Dragging upward raises the light; 500 points spans one metre.
            let height = clamped(startHeight - Float(translation.y) / 500, -0.2, 2.0)
            viewModel.updateSelectedLight { $0.position.y = height }
            synchronizeScene()
        case .ended, .cancelled, .failed:
            verticalLightPanStartHeight = nil
        default:
            break
        }
    }

    private func raycastPlane(from point: CGPoint) -> ARRaycastResult? {
        guard let arView else { return nil }

        // Once ARKit has found a horizontal plane, anchor to that measured
        // geometry. Estimated planes are useful only as a fallback while the
        // device is still scanning and can otherwise make placement jumpy.
        if let measuredPlane = arView.raycast(
            from: point,
            allowing: .existingPlaneGeometry,
            alignment: .horizontal
        ).first {
            return measuredPlane
        }

        return arView.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal).first
    }

    private func placeScene(at result: ARRaycastResult) {
        guard let arView else { return }
        let anchor = AnchorEntity(world: result.worldTransform)
        arView.scene.addAnchor(anchor)
        sceneAnchor = anchor
        defaultObjectPosition = .zero

        receiverManager.setupReceiver(on: anchor, usesFlatFallback: true)
        projectionRenderer.attach(to: anchor)
        annotationManager.attach(to: anchor)
        replaceObject(on: anchor)
        syncLights(on: anchor)

        viewModel.surfaceState = .placed
        viewModel.isObjectPlaced = true
        viewModel.debugLog("Object placement completed on selected surface")
    }

    private func replaceObject(on anchor: AnchorEntity) {
        objectEntity?.removeFromParent()
        let object = ObjectFactory.makeObject(type: viewModel.selectedObjectType, texture: viewModel.selectedTexture)
        applyObjectTransform(to: object, groundPosition: defaultObjectPosition)
        anchor.addChild(object)
        objectEntity = object

        collisionManager.registerObstacle(
            id: objectObstacleID,
            position: object.position,
            radius: ObjectFactory.boundingRadius(for: viewModel.selectedObjectType)
        )

        viewModel.debugLog("Object switched to \(viewModel.selectedObjectType.rawValue), texture \(viewModel.selectedTexture.name)")
    }

    private func moveObject(to result: ARRaycastResult) {
        guard let anchor = sceneAnchor, let objectEntity else { return }
        let worldPosition = SIMD3<Float>(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y,
            result.worldTransform.columns.3.z
        )
        var localPosition = anchor.convert(position: worldPosition, from: nil)
        localPosition.y = 0

        let resolution = collisionManager.resolvedPosition(
            candidatePosition: localPosition,
            movingRadius: ObjectFactory.boundingRadius(for: viewModel.selectedObjectType),
            excludingID: objectObstacleID
        )
        localPosition = resolution.position
        localPosition.y = 0

        applyObjectTransform(to: objectEntity, groundPosition: localPosition)
        defaultObjectPosition = localPosition
        collisionManager.updatePosition(id: objectObstacleID, position: localPosition)
        viewModel.collisionWarning = resolution.didCollide ? "Object blocked by another object" : nil

        updateEducationalOverlays()
        updateShadowInfo()
        viewModel.debugLog("Object moved")
    }

    private func moveSelectedLight(to result: ARRaycastResult) {
        guard let anchor = sceneAnchor else { return }
        let worldPosition = SIMD3<Float>(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y,
            result.worldTransform.columns.3.z
        )
        var localPosition = anchor.convert(position: worldPosition, from: nil)
        localPosition.x = clamped(localPosition.x, -0.9, 0.9)
        localPosition.z = clamped(localPosition.z, -0.9, 0.9)

        let selectedID = viewModel.selectedLightID
        let resolution = collisionManager.resolvedPosition(
            candidatePosition: localPosition,
            movingRadius: Self.lightObstacleRadius,
            excludingID: selectedID
        )
        localPosition = resolution.position
        viewModel.collisionWarning = resolution.didCollide ? "Light blocked by another object" : nil

        viewModel.updateSelectedLight { light in
            light.position.x = clamped(localPosition.x, -0.9, 0.9)
            light.position.z = clamped(localPosition.z, -0.9, 0.9)
        }
        collisionManager.updatePosition(id: selectedID, position: viewModel.selectedLight.position)
        synchronizeScene()
        viewModel.debugLog("Selected light moved")
    }

    private func syncLights(on anchor: AnchorEntity) {
        let currentIDs = Set(viewModel.lights.map(\.id))
        for (id, entities) in lightEntities where !currentIDs.contains(id) {
            entities.root.removeFromParent()
            lightEntities[id] = nil
            collisionManager.removeObstacle(id: id)
            viewModel.debugLog("Light deletion cleaned up from scene")
        }

        for light in viewModel.lights {
            let effectiveLight = effectiveLightConfiguration(for: light)
            let selected = light.id == viewModel.selectedLightID
            if let entities = lightEntities[light.id] {
                LightFactory.update(
                    light: entities.light,
                    marker: entities.marker,
                    ring: entities.selectionRing,
                    configuration: effectiveLight,
                    selected: selected
                )
                collisionManager.updatePosition(id: light.id, position: light.position)
            } else {
                let entities = LightFactory.makeLight(configuration: effectiveLight, selected: selected)
                anchor.addChild(entities.root)
                lightEntities[light.id] = entities
                collisionManager.registerObstacle(id: light.id, position: light.position, radius: Self.lightObstacleRadius)
                viewModel.debugLog("Light creation: \(effectiveLight.name)")
            }
        }
    }

    private func updateEducationalOverlays() {
        guard let objectEntity else { return }
        let objectHeight = ObjectFactory.objectHeight(for: viewModel.selectedObjectType)
        let selectedLight = effectiveLightConfiguration(for: viewModel.selectedLight)
        let objectGroundPosition = groundPosition(of: objectEntity)
        projectionRenderer.update(
            objectType: viewModel.selectedObjectType,
            objectPosition: objectGroundPosition,
            objectHeight: objectHeight,
            objectYawDegrees: viewModel.objectYawDegrees,
            selectedLight: selectedLight,
            toggles: OverlayToggles(
                showLightDirection: viewModel.showLightDirection,
                showLightRays: viewModel.showLightRays,
                showProjectionLines: viewModel.showProjectionLines,
                showGroundProjection: viewModel.showGroundProjection
            )
        )
        annotationManager.update(
            visible: viewModel.showShadowLabels,
            objectType: viewModel.selectedObjectType,
            objectPosition: objectGroundPosition,
            objectHeight: objectHeight,
            selectedLight: selectedLight
        )
    }

    private func updateShadowInfo() {
        guard let objectEntity else { return }
        let light = effectiveLightConfiguration(for: viewModel.selectedLight)
        let objectHeight = ObjectFactory.objectHeight(for: viewModel.selectedObjectType)
        let objectGroundPosition = groundPosition(of: objectEntity)
        let updatedShadowInfo = ShadowInfo(
            lightType: light.type.rawValue,
            intensity: light.intensity,
            lightHeight: light.position.y,
            yawDegrees: light.yawDegrees,
            pitchDegrees: light.pitchDegrees,
            beamSpread: light.beamSpread.rawValue,
            shadowDirectionDegrees: ShadowGeometryCalculator.shadowDirectionDegrees(
                lightPosition: light.position,
                objectPosition: objectGroundPosition
            ),
            shadowLength: ShadowGeometryCalculator.approximateShadowLength(
                lightPosition: light.position,
                objectGroundPosition: objectGroundPosition,
                objectHeight: objectHeight
            )
        )

        // Do not publish an identical value. This method is also reached from
        // SwiftUI-driven scene synchronization, so publishing unchanged data
        // would request another render for no visible change.
        if viewModel.shadowInfo != updatedShadowInfo {
            viewModel.shadowInfo = updatedShadowInfo
        }
    }

    private func resetObjectPosition() {
        defaultObjectPosition = .zero
        if let objectEntity {
            applyObjectTransform(to: objectEntity, groundPosition: defaultObjectPosition)
        }
        updateEducationalOverlays()
        updateShadowInfo()
        viewModel.debugLog("Object position reset")
    }

    /// `defaultObjectPosition` and collision coordinates describe the contact
    /// point on the floor; the model itself is raised by half its height.
    private func renderedObjectPosition(for groundPosition: SIMD3<Float>) -> SIMD3<Float> {
        groundPosition + SIMD3<Float>(0, ObjectFactory.groundOffset(for: viewModel.selectedObjectType), 0)
    }

    private func applyObjectTransform(to object: ModelEntity, groundPosition: SIMD3<Float>) {
        object.position = renderedObjectPosition(for: groundPosition)
        object.orientation = simd_quatf(
            angle: viewModel.objectYawDegrees * .pi / 180,
            axis: SIMD3<Float>(0, 1, 0)
        )
    }

    private func groundPosition(of object: ModelEntity) -> SIMD3<Float> {
        SIMD3<Float>(object.position.x, 0, object.position.z)
    }

    private func effectiveLightConfiguration(for light: LightConfiguration) -> LightConfiguration {
        guard light.type == .spot, let objectEntity else { return light }

        var adjusted = light
        let objectCenter = objectEntity.position
        let delta = objectCenter - light.position
        let horizontalDistance = sqrt(delta.x * delta.x + delta.z * delta.z)
        guard horizontalDistance > 0.001 || abs(delta.y) > 0.001 else { return adjusted }

        adjusted.yawDegrees = atan2(delta.x, -delta.z) * 180 / .pi
        adjusted.pitchDegrees = atan2(delta.y, horizontalDistance) * 180 / .pi
        return adjusted
    }

    private func resetScene() {
        sceneAnchor?.removeFromParent()
        sceneAnchor = nil
        objectEntity = nil
        lightEntities.removeAll()
        collisionManager.removeAll()
        receiverManager.reset()
        projectionRenderer.clear()
        viewModel.isObjectPlaced = false
        viewModel.surfaceState = .found
        viewModel.debugLog("Scene reset")
    }

    private func rescanSurface() {
        resetScene()
        viewModel.surfaceState = .scanning
        runSession(resetTracking: true)
        coachingOverlay?.setActive(true, animated: true)
        viewModel.debugLog("Surface rescan requested")
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        handleDetectedHorizontalPlane(in: anchors)
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        handleDetectedHorizontalPlane(in: anchors)
    }

    private nonisolated func handleDetectedHorizontalPlane(in anchors: [ARAnchor]) {
        guard anchors.contains(where: { ($0 as? ARPlaneAnchor)?.alignment == .horizontal }) else { return }
        Task { @MainActor in
            if self.viewModel.surfaceState == .scanning {
                self.viewModel.surfaceState = .found
                self.coachingOverlay?.setActive(false, animated: true)
                self.viewModel.debugLog("Horizontal plane detected")
            }
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.viewModel.debugLog("AR session error: \(error.localizedDescription)")
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            self.viewModel.debugLog("AR session interrupted")
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in
            self.viewModel.debugLog("AR session interruption ended")
            self.runSession(resetTracking: false)
        }
    }
}
