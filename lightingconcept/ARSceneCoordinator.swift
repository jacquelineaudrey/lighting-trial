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

    private var lastObjectType: LearningObjectType?
    private var lastSceneRevision = -1
    private var lastResetObjectFlag = false
    private var lastResetSceneFlag = false
    private var lastRescanFlag = false
    private var defaultObjectPosition = SIMD3<Float>(0, 0, 0)

    init(viewModel: ARSceneViewModel) {
        self.viewModel = viewModel
    }

    func configure(arView: ARView) {
        self.arView = arView
        arView.automaticallyConfigureSession = false
        arView.environment.lighting.intensityExponent = 0
        arView.renderOptions.remove(.disableMotionBlur)

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

        if lastObjectType != viewModel.selectedObjectType {
            replaceObject(on: anchor)
            lastObjectType = viewModel.selectedObjectType
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

    private func addGestures(to arView: ARView) {
        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
        arView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
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

    private func raycastPlane(from point: CGPoint) -> ARRaycastResult? {
        guard let arView else { return nil }
        return arView.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal).first
    }

    private func placeScene(at result: ARRaycastResult) {
        guard let arView else { return }
        let anchor = AnchorEntity(world: result.worldTransform)
        arView.scene.addAnchor(anchor)
        sceneAnchor = anchor
        defaultObjectPosition = .zero

        receiverManager.setupReceiver(on: anchor)
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
        let object = ObjectFactory.makeObject(type: viewModel.selectedObjectType)
        object.position = defaultObjectPosition
        anchor.addChild(object)
        objectEntity = object
        viewModel.debugLog("Object switched to \(viewModel.selectedObjectType.rawValue)")
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
        objectEntity.position = localPosition
        defaultObjectPosition = localPosition
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
        let localPosition = anchor.convert(position: worldPosition, from: nil)
        viewModel.updateSelectedLight { light in
            light.position.x = clamped(localPosition.x, -0.7, 0.7)
            light.position.z = clamped(localPosition.z, -0.7, 0.7)
        }
        synchronizeScene()
        viewModel.debugLog("Selected light moved")
    }

    private func syncLights(on anchor: AnchorEntity) {
        let currentIDs = Set(viewModel.lights.map(\.id))
        for (id, entities) in lightEntities where !currentIDs.contains(id) {
            entities.root.removeFromParent()
            lightEntities[id] = nil
        }

        for light in viewModel.lights {
            let selected = light.id == viewModel.selectedLightID
            if let entities = lightEntities[light.id] {
                LightFactory.update(
                    light: entities.light,
                    marker: entities.marker,
                    ring: entities.selectionRing,
                    configuration: light,
                    selected: selected
                )
            } else {
                let entities = LightFactory.makeLight(configuration: light, selected: selected)
                anchor.addChild(entities.root)
                lightEntities[light.id] = entities
                viewModel.debugLog("Light creation: \(light.name)")
            }
        }
    }

    private func updateEducationalOverlays() {
        guard let objectEntity else { return }
        let objectHeight = ObjectFactory.objectHeight(for: viewModel.selectedObjectType)
        let selectedLight = viewModel.selectedLight
        projectionRenderer.update(
            objectType: viewModel.selectedObjectType,
            objectPosition: objectEntity.position,
            objectHeight: objectHeight,
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
            objectPosition: objectEntity.position,
            objectHeight: objectHeight,
            selectedLight: selectedLight
        )
    }

    private func updateShadowInfo() {
        guard let objectEntity else { return }
        let light = viewModel.selectedLight
        let objectHeight = ObjectFactory.objectHeight(for: viewModel.selectedObjectType)
        viewModel.shadowInfo = ShadowInfo(
            lightType: light.type.rawValue,
            intensity: light.intensity,
            lightHeight: light.position.y,
            yawDegrees: light.yawDegrees,
            pitchDegrees: light.pitchDegrees,
            beamSpread: light.beamSpread.rawValue,
            shadowDirectionDegrees: ShadowGeometryCalculator.shadowDirectionDegrees(
                lightPosition: light.position,
                objectPosition: objectEntity.position
            ),
            shadowLength: ShadowGeometryCalculator.approximateShadowLength(
                lightPosition: light.position,
                objectGroundPosition: objectEntity.position,
                objectHeight: objectHeight
            )
        )
    }

    private func resetObjectPosition() {
        objectEntity?.position = .zero
        defaultObjectPosition = .zero
        updateEducationalOverlays()
        updateShadowInfo()
        viewModel.debugLog("Object position reset")
    }

    private func resetScene() {
        sceneAnchor?.removeFromParent()
        sceneAnchor = nil
        objectEntity = nil
        lightEntities.removeAll()
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
        guard anchors.contains(where: { $0 is ARPlaneAnchor }) else { return }
        Task { @MainActor in
            if self.viewModel.surfaceState == .scanning {
                self.viewModel.surfaceState = .found
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
