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
    private var objectEntities: [UUID: Entity] = [:]
    private var objectSourceKeys: [UUID: String] = [:]
    private var objectLoadTasks: [UUID: Task<Void, Never>] = [:]
    private var lightEntities: [UUID: LightSceneEntities] = [:]

    private let projectionRenderer = ProjectionLineRenderer()
    private let annotationManager = ShadowAnnotationManager()
    private let receiverManager = ShadowReceiverManager()
    private let collisionManager = CollisionManager()
    private static let lightObstacleRadius: Float = 0.07
    private static let lidarLightRadius: Float = 0.045
    private static let lidarClearance: Float = 0.006
    private var usesSceneReconstruction = false

    private var lastTexture: MaterialTexture?
    private var lastSceneRevision = -1
    private var lastSceneSignature: SceneUpdateSignature?
    private var lastResetObjectFlag = false
    private var lastResetSceneFlag = false
    private var lastRescanFlag = false
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
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
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
        let signature = currentSceneSignature()
        guard signature != lastSceneSignature else { return }

        syncObjects(on: anchor)
        syncLights(on: anchor)
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

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
            usesSceneReconstruction = true
            viewModel.debugLog("LiDAR scene reconstruction enabled; collision and real-world occlusion active")
        } else {
            usesSceneReconstruction = false
            viewModel.debugLog("LiDAR scene reconstruction unavailable; using flat fallback receiver")
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

        if let entity = arView.entity(at: location),
           selectLight(containing: entity) {
            viewModel.interactionMode = .moveLight
            synchronizeScene()
            return
        }

        if let entity = arView.entity(at: location),
           selectObject(containing: entity) {
            viewModel.interactionMode = .moveObject
            synchronizeScene()
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
            moveObject(to: result, logWhenMoved: gesture.state == .ended)
        case .moveLight:
            moveSelectedLight(to: result, logWhenMoved: gesture.state == .ended)
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

        receiverManager.setupReceiver(on: anchor, usesFlatFallback: !usesSceneReconstruction)
        projectionRenderer.attach(to: anchor)
        annotationManager.attach(to: anchor)
        syncObjects(on: anchor)
        syncLights(on: anchor)

        viewModel.surfaceState = .placed
        viewModel.isObjectPlaced = true
        viewModel.debugLog("Object placement completed on selected surface")
    }

    private func moveObject(to result: ARRaycastResult, logWhenMoved: Bool = false) {
        let selectedObject = viewModel.selectedObject
        guard let anchor = sceneAnchor,
              let objectEntity = objectEntities[selectedObject.id] else { return }
        let worldPosition = SIMD3<Float>(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y,
            result.worldTransform.columns.3.z
        )
        var localPosition = anchor.convert(position: worldPosition, from: nil)
        localPosition.y = 0

        let height = ObjectFactory.objectHeight(for: selectedObject) * selectedObject.scale
        let centerOffset = SIMD3<Float>(0, height / 2, 0)
        let virtualResolution = collisionManager.resolvedPosition(
            candidatePosition: localPosition + centerOffset,
            movingRadius: ObjectFactory.collisionRadius(for: selectedObject),
            excludingID: selectedObject.id
        )
        localPosition = virtualResolution.position - centerOffset
        localPosition.y = 0

        let lidarResolution = resolvedObjectPosition(
            object: selectedObject,
            from: selectedObject.position,
            to: localPosition,
            relativeTo: anchor
        )
        viewModel.updateObjectPosition(id: selectedObject.id, position: lidarResolution.position)
        let updatedObject = viewModel.selectedObject
        collisionManager.updatePosition(
            id: updatedObject.id,
            position: obstaclePosition(for: updatedObject)
        )
        if lidarResolution.didCollide {
            viewModel.collisionWarning = "Object stopped by a scanned real-world surface."
        } else if virtualResolution.didCollide {
            viewModel.collisionWarning = "Object stopped by another virtual object."
        } else {
            viewModel.collisionWarning = nil
        }
        applyObjectTransform(to: objectEntity, configuration: updatedObject)
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

        let selectedID = viewModel.selectedLightID
        let currentPosition = viewModel.selectedLight.position
        localPosition.y = currentPosition.y
        let resolution = collisionManager.resolvedPosition(
            candidatePosition: localPosition,
            movingRadius: Self.lightObstacleRadius,
            excludingID: selectedID
        )
        localPosition = resolution.position
        let lidarResolution = resolvedLiDARPosition(
            from: currentPosition,
            to: localPosition,
            shape: .generateSphere(radius: Self.lidarLightRadius),
            orientation: .init(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
            relativeTo: anchor
        )
        localPosition = lidarResolution.position
        let collisionWarning: String?
        if lidarResolution.didCollide {
            collisionWarning = "Light stopped by a scanned real-world surface."
        } else if resolution.didCollide {
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

    private func syncObjects(on anchor: AnchorEntity) {
        let currentIDs = Set(viewModel.objects.map { $0.id })
        for (id, entity) in objectEntities where !currentIDs.contains(id) {
            objectLoadTasks[id]?.cancel()
            objectLoadTasks[id] = nil
            entity.removeFromParent()
            objectEntities[id] = nil
            objectSourceKeys[id] = nil
            collisionManager.removeObstacle(id: id)
            viewModel.debugLog("Object deletion cleaned up from scene")
        }

        let textureChanged = lastTexture != viewModel.selectedTexture
        for configuration in viewModel.objects {
            let sourceKey = objectSourceKey(for: configuration)
            let needsReplacement = objectEntities[configuration.id] == nil
                || objectSourceKeys[configuration.id] != sourceKey
                || (configuration.importedModel == nil && textureChanged)

            if needsReplacement {
                objectLoadTasks[configuration.id]?.cancel()
                objectLoadTasks[configuration.id] = nil
                objectEntities[configuration.id]?.removeFromParent()

                if let importedModel = configuration.importedModel {
                    let placeholder = ObjectFactory.makeObject(type: .cuboid)
                    anchor.addChild(placeholder)
                    objectEntities[configuration.id] = placeholder
                    objectSourceKeys[configuration.id] = sourceKey
                    loadImportedObject(
                        importedModel,
                        objectID: configuration.id,
                        sourceKey: sourceKey,
                        on: anchor
                    )
                } else {
                    let entity = ObjectFactory.makeObject(
                        type: configuration.type,
                        texture: viewModel.selectedTexture
                    )
                    anchor.addChild(entity)
                    objectEntities[configuration.id] = entity
                    objectSourceKeys[configuration.id] = sourceKey
                    viewModel.debugLog(
                        "Object synchronized: \(configuration.name) — \(configuration.type.rawValue)"
                    )
                }
            }

            guard let entity = objectEntities[configuration.id] else { continue }
            applyObjectTransform(to: entity, configuration: configuration)
            collisionManager.registerObstacle(
                id: configuration.id,
                position: obstaclePosition(for: configuration),
                radius: ObjectFactory.collisionRadius(for: configuration)
            )
        }

        lastTexture = viewModel.selectedTexture
    }

    private func loadImportedObject(
        _ importedModel: ImportedModelConfiguration,
        objectID: UUID,
        sourceKey: String,
        on anchor: AnchorEntity
    ) {
        objectLoadTasks[objectID] = Task { [weak self, weak anchor] in
            guard let self else { return }

            do {
                let loadedEntity = try await Entity(contentsOf: importedModel.fileURL)
                try Task.checkCancellation()
                guard let anchor,
                      self.objectSourceKeys[objectID] == sourceKey,
                      let configuration = self.viewModel.objects.first(where: { $0.id == objectID }),
                      configuration.importedModel?.fileURL == importedModel.fileURL else { return }

                let normalizedObject = try self.makeNormalizedImportedObject(
                    from: loadedEntity,
                    name: importedModel.displayName
                )
                self.objectEntities[objectID]?.removeFromParent()
                anchor.addChild(normalizedObject.entity)
                self.objectEntities[objectID] = normalizedObject.entity
                self.objectLoadTasks[objectID] = nil
                self.viewModel.updateImportedModelDimensions(
                    id: objectID,
                    dimensions: normalizedObject.dimensions
                )

                let updatedConfiguration = self.viewModel.objects.first(where: { $0.id == objectID })
                    ?? configuration
                self.applyObjectTransform(
                    to: normalizedObject.entity,
                    configuration: updatedConfiguration
                )
                self.collisionManager.registerObstacle(
                    id: objectID,
                    position: self.obstaclePosition(for: updatedConfiguration),
                    radius: ObjectFactory.collisionRadius(for: updatedConfiguration)
                )
                self.lastSceneSignature = nil
                self.viewModel.debugLog("Imported 3D model loaded: \(importedModel.displayName)")
            } catch is CancellationError {
                self.objectLoadTasks[objectID] = nil
            } catch {
                self.objectLoadTasks[objectID] = nil
                self.viewModel.reportModelLoadFailure(
                    named: importedModel.displayName,
                    error: error
                )
            }
        }
    }

    private func makeNormalizedImportedObject(
        from loadedEntity: Entity,
        name: String
    ) throws -> (entity: Entity, dimensions: SIMD3<Float>) {
        let normalizer = Entity()
        normalizer.addChild(loadedEntity)
        let bounds = normalizer.visualBounds(recursive: true, relativeTo: normalizer)
        let rawDimensions = bounds.extents
        let largestDimension = max(rawDimensions.x, rawDimensions.y, rawDimensions.z)

        guard largestDimension.isFinite, largestDimension > 0.0001 else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let normalizationScale = ImportedModelConfiguration.targetMaximumDimension / largestDimension
        let dimensions = SIMD3<Float>(
            max(rawDimensions.x * normalizationScale, 0.002),
            max(rawDimensions.y * normalizationScale, 0.002),
            max(rawDimensions.z * normalizationScale, 0.002)
        )
        normalizer.scale = SIMD3<Float>(repeating: normalizationScale)
        normalizer.position = -bounds.center * normalizationScale

        let container = Entity()
        container.name = name
        container.addChild(normalizer)
        container.components.set(
            CollisionComponent(shapes: [.generateBox(size: dimensions)])
        )
        enableDynamicShadows(on: loadedEntity)
        return (container, dimensions)
    }

    private func enableDynamicShadows(on entity: Entity) {
        if entity is ModelEntity {
            entity.components.set(DynamicLightShadowComponent(castsShadow: true))
        }
        for child in entity.children {
            enableDynamicShadows(on: child)
        }
    }

    private func objectSourceKey(for object: ObjectConfiguration) -> String {
        if let importedModel = object.importedModel {
            return "imported:\(importedModel.fileURL.path)"
        }
        return "primitive:\(object.type.rawValue)"
    }

    private func syncLights(on anchor: AnchorEntity) {
        let currentIDs = Set(viewModel.lights.map { $0.id })
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
                let lidarResolution = resolvedLiDARPosition(
                    from: entities.marker.position,
                    to: virtualResolution.position,
                    shape: .generateSphere(radius: Self.lidarLightRadius),
                    orientation: .init(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
                    relativeTo: anchor
                )
                light.position = lidarResolution.position

                if light.position != requestedLight.position {
                    viewModel.updateLightPosition(id: light.id, position: light.position)
                }

                if selected {
                    if lidarResolution.didCollide {
                        selectedCollisionWarning = "Light stopped by a scanned real-world surface."
                    } else if virtualResolution.didCollide {
                        selectedCollisionWarning = "Light stopped by another virtual object."
                    }
                }

                let effectiveLight = effectiveLightConfiguration(for: light)
                LightFactory.update(
                    light: entities.light,
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
        object: ObjectConfiguration,
        from currentGroundPosition: SIMD3<Float>,
        to candidateGroundPosition: SIMD3<Float>,
        relativeTo anchor: Entity
    ) -> (position: SIMD3<Float>, didCollide: Bool) {
        let dimensions = ObjectFactory.baseDimensions(for: object) * object.scale
        let height = dimensions.y
        let clearance = Self.lidarClearance
        let centerOffset = SIMD3<Float>(0, height / 2 + clearance, 0)
        let shape: ShapeResource

        if object.importedModel != nil {
            shape = .generateBox(size: SIMD3<Float>(
                max(dimensions.x - clearance * 2, 0.001),
                max(height - clearance * 2, 0.001),
                max(dimensions.z - clearance * 2, 0.001)
            ))
        } else if object.type == .sphere {
            shape = .generateSphere(radius: max(height / 2 - clearance, 0.001))
        } else {
            shape = .generateBox(size: SIMD3<Float>(
                max(dimensions.x - clearance * 2, 0.001),
                max(height - clearance * 2, 0.001),
                max(dimensions.z - clearance * 2, 0.001)
            ))
        }

        let orientation = simd_quatf(
            angle: object.yawDegrees.degreesToRadians,
            axis: SIMD3<Float>(0, 1, 0)
        )
        let resolution = resolvedLiDARPosition(
            from: currentGroundPosition + centerOffset,
            to: candidateGroundPosition + centerOffset,
            shape: shape,
            orientation: orientation,
            relativeTo: anchor,
            ignoringSupportBelow: clearance * 4
        )
        return (resolution.position - centerOffset, resolution.didCollide)
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
        guard objectEntities[viewModel.selectedObjectID] != nil else { return }
        let objectHeight = scaledObjectHeight
        let selectedLight = effectiveLightConfiguration(for: viewModel.selectedLight)
        projectionRenderer.update(
            objectType: viewModel.selectedObjectType,
            objectPosition: objectGroundPosition,
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
            objectPosition: objectGroundPosition,
            objectHeight: objectHeight,
            selectedLight: selectedLight
        )
    }

    private func updateShadowInfo() {
        guard objectEntities[viewModel.selectedObjectID] != nil else { return }
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
        viewModel.selectedObject.position
    }

    private func resetObjectPosition() {
        viewModel.updateSelectedObject { $0.position = .zero }
        let selectedObject = viewModel.selectedObject
        if let objectEntity = objectEntities[selectedObject.id] {
            applyObjectTransform(to: objectEntity, configuration: selectedObject)
            collisionManager.updatePosition(
                id: selectedObject.id,
                position: obstaclePosition(for: selectedObject)
            )
        }
        updateEducationalOverlays()
        updateShadowInfo()
        viewModel.debugLog("Object position reset")
    }


    private func resetScene() {
        for task in objectLoadTasks.values {
            task.cancel()
        }
        sceneAnchor?.removeFromParent()
        sceneAnchor = nil
        objectEntities.removeAll()
        objectSourceKeys.removeAll()
        objectLoadTasks.removeAll()
        lightEntities.removeAll()
        collisionManager.removeAll()
        receiverManager.reset()
        projectionRenderer.clear()
        annotationManager.clear()
        lastSceneSignature = nil
        lastTexture = nil
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

    private func currentSceneSignature() -> SceneUpdateSignature {
        SceneUpdateSignature(
            objects: viewModel.objects,
            selectedObjectID: viewModel.selectedObjectID,
            selectedTexture: viewModel.selectedTexture,
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

    private func selectObject(containing entity: Entity) -> Bool {
        for (id, object) in objectEntities {
            var candidate: Entity? = entity
            while let current = candidate {
                if current == object {
                    viewModel.selectedObjectID = id
                    viewModel.debugLog("Selected object changed")
                    return true
                }
                candidate = current.parent
            }
        }
        return false
    }

    private func applyObjectTransform(
        to object: Entity,
        configuration: ObjectConfiguration
    ) {
        let scaledHeight = ObjectFactory.objectHeight(for: configuration) * configuration.scale
        object.position = SIMD3<Float>(
            configuration.position.x,
            scaledHeight / 2,
            configuration.position.z
        )
        object.scale = SIMD3<Float>(repeating: configuration.scale)
        object.orientation = simd_quatf(
            angle: configuration.yawDegrees.degreesToRadians,
            axis: SIMD3<Float>(0, 1, 0)
        )
    }

    private var scaledObjectHeight: Float {
        let selectedObject = viewModel.selectedObject
        return ObjectFactory.objectHeight(for: selectedObject) * selectedObject.scale
    }

    private func obstaclePosition(for object: ObjectConfiguration) -> SIMD3<Float> {
        object.position + SIMD3<Float>(
            0,
            ObjectFactory.objectHeight(for: object) * object.scale / 2,
            0
        )
    }

    private func effectiveLightConfiguration(for light: LightConfiguration) -> LightConfiguration {
        guard light.type == .spot,
              let objectEntity = objectEntities[viewModel.selectedObjectID] else { return light }

        var adjusted = light
        let target = objectEntity.position + SIMD3<Float>(0, scaledObjectHeight * 0.15, 0)
        let delta = target - light.position
        let horizontalDistance = sqrt(delta.x * delta.x + delta.z * delta.z)
        guard horizontalDistance > 0.001 || abs(delta.y) > 0.001 else { return adjusted }

        adjusted.yawDegrees = atan2(delta.x, -delta.z).radiansToDegrees
        adjusted.pitchDegrees = atan2(delta.y, horizontalDistance).radiansToDegrees
        return adjusted
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        Task { @MainActor in
            if anchors.contains(where: { $0 is ARPlaneAnchor }),
               self.viewModel.surfaceState == .scanning {
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
