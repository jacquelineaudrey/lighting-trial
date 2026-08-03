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
    private let lidarMeshOcclusionManager = LiDARMeshOcclusionManager()
    private let collisionManager = CollisionManager()
    private static let lightObstacleRadius: Float = 0.07
    private static let lidarLightRadius: Float = 0.045
    private static let lidarClearance: Float = 0.006
    private var usesSceneReconstruction = false

    private var lastObjectType: LearningObjectType?
    private var lastTexture: MaterialTexture?
    private var lastSceneRevision = -1
    private var lastSceneSignature: SceneUpdateSignature?
    private var lastResetSceneFlag = false
    private var lastRescanFlag = false
    private var defaultObjectPosition = SIMD3<Float>(0, 0, 0)
    private var verticalLightPanStartHeight: Float?
    private var lastAppliedObjectYawDegrees: Float?
    private var hasLoggedLiDARMeshOcclusion = false

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
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        arView.environment.sceneUnderstanding.options.insert(.receivesLighting)

        arView.session.delegate = self
        addCoachingOverlay(to: arView)
        addGestures(to: arView)
        runSession(resetTracking: true)
        viewModel.debugLog("AR session start")
    }

    func synchronizeScene() {
        guard arView != nil else { return }

        if lastResetSceneFlag != viewModel.pendingResetScene {
            lastResetSceneFlag = viewModel.pendingResetScene
            resetScene()
        }

        if lastRescanFlag != viewModel.pendingRescanSurface {
            lastRescanFlag = viewModel.pendingRescanSurface
            rescanSurface()
        }

        guard let anchor = sceneAnchor else { return }
        let signature = currentSceneSignature()
        guard signature != lastSceneSignature || lastObjectType != viewModel.selectedObjectType else { return }

        if lastObjectType != viewModel.selectedObjectType || lastTexture != viewModel.selectedTexture {
            replaceObject(on: anchor)
            lastObjectType = viewModel.selectedObjectType
            lastTexture = viewModel.selectedTexture
        } else if let objectEntity {
            applyObjectTransform(to: objectEntity)
        }

        syncLights(on: anchor)
        receiverManager.updateSurfaceTexture(viewModel.selectedTexture)
        updateEducationalOverlays()
        updateShadowInfo()
        lastSceneSignature = currentSceneSignature()
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

        // Konfigurasi utama AR:
        // - horizontal plane untuk meja/lantai
        // - environment texturing + light estimation agar object lebih menyatu dengan kamera
        // - LiDAR mesh reconstruction hanya jika device mendukung
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        configuration.isLightEstimationEnabled = true
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
            viewModel.debugLog("LiDAR smoothed scene depth enabled")
        }
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
            usesSceneReconstruction = true
            viewModel.isLiDARAvailable = true
            viewModel.resetLiDARScan()
            // Mesh cyan hanya feedback scan untuk user. Occlusion visual tetap memakai
            // sceneUnderstanding bawaan RealityKit, bukan mesh occluder custom.
            lidarMeshOcclusionManager.setVisualizationEnabled(true)
            viewModel.debugLog("LiDAR scene reconstruction enabled; real-world mesh occlusion active")
        } else {
            usesSceneReconstruction = false
            viewModel.isLiDARAvailable = false
            viewModel.debugLog("LiDAR scene reconstruction unavailable; using flat fallback receiver")
        }

        let options: ARSession.RunOptions = resetTracking ? [.resetTracking, .removeExistingAnchors] : []
        arView.session.run(configuration, options: options)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView else { return }
        let location = gesture.location(in: arView)

        // Label edukasi adalah entity 3D. Saat diketuk, SwiftUI menampilkan alert penjelasan.
        if let entity = arView.entity(at: location),
           entity.name.hasPrefix("Label: ") {
            let conceptName = entity.name.replacingOccurrences(of: "Label: ", with: "")
            viewModel.selectedConcept = ShadowConcept.allCases.first { $0.rawValue == conceptName }
            return
        }

        if let entity = arView.entity(at: location),
           selectLight(containing: entity) {
            viewModel.interactionMode = .moveLight
            synchronizeScene()
            return
        }

        guard let result = raycastPlane(from: location) else { return }

        if sceneAnchor == nil {
            // Di device LiDAR, placement ditahan sampai coverage scan cukup agar posisi awal
            // object dan receiver tidak terlalu meleset dari meja/lantai yang sebenarnya.
            guard viewModel.isReadyForPlacement else {
                viewModel.debugLog("Object placement blocked until LiDAR scan reaches target coverage")
                return
            }
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
            moveObject(to: result, logWhenMoved: gesture.state == .ended)
        case .moveLight:
            moveSelectedLight(to: result, logWhenMoved: gesture.state == .ended)
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

        // Utamakan bidang horizontal yang sudah benar-benar terdeteksi.
        // Estimated plane hanya fallback supaya app tetap bisa dipakai saat scanning awal.
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
        lidarMeshOcclusionManager.setVisualizationEnabled(false)

        // Receiver invisible inilah yang menangkap dynamic shadow.
        // Kamera asli tidak bisa langsung menerima shadow karena hanya video background.
        receiverManager.setupReceiver(
            on: anchor,
            usesFlatFallback: !usesSceneReconstruction,
            surfaceTexture: viewModel.selectedTexture
        )
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
        applyObjectTransform(to: object)
        anchor.addChild(object)
        objectEntity = object
        viewModel.debugLog("Shadow caster changed to \(viewModel.selectedObjectType.rawValue)")
    }

    private func moveObject(to result: ARRaycastResult, logWhenMoved: Bool = false) {
        guard let anchor = sceneAnchor, let objectEntity else { return }
        let worldPosition = SIMD3<Float>(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y,
            result.worldTransform.columns.3.z
        )
        var localPosition = anchor.convert(position: worldPosition, from: nil)
        localPosition.y = 0
        // Object selalu digrounding ke anchor plane. Tinggi visual dihitung ulang
        // di `applyObjectTransform` supaya setiap shape tetap duduk di permukaan.
        let resolution = resolvedObjectPosition(
            from: defaultObjectPosition,
            to: localPosition,
            relativeTo: anchor
        )
        defaultObjectPosition = resolution.position
        viewModel.collisionWarning = nil
        applyObjectTransform(to: objectEntity)
        updateEducationalOverlays()
        updateShadowInfo()
        lastSceneSignature = currentSceneSignature()
        if logWhenMoved {
            viewModel.debugLog("Object moved")
        }
    }

    private func moveSelectedLight(to result: ARRaycastResult, logWhenMoved: Bool = false) {
        guard let anchor = sceneAnchor else { return }
        let worldPosition = SIMD3<Float>(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y,
            result.worldTransform.columns.3.z
        )
        var localPosition = anchor.convert(position: worldPosition, from: nil)
        localPosition.x = clamped(localPosition.x, -0.9, 0.9)
        localPosition.z = clamped(localPosition.z, -0.9, 0.9)

        // Drag satu jari hanya mengubah X/Z. Height dikontrol slider atau two-finger pan
        // supaya light tidak tiba-tiba naik/turun saat user menggeser marker.
        let selectedID = viewModel.selectedLightID
        let currentPosition = viewModel.selectedLight.position
        localPosition.y = currentPosition.y
        let resolution = collisionManager.resolvedPosition(
            candidatePosition: localPosition,
            movingRadius: Self.lightObstacleRadius,
            excludingID: selectedID
        )
        localPosition = resolution.position
        let collisionWarning: String?
        if resolution.didCollide {
            collisionWarning = "Light stopped by another virtual object."
        } else {
            collisionWarning = nil
        }

        viewModel.updateSelectedLight { light in
            light.position.x = clamped(localPosition.x, -0.9, 0.9)
            light.position.z = clamped(localPosition.z, -0.9, 0.9)
        }
        collisionManager.updatePosition(id: selectedID, position: viewModel.selectedLight.position)
        synchronizeScene()
        viewModel.collisionWarning = collisionWarning
        if logWhenMoved {
            viewModel.debugLog("Selected light moved")
        }
    }

    private func syncLights(on anchor: AnchorEntity) {
        // Sinkronisasi state SwiftUI ke entity RealityKit. Entity lama dipakai ulang
        // agar performa lebih stabil daripada recreate semua light setiap update.
        let currentIDs = Set(viewModel.lights.map(\.id))
        for (id, entities) in lightEntities where !currentIDs.contains(id) {
            entities.root.removeFromParent()
            lightEntities[id] = nil
            collisionManager.removeObstacle(id: id)
            viewModel.debugLog("Light deletion cleaned up from scene")
        }

        var selectedCollisionWarning: String?

        for requestedLight in viewModel.lights {
            var light = requestedLight
            let selected = light.id == viewModel.selectedLightID

            if let entities = lightEntities[light.id] {
                let virtualResolution = collisionManager.resolvedPosition(
                    candidatePosition: light.position,
                    movingRadius: Self.lightObstacleRadius,
                    excludingID: light.id
                )
                light.position = virtualResolution.position

                if light.position != requestedLight.position {
                    viewModel.updateLightPosition(id: light.id, position: light.position)
                }

                if selected {
                    if virtualResolution.didCollide {
                        selectedCollisionWarning = "Light stopped by another virtual object."
                    }
                }

                let effectiveLight = effectiveLightConfiguration(for: light)
                LightFactory.update(
                    light: entities.light,
                    fillLight: entities.fillLight,
                    marker: entities.marker,
                    ring: entities.selectionRing,
                    configuration: effectiveLight,
                    selected: selected
                )
                collisionManager.updatePosition(id: light.id, position: light.position)
            } else {
                let effectiveLight = effectiveLightConfiguration(for: light)
                let entities = LightFactory.makeLight(configuration: effectiveLight, selected: selected)
                anchor.addChild(entities.root)
                lightEntities[light.id] = entities
                collisionManager.registerObstacle(id: light.id, position: light.position, radius: Self.lightObstacleRadius)
                viewModel.debugLog("Light creation: \(effectiveLight.name)")
            }
        }

        viewModel.collisionWarning = selectedCollisionWarning
    }

    private func resolvedObjectPosition(
        from currentGroundPosition: SIMD3<Float>,
        to candidateGroundPosition: SIMD3<Float>,
        relativeTo anchor: Entity
    ) -> (position: SIMD3<Float>, didCollide: Bool) {
        // Collision terhadap LiDAR mesh sengaja dinonaktifkan untuk movement.
        // Mesh scan sering noisy; kalau dipakai sebagai blocker, object/light bisa
        // terlihat "nyangkut" padahal tidak ada penghalang nyata di kamera.
        return (candidateGroundPosition, false)
    }

    private func resolvedLiDARPosition(
        from currentPosition: SIMD3<Float>,
        to candidatePosition: SIMD3<Float>,
        shape: ShapeResource,
        orientation: simd_quatf,
        relativeTo anchor: Entity,
        ignoringSupportBelow supportSurfaceMaximumHeight: Float? = nil
    ) -> (position: SIMD3<Float>, didCollide: Bool) {
        guard usesSceneReconstruction, let arView else {
            return (candidatePosition, false)
        }

        var remainingTravel = candidatePosition - currentPosition
        guard simd_length(remainingTravel) > 0.0001 else {
            return (candidatePosition, false)
        }

        var resolvedPosition = currentPosition
        var didCollide = false

        // Resolve once toward the requested point, then once more along the
        // contact plane. This prevents tunnelling while still allowing a drag
        // to glide naturally beside a wall or piece of scanned furniture.
        for _ in 0..<2 {
            let travelDistance = simd_length(remainingTravel)
            guard travelDistance > 0.0001 else { break }

            let direction = remainingTravel / travelDistance
            let destination = resolvedPosition + remainingTravel
            let hits = arView.scene.convexCast(
                convexShape: shape,
                fromPosition: resolvedPosition,
                fromOrientation: orientation,
                toPosition: destination,
                toOrientation: orientation,
                query: .all,
                mask: .sceneUnderstanding,
                relativeTo: anchor
            )
            let blockingHit = hits
                .filter { hit in
                    if let supportSurfaceMaximumHeight,
                       hit.normal.y > 0.65,
                       hit.position.y <= supportSurfaceMaximumHeight {
                        return false
                    }

                    // LiDAR meshes can fluctuate slightly around the current
                    // location. A zero-distance hit must not trap an entity
                    // that is moving out of the reconstructed surface.
                    return hit.distance > Self.lidarClearance
                        || simd_dot(direction, hit.normal) <= 0.05
                }
                .min { $0.distance < $1.distance }

            guard let hit = blockingHit else {
                resolvedPosition = destination
                break
            }

            didCollide = true
            let safeDistance = max(0, min(travelDistance, hit.distance - Self.lidarClearance))
            resolvedPosition += direction * safeDistance

            let unusedTravel = destination - resolvedPosition
            let travelIntoSurface = simd_dot(unusedTravel, hit.normal)
            guard travelIntoSurface < 0 else {
                resolvedPosition = destination
                break
            }

            resolvedPosition += hit.normal * Self.lidarClearance
            remainingTravel = unusedTravel - hit.normal * travelIntoSurface
        }

        return (resolvedPosition, didCollide)
    }

    private func updateEducationalOverlays() {
        guard objectEntity != nil else { return }
        let objectHeight = scaledObjectHeight
        let selectedLight = effectiveLightConfiguration(for: viewModel.selectedLight)
        // Overlay memakai perhitungan geometri yang sama dengan arah spotlight,
        // tetapi tidak ikut membuat shadow. Ini murni lapisan edukasi.
        projectionRenderer.update(
            objectType: viewModel.selectedObjectType,
            objectPosition: objectGroundPosition,
            objectHeight: objectHeight,
            objectYawDegrees: viewModel.objectYawDegrees,
            lightTarget: lightingTarget(objectHeight: objectHeight),
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
        guard objectEntity != nil else { return }
        let light = effectiveLightConfiguration(for: viewModel.selectedLight)
        let objectHeight = scaledObjectHeight
        let nextInfo = ShadowInfo(
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
        if viewModel.shadowInfo != nextInfo {
            viewModel.shadowInfo = nextInfo
        }
    }

    private var objectGroundPosition: SIMD3<Float> {
        defaultObjectPosition
    }

    private func resetScene() {
        sceneAnchor?.removeFromParent()
        sceneAnchor = nil
        objectEntity = nil
        lightEntities.removeAll()
        collisionManager.removeAll()
        receiverManager.reset()
        projectionRenderer.clear()
        annotationManager.clear()
        lastSceneSignature = nil
        lastObjectType = nil
        lastTexture = nil
        viewModel.isObjectPlaced = false
        viewModel.surfaceState = .found
        viewModel.debugLog("Scene reset")
    }

    private func rescanSurface() {
        lidarMeshOcclusionManager.reset()
        hasLoggedLiDARMeshOcclusion = false
        viewModel.resetLiDARScan()
        resetScene()
        viewModel.surfaceState = .scanning
        runSession(resetTracking: true)
        coachingOverlay?.setActive(true, animated: true)
        viewModel.debugLog("Surface rescan requested")
    }

    private func currentSceneSignature() -> SceneUpdateSignature {
        SceneUpdateSignature(
            objectType: viewModel.selectedObjectType,
            selectedTexture: viewModel.selectedTexture,
            objectScale: viewModel.objectScale,
            objectYawDegrees: viewModel.objectYawDegrees,
            lights: viewModel.lights,
            selectedLightID: viewModel.selectedLightID,
            showLightDirection: viewModel.showLightDirection,
            showLightRays: viewModel.showLightRays,
            showProjectionLines: viewModel.showProjectionLines,
            showGroundProjection: viewModel.showGroundProjection,
            showShadowLabels: viewModel.showShadowLabels,
            showShadowInformation: viewModel.showShadowInformation
        )
    }

    private func selectLight(containing entity: Entity) -> Bool {
        for (id, entities) in lightEntities {
            if entity == entities.marker || entity == entities.selectionRing {
                viewModel.selectedLightID = id
                viewModel.debugLog("Selected light changed")
                return true
            }
        }
        return false
    }

    private func applyObjectTransform(to object: ModelEntity) {
        let scaledHeight = scaledObjectHeight
        object.position = SIMD3<Float>(
            defaultObjectPosition.x,
            scaledHeight / 2,
            defaultObjectPosition.z
        )
        object.scale = SIMD3<Float>(repeating: viewModel.objectScale)
        object.orientation = simd_quatf(
            angle: viewModel.objectYawDegrees.degreesToRadians,
            axis: SIMD3<Float>(0, 1, 0)
        )
        if lastAppliedObjectYawDegrees != viewModel.objectYawDegrees {
            lastAppliedObjectYawDegrees = viewModel.objectYawDegrees
            viewModel.debugLog("Object rotation updated")
        }
    }

    private var scaledObjectHeight: Float {
        ObjectFactory.objectHeight(for: viewModel.selectedObjectType) * viewModel.objectScale
    }

    private func effectiveLightConfiguration(for light: LightConfiguration) -> LightConfiguration {
        guard light.type == .spot, objectEntity != nil else { return light }

        var adjusted = light
        let target = lightingTarget(objectHeight: scaledObjectHeight)
        let delta = target - light.position
        let horizontalDistance = sqrt(delta.x * delta.x + delta.z * delta.z)
        guard horizontalDistance > 0.001 || abs(delta.y) > 0.001 else { return adjusted }

        // RealityKit spotlight mengarah ke local -Z. Yaw menghadap target secara horizontal,
        // pitch mengangkat/menurunkan beam sesuai beda tinggi light dan object.
        adjusted.yawDegrees = atan2(delta.x, -delta.z).radiansToDegrees
        adjusted.pitchDegrees = atan2(delta.y, horizontalDistance).radiansToDegrees
        return adjusted
    }

    private func lightingTarget(objectHeight: Float) -> SIMD3<Float> {
        // Target sedikit di atas tengah object agar beam menyinari form, bukan hanya kaki object.
        objectGroundPosition + SIMD3<Float>(0, objectHeight * 0.58, 0)
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        Task { @MainActor in
            self.updateLiDARMeshOcclusion(from: anchors)
            if anchors.contains(where: { $0 is ARPlaneAnchor }),
               self.viewModel.surfaceState == .scanning {
                self.viewModel.surfaceState = .found
                self.coachingOverlay?.setActive(false, animated: true)
                self.viewModel.debugLog("Horizontal plane detected")
            }

        }
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        Task { @MainActor in
            self.updateLiDARMeshOcclusion(from: anchors)
        }
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        Task { @MainActor in
            self.lidarMeshOcclusionManager.remove(anchors: anchors)
        }
    }

    private func updateLiDARMeshOcclusion(from anchors: [ARAnchor]) {
        guard usesSceneReconstruction, let arView else { return }
        let result = lidarMeshOcclusionManager.update(from: anchors, in: arView)
        if result.updatedCount > 0 {
            viewModel.updateLiDARScan(meshCount: result.meshCount, faceCount: result.faceCount)
        }
        if result.updatedCount > 0, !hasLoggedLiDARMeshOcclusion {
            hasLoggedLiDARMeshOcclusion = true
            viewModel.debugLog("LiDAR scan mesh visualization updated; ARKit scene understanding handles occlusion")
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
