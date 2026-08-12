import ARKit
import RealityKit
import SwiftUI
import UIKit
import Combine
import QuartzCore

@MainActor
final class Level1ARCoordinator: NSObject, ARSessionDelegate, ARCoachingOverlayViewDelegate {

    private let viewModel: Level1ViewModel
    private weak var arView: ARView?
    private var coachingOverlay: ARCoachingOverlayView?

    // MARK: - Checkpoint configuration
    private static let pathRadius: Float = 3.2
    private static let childTargetHeight: Float = 1.30
    private static let markerRadius: Float = 1.0
    private static let markerOffsetFromShape: Float = 0
    private static let minimumScanDuration: Duration = .seconds(4)
    private static let checkpointMinimumSpacing: Float = 3.0
    private static let scatterStepRange: ClosedRange<Float> = 3.2...4.6
    private static let scatterMaxRadiusFromOrigin: Float = 7.0
    private static let scatterPlacementAttempts = 60
    private static let neonLabelColor = UIColor(red: 0.75, green: 1.0, blue: 0.15, alpha: 1.0)

    // MARK: - Checkpoint-reached feedback (haptic + flash)
    private static let checkpointFlashColor = UIColor(red: 0.75, green: 1.0, blue: 0.15, alpha: 1.0)
    private static let checkpointFlashDuration: TimeInterval = 0.22
    private static let checkpointFlashStartRadius: Float = 0.05
    private static let checkpointFlashEndScale: Float = 9

    // MARK: - 3D Waypoint Indicator
    private static let directionIndicatorForwardOffset: Float = 1.15
    private static let directionIndicatorHeightOffset: Float = -0.35
    private static let directionIndicatorMoveAmplitude: Float = 0.10
    private static let directionIndicatorMoveSpeed: Float = 2.4
    private static let directionIndicatorFloatAmplitude: Float = 0.015
    private static let directionIndicatorFloatSpeed: Float = 2.0
    private static let directionIndicatorPulseAmplitude: Float = 0.05
    private static let directionIndicatorPulseSpeed: Float = 2.8
    private static let directionIndicatorBlue = UIColor(red: 0.05, green: 0.40, blue: 1.0, alpha: 1.0)

    private var hasPlacedPath = false
    private var latestHorizontalPlaneAnchor: ARPlaneAnchor?
    private var pathCenterXZ: SIMD2<Float> = .zero
    private var pathAnchor: AnchorEntity?
    private var checkpointWorldPositions: [SIMD3<Float>] = []
    private var markerWorldPositions: [SIMD3<Float>] = []
    private var checkpointEntities: [ModelEntity] = []
    private var markerEntities: [ModelEntity] = []
    private var lastAppliedTextureID: [Int: String] = [:]
    private var lastArrivedIndex: Int?
    private var lastMarkerState: [Int: MarkerState] = [:]

    // MARK: - Direction indicator state
    private var directionIndicatorAnchor: AnchorEntity?
    private var directionIndicatorRoot: ModelEntity?
    private var directionIndicatorLabel: ModelEntity?
    private var lastIndicatorDistanceText: String?

    private var cancellables = Set<AnyCancellable>()
    private var automaticPlacementTask: Task<Void, Never>?
    private var pulseDisplayLink: CADisplayLink?

    /// Getar + kilatan cahaya singkat saat anak tiba di checkpoint. Generator
    /// disiapkan lebih awal (`.prepare()`) di `configure(arView:)` supaya
    /// getaran pertama tidak telat/lag saat benar-benar dipicu.
    private let checkpointHapticGenerator = UINotificationFeedbackGenerator()

    // MARK: - Lighting / collision
    private var pathLightBundle: RealityKitLightEntityBundle?
    private let collisionSystem = CollisionSystem()
    private let pathLightID = UUID()
    private var checkpointObstacleIDs: [String: UUID] = [:]
    private let shadowReceiverManager = ShadowReceiverManager()
    private let lidarMeshOcclusionManager = LiDARMeshOcclusionManager()
    private var usesSceneReconstruction = false

    private enum MarkerState: Equatable { case active, visited, upcoming }

    private func obstacleID(for checkpointID: String) -> UUID {
        if let existing = checkpointObstacleIDs[checkpointID] { return existing }
        let id = UUID(); checkpointObstacleIDs[checkpointID] = id
        return id
    }

    init(viewModel: Level1ViewModel) {
        self.viewModel = viewModel
        super.init()
    }

    func configure(arView: ARView) {
        self.arView = arView
        arView.session.delegate = self
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        addCoachingOverlay(to: arView)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            usesSceneReconstruction = true
            viewModel.arSceneViewModel.isLiDARAvailable = true
            viewModel.arSceneViewModel.resetLiDARScan()
        } else {
            usesSceneReconstruction = false
            viewModel.arSceneViewModel.isLiDARAvailable = false
        }

        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        setupDirectionIndicator(in: arView)
        observeViewModelChanges()
        startPulseAnimation()
        checkpointHapticGenerator.prepare()
    }

    deinit {
        automaticPlacementTask?.cancel()
        pulseDisplayLink?.invalidate()
    }

    private func addCoachingOverlay(to arView: ARView) {
        let overlay = ARCoachingOverlayView()
        overlay.session = arView.session
        overlay.goal = .horizontalPlane
        overlay.activatesAutomatically = false
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

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        if let arView { scheduleAutomaticPlacement(in: arView) }
    }

    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        automaticPlacementTask?.cancel(); automaticPlacementTask = nil
        hasPlacedPath = false; latestHorizontalPlaneAnchor = nil
        arView?.scene.anchors.removeAll(); pathAnchor = nil
        checkpointEntities.removeAll(); markerEntities.removeAll()
        checkpointWorldPositions.removeAll(); markerWorldPositions.removeAll()
        lastMarkerState.removeAll(); lastAppliedTextureID.removeAll()
        pathLightBundle = nil
        collisionSystem.removeAll(); checkpointObstacleIDs.removeAll()
        shadowReceiverManager.reset(); lidarMeshOcclusionManager.reset()
        viewModel.arSceneViewModel.resetLiDARScan(); viewModel.clearWaypoint()
        directionIndicatorRoot?.isEnabled = false
        directionIndicatorLabel?.removeFromParent(); directionIndicatorLabel = nil
        lastIndicatorDistanceText = nil
    }

    private func observeViewModelChanges() {
        viewModel.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.syncActiveCheckpointMaterial()
                self?.syncMarkerStates()
                self?.syncCheckpointVisibility()
                self?.syncDirectionIndicatorVisibility()
            }
        }.store(in: &cancellables)

        viewModel.$phase.receive(on: DispatchQueue.main).sink { [weak self] phase in
            guard let self = self, let arView = self.arView else { return }
            if phase == .scanningSurface {
                self.latestHorizontalPlaneAnchor = nil
                if let config = arView.session.configuration {
                    arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
                }
                self.coachingOverlay?.setActive(true, animated: true)
                self.scheduleAutomaticPlacement(in: arView)
            } else if phase == .exploring {
                self.automaticPlacementTask?.cancel(); self.automaticPlacementTask = nil
                self.coachingOverlay?.setActive(false, animated: true)
                if !self.hasPlacedPath {
                    print("🛠 Menggunakan jalur pintas Debug: Menaruh objek paksa!")
                    let camPos = arView.cameraTransform.matrix.columns.3
                    self.placeCheckpointCircle(floorY: camPos.y - 1.2, originXZ: SIMD2<Float>(camPos.x, camPos.z), in: arView)
                }
            } else if phase != .exploring && phase != .returningToStart {
                self.viewModel.clearWaypoint()
            }
        }.store(in: &cancellables)
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        trackLatestHorizontalPlane(from: anchors); updateLiDARMeshOcclusion(from: anchors)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        trackLatestHorizontalPlane(from: anchors); updateLiDARMeshOcclusion(from: anchors)
    }

    private func scheduleAutomaticPlacement(in arView: ARView) {
        guard automaticPlacementTask == nil else { return }
        automaticPlacementTask = Task { [weak self, weak arView] in
            try? await Task.sleep(for: Self.minimumScanDuration)
            guard !Task.isCancelled, let self, let arView else { return }
            await MainActor.run {
                guard self.viewModel.phase == .scanningSurface else { return }
                self.placePathIfNeeded(in: arView, allowsFallback: true)
            }
        }
    }

    private func placePathIfNeeded(in arView: ARView, allowsFallback: Bool) {
        guard !hasPlacedPath else { return }
        let planeAnchor = latestHorizontalPlaneAnchor ?? arView.session.currentFrame?.anchors.compactMap { $0 as? ARPlaneAnchor }.first { $0.alignment == .horizontal }
        
        if let validPlane = planeAnchor {
            placeCheckpointCircle(fromPlane: validPlane, in: arView)
        } else if allowsFallback {
            print("⚠️ Peringatan: ARKit belum menemukan anchor lantai. Menggunakan fallback otomatis.")
            let camPos = arView.cameraTransform.matrix.columns.3
            placeCheckpointCircle(floorY: camPos.y - 1.2, originXZ: SIMD2<Float>(camPos.x, camPos.z), in: arView)
        } else { return }
        
        automaticPlacementTask?.cancel(); automaticPlacementTask = nil
        coachingOverlay?.setActive(false, animated: true)
        viewModel.finishScanning()
    }

    private func trackLatestHorizontalPlane(from anchors: [ARAnchor]) {
        guard !hasPlacedPath else { return }
        if let planeAnchor = anchors.compactMap({ $0 as? ARPlaneAnchor }).filter({ $0.alignment == .horizontal }).max(by: { planeArea($0) < planeArea($1) }) {
            if let existing = latestHorizontalPlaneAnchor {
                if planeArea(planeAnchor) > planeArea(existing) { latestHorizontalPlaneAnchor = planeAnchor }
            } else {
                latestHorizontalPlaneAnchor = planeAnchor
            }
        }
    }

    private func planeArea(_ planeAnchor: ARPlaneAnchor) -> Float {
        return planeAnchor.planeExtent.width * planeAnchor.planeExtent.height
    }

    private func updateLiDARMeshOcclusion(from anchors: [ARAnchor]) {
        guard usesSceneReconstruction, let arView else { return }
        let result = lidarMeshOcclusionManager.update(from: anchors, in: arView)
        if result.updatedCount > 0 { viewModel.arSceneViewModel.updateLiDARScan(meshCount: result.meshCount, faceCount: result.faceCount) }
    }

    private func placeCheckpointCircle(fromPlane planeAnchor: ARPlaneAnchor, in arView: ARView) {
        let planeCenter = planeAnchor.transform * SIMD4<Float>(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z, 1)
        placeCheckpointCircle(floorY: planeCenter.y, originXZ: SIMD2<Float>(planeCenter.x, planeCenter.z), in: arView)
    }

    private func placeCheckpointCircle(floorY: Float, originXZ: SIMD2<Float>, in arView: ARView) {
        hasPlacedPath = true
        let forwardXZ = horizontalForward(of: arView.cameraTransform.matrix)
        let shapePositionsXZ = makeCheckpointShapePositions(originXZ: originXZ, forwardXZ: forwardXZ, count: viewModel.checkpoints.count)
        pathCenterXZ = averagePosition(shapePositionsXZ)
        
        checkpointWorldPositions.removeAll(); markerWorldPositions.removeAll()
        checkpointEntities.removeAll(); markerEntities.removeAll(); collisionSystem.removeAll()

        let anchor = AnchorEntity(world: translationMatrix(SIMD3<Float>(pathCenterXZ.x, floorY, pathCenterXZ.y)))
        arView.scene.addAnchor(anchor)
        pathAnchor = anchor
        shadowReceiverManager.setupReceiver(on: anchor, usesFlatFallback: true, surfaceTexture: .defaultGrid)
        lidarMeshOcclusionManager.setVisualizationEnabled(false)
        viewModel.arSceneViewModel.isObjectPlaced = true

        for (index, checkpoint) in viewModel.checkpoints.enumerated() {
            let shapeXZ = shapePositionsXZ[index]
            let shapeWorldPosition = SIMD3<Float>(shapeXZ.x, floorY, shapeXZ.y)
            checkpointWorldPositions.append(shapeWorldPosition)

            let shapeLocalPosition = SIMD3<Float>(shapeXZ.x - pathCenterXZ.x, 0, shapeXZ.y - pathCenterXZ.y)
            let markerXZ = shapeXZ + forwardXZ * Self.markerOffsetFromShape
            let markerWorldPosition = SIMD3<Float>(markerXZ.x, floorY + 0.005, markerXZ.y)
            markerWorldPositions.append(markerWorldPosition)

            let markerLocalPosition = SIMD3<Float>(markerXZ.x - pathCenterXZ.x, 0.005, markerXZ.y - pathCenterXZ.y)
            let shapeEntity = makeCheckpointEntity(for: checkpoint, worldPosition: shapeWorldPosition)
            shapeEntity.position += shapeLocalPosition
            checkpointEntities.append(shapeEntity)
            anchor.addChild(shapeEntity)

            let markerEntity = makeMarkerEntity()
            markerEntity.position = markerLocalPosition
            markerEntities.append(markerEntity)
            anchor.addChild(markerEntity)

            collisionSystem.registerObstacle(id: obstacleID(for: checkpoint.id), position: shapeWorldPosition, radius: Self.childTargetHeight / 2)
        }

        placePathLight(anchor: anchor, floorY: floorY)
        syncMarkerStates()
        syncCheckpointVisibility()
    }

    private func makeCheckpointShapePositions(originXZ: SIMD2<Float>, forwardXZ: SIMD2<Float>, count: Int) -> [SIMD2<Float>] {
        guard count > 0 else { return [] }
        guard count > 1 else { return [originXZ] }
        var selected: [SIMD2<Float>] = [originXZ]
        for _ in 1..<count {
            if let next = randomScatterPoint(from: selected.last!, avoiding: selected, originXZ: originXZ) { selected.append(next) } else { break }
        }
        if selected.count == count { return selected }

        let centerXZ = originXZ + forwardXZ * Self.pathRadius
        let angleToStart = atan2(originXZ.y - centerXZ.y, originXZ.x - centerXZ.x)
        let angleStep = (2 * Float.pi) / Float(count)
        return (0..<count).map { centerXZ + SIMD2<Float>(cos(angleToStart + angleStep * Float($0)), sin(angleToStart + angleStep * Float($0))) * Self.pathRadius }
    }

    private func randomScatterPoint(from anchor: SIMD2<Float>, avoiding existing: [SIMD2<Float>], originXZ: SIMD2<Float>) -> SIMD2<Float>? {
        for _ in 0..<Self.scatterPlacementAttempts {
            let angle = Float.random(in: 0..<(2 * Float.pi))
            let distance = Float.random(in: Self.scatterStepRange)
            let candidate = anchor + SIMD2<Float>(cos(angle), sin(angle)) * distance
            let isClear = existing.allSatisfy { simd_distance(candidate, $0) >= Self.checkpointMinimumSpacing }
            let isWithinRoom = simd_distance(candidate, originXZ) <= Self.scatterMaxRadiusFromOrigin
            if isClear && isWithinRoom { return candidate }
        }
        return nil
    }

    private func averagePosition(_ positions: [SIMD2<Float>]) -> SIMD2<Float> {
        guard !positions.isEmpty else { return .zero }
        return positions.reduce(SIMD2<Float>.zero, +) / Float(positions.count)
    }

    private func placePathLight(anchor: AnchorEntity, floorY: Float) {
        let lightHeight: Float = 1.4
        let defaults = LightConfiguration.defaultLight()
        let config = LightConfiguration(id: pathLightID, name: "Level 1 Path Light", type: defaults.type, color: defaults.color, intensity: defaults.intensity, position: SIMD3<Float>(0, lightHeight, 0), yawDegrees: 0, pitchDegrees: -70, beamSpread: .spread)
        let bundle = SceneLightEntityFactory.makeLight(configuration: config, selected: false)
        anchor.addChild(bundle.root)
        pathLightBundle = bundle
        collisionSystem.registerObstacle(id: pathLightID, position: SIMD3<Float>(anchor.position.x, floorY + lightHeight, anchor.position.z), radius: SceneLightSystem.lightObstacleRadius)
    }

    private func makeCheckpointEntity(for checkpoint: Checkpoint, worldPosition: SIMD3<Float>) -> ModelEntity {
        let texture = checkpoint.shape.textures[0].material
        // `doubleSided: true` supaya begitu anak jalan menembus objek, mereka
        // tetap melihat sisi dalam mesh alih-alih objek jadi tembus pandang.
        let entity = SceneObjectEntityFactory.makeObject(type: checkpoint.shape.objectType, texture: texture, doubleSided: true)
        let naturalHeight = SceneObjectEntityFactory.objectHeight(for: checkpoint.shape.objectType)
        let scale = Self.childTargetHeight / naturalHeight
        entity.scale = SIMD3<Float>(repeating: scale)
        entity.position.y = (naturalHeight * scale) / 2
        entity.addChild(makeLabel(text: checkpoint.shape.displayName, aboveHeight: naturalHeight * scale))
        lastAppliedTextureID[checkpoint.order] = checkpoint.shape.textures[0].id
        return entity
    }

    private func makeLabel(text: String, aboveHeight: Float) -> ModelEntity {
        let mesh = MeshResource.generateText(text, extrusionDepth: 0.004, font: .boldSystemFont(ofSize: 0.12), containerFrame: .zero, alignment: .center, lineBreakMode: .byTruncatingTail)
        let label = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: Self.neonLabelColor)])
        label.scale = SIMD3<Float>(repeating: 0.5)
        label.components.set(BillboardComponent())
        label.position = SIMD3<Float>(-mesh.bounds.extents.x * 0.25, aboveHeight + 0.2, 0)
        label.addChild(makeLabelGlow(textBounds: mesh.bounds))
        return label
    }

    private func makeLabelGlow(textBounds: BoundingBox) -> ModelEntity {
        let width = max(textBounds.extents.x + 0.09, 0.05); let height = max(textBounds.extents.y + 0.07, 0.05)
        var material = UnlitMaterial(color: Self.neonLabelColor.withAlphaComponent(0.35))
        material.blending = .transparent(opacity: 0.35)
        let glow = ModelEntity(mesh: MeshResource.generatePlane(width: width, height: height), materials: [material])
        glow.position = SIMD3<Float>(textBounds.center.x, textBounds.center.y, textBounds.center.z - 0.01)
        return glow
    }

    private func makeMarkerEntity() -> ModelEntity {
        var material = UnlitMaterial(color: .systemBlue.withAlphaComponent(0.55))
        material.blending = .transparent(opacity: 0.55)
        let entity = ModelEntity(mesh: MeshResource.generateSphere(radius: Self.markerRadius), materials: [material])
        entity.scale = SIMD3<Float>(1, 0.04, 1)
        return entity
    }

    // MARK: - 3D Direction Indicator
    private func setupDirectionIndicator(in arView: ARView) {
        let anchor = AnchorEntity(world: matrix_identity_float4x4)
        arView.scene.addAnchor(anchor)
        directionIndicatorAnchor = anchor

        let root = ModelEntity(); root.isEnabled = false
        
        let mesh = MeshResource.generateText("➔", extrusionDepth: 0.04, font: .systemFont(ofSize: 0.35, weight: .black))
        let arrowMat = SimpleMaterial(color: Self.directionIndicatorBlue, roughness: 0.2, isMetallic: false)
        let arrowEntity = ModelEntity(mesh: mesh, materials: [arrowMat])
        
        arrowEntity.position = SIMD3<Float>(-mesh.bounds.center.x, -mesh.bounds.center.y, -mesh.bounds.center.z)
        let pivot = Entity()
        pivot.addChild(arrowEntity)
        pivot.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0]) * simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        
        root.addChild(pivot)
        anchor.addChild(root)
        directionIndicatorRoot = root
    }

    // UPDATED: Menggunakan Look(at:) dan targetPosition langsung alih-alih manual Yaw
    private func updateDirectionIndicator(cameraTransform: simd_float4x4, cameraPosition: SIMD3<Float>, targetPosition: SIMD3<Float>, distanceMeters: Double) {
        guard let root = directionIndicatorRoot else { return }
        root.isEnabled = true
        
        let forward3D = -SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
        let horizontalForward3D = SIMD3<Float>(forward3D.x, 0, forward3D.z)
        let forwardLength = simd_length(horizontalForward3D)
        guard forwardLength > 0.0001 else { return }
        
        let normalizedForward = horizontalForward3D / forwardLength
        let time = Float(CACurrentMediaTime())
        let forwardBackward = sin(time * Self.directionIndicatorMoveSpeed) * Self.directionIndicatorMoveAmplitude
        let verticalFloat = sin(time * Self.directionIndicatorFloatSpeed) * Self.directionIndicatorFloatAmplitude
        
        let position = cameraPosition + normalizedForward * (Self.directionIndicatorForwardOffset + forwardBackward) + SIMD3<Float>(0, Self.directionIndicatorHeightOffset + verticalFloat, 0)
        
        // Target langsung ke titik yang dituju secara presisi di level mata yang sejajar (XZ Plane)
        let targetXZ = SIMD3<Float>(targetPosition.x, position.y, targetPosition.z)
        root.look(at: targetXZ, from: position, relativeTo: nil)

        let pulse = 1 + Self.directionIndicatorPulseAmplitude * sin(time * Self.directionIndicatorPulseSpeed)
        root.scale = SIMD3<Float>(repeating: pulse)
        updateIndicatorDistanceLabel(meters: distanceMeters, parent: root)
    }

    private func updateIndicatorDistanceLabel(meters: Double, parent: ModelEntity) {
        let text = meters < 1 ? "Sudah dekat!" : String(format: "%.1f m", meters)
        guard text != lastIndicatorDistanceText else { return }
        lastIndicatorDistanceText = text
        directionIndicatorLabel?.removeFromParent()
        
        let mesh = MeshResource.generateText(text, extrusionDepth: 0.002, font: .boldSystemFont(ofSize: 0.05), containerFrame: .zero, alignment: .center, lineBreakMode: .byTruncatingTail)
        let label = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
        label.components.set(BillboardComponent())
        label.position = SIMD3<Float>(-mesh.bounds.center.x - mesh.bounds.extents.x / 2, 0.18, 0)
        parent.addChild(label)
        directionIndicatorLabel = label
    }

    private func syncDirectionIndicatorVisibility() {
        guard let root = directionIndicatorRoot else { return }
        let shouldShow = viewModel.hasWaypointTarget
        root.isEnabled = shouldShow
        if !shouldShow { directionIndicatorLabel?.removeFromParent(); directionIndicatorLabel = nil; lastIndicatorDistanceText = nil }
    }

    private func syncActiveCheckpointMaterial() {
        let activeIndex = viewModel.currentCheckpointIndex
        guard checkpointEntities.indices.contains(activeIndex), viewModel.hasArrivedAtCurrentCheckpoint else { return }
        let texture = viewModel.currentTexture
        guard lastAppliedTextureID[activeIndex] != texture.id else { return }
        lastAppliedTextureID[activeIndex] = texture.id
        checkpointEntities[activeIndex].model?.materials = [texture.material.makeMaterial(doubleSided: true)]
    }

    private func syncCheckpointVisibility() {
        guard !checkpointEntities.isEmpty else { return }
        let targetIndex = viewModel.nextTargetCheckpointIndex
        for index in checkpointEntities.indices { checkpointEntities[index].isEnabled = targetIndex != nil ? index <= targetIndex! : true }
    }

    private func syncMarkerStates() {
        guard !markerEntities.isEmpty else { return }
        let targetIndex = viewModel.nextTargetCheckpointIndex
        for index in markerEntities.indices {
            let state: MarkerState = targetIndex == index ? .active : (targetIndex == nil || index < targetIndex! ? .visited : .upcoming)
            guard lastMarkerState[index] != state else { continue }
            lastMarkerState[index] = state
            applyMarkerAppearance(state, to: markerEntities[index])
        }
    }

    private func applyMarkerAppearance(_ state: MarkerState, to entity: ModelEntity) {
        switch state {
        case .active:
            entity.isEnabled = true
            var mat = UnlitMaterial(color: .systemBlue.withAlphaComponent(0.65)); mat.blending = .transparent(opacity: 0.65)
            entity.model?.materials = [mat]
        case .upcoming:
            entity.isEnabled = true
            var mat = UnlitMaterial(color: .systemGray.withAlphaComponent(0.25)); mat.blending = .transparent(opacity: 0.25)
            entity.model?.materials = [mat]
        case .visited:
            entity.isEnabled = false
        }
    }

    private func startPulseAnimation() {
        let link = CADisplayLink(target: self, selector: #selector(handlePulseTick))
        link.add(to: .main, forMode: .common)
        pulseDisplayLink = link
    }

    @objc private func handlePulseTick(_ link: CADisplayLink) {
        guard let targetIndex = viewModel.nextTargetCheckpointIndex, markerEntities.indices.contains(targetIndex) else { return }
        let pulse = 1 + 0.12 * sin(Float(link.timestamp) * 4)
        markerEntities[targetIndex].scale = SIMD3<Float>(pulse, 0.04, pulse)
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard !markerWorldPositions.isEmpty else { return }
        let camTrans = frame.camera.transform
        let camPos = SIMD3<Float>(camTrans.columns.3.x, camTrans.columns.3.y, camTrans.columns.3.z)
        let candidateIndex = viewModel.phase == .exploring ? viewModel.nextTargetCheckpointIndex : (viewModel.phase == .returningToStart ? 0 : nil)
        
        guard let index = candidateIndex, markerWorldPositions.indices.contains(index) else { return }
        updateWaypoint(cameraTransform: camTrans, cameraPosition: camPos, targetPosition: markerWorldPositions[index])
        
        if horizontalDistance(camPos, markerWorldPositions[index]) < Self.markerRadius {
            guard lastArrivedIndex != index else { return }
            lastArrivedIndex = index
            triggerCheckpointReachedFeedback(at: markerWorldPositions[index])
            viewModel.arrive(atCheckpointIndex: index)
        } else if lastArrivedIndex == index { lastArrivedIndex = nil }
    }

    /// Dipanggil sekali persis saat anak tiba di sebuah checkpoint (lihat
    /// `session(_:didUpdate:)` di atas). Dua hal terjadi bersamaan:
    /// 1. Device bergetar (haptic) sebagai konfirmasi fisik "checkpoint kena".
    /// 2. Kilatan cahaya neon muncul sekilas (~0.22s) di posisi marker lalu
    ///    hilang lagi — bukan animasi opacity manual, cukup sebuah sphere unlit
    ///    kecil yang membesar cepat lalu dibuang dari scene, jadi ringan untuk
    ///    tiap frame.
    private func triggerCheckpointReachedFeedback(at worldPosition: SIMD3<Float>) {
        checkpointHapticGenerator.notificationOccurred(.success)
        checkpointHapticGenerator.prepare() // siap-siap untuk checkpoint berikutnya

        guard let arView else { return }

        var material = UnlitMaterial(color: Self.checkpointFlashColor)
        material.blending = .transparent(opacity: 0.9)
        let flash = ModelEntity(mesh: .generateSphere(radius: Self.checkpointFlashStartRadius), materials: [material])

        let flashAnchor = AnchorEntity(world: translationMatrix(worldPosition + SIMD3<Float>(0, Self.childTargetHeight / 2, 0)))
        flashAnchor.addChild(flash)
        arView.scene.addAnchor(flashAnchor)

        var expanded = flash.transform
        expanded.scale = SIMD3<Float>(repeating: Self.checkpointFlashEndScale)
        flash.move(to: expanded, relativeTo: flash.parent, duration: Self.checkpointFlashDuration, timingFunction: .easeOut)

        Task { [weak flashAnchor] in
            try? await Task.sleep(for: .seconds(Self.checkpointFlashDuration))
            flashAnchor?.removeFromParent()
        }
    }

    // UPDATED: Langsung mengirimkan targetPosition ke updateDirectionIndicator
    private func updateWaypoint(cameraTransform: simd_float4x4, cameraPosition: SIMD3<Float>, targetPosition: SIMD3<Float>) {
        let forward = horizontalForward(of: cameraTransform)
        let toTarget = SIMD2<Float>(targetPosition.x - cameraPosition.x, targetPosition.z - cameraPosition.z)
        let toTargetLength = simd_length(toTarget)
        guard toTargetLength > 0.01 else { return }
        
        let toTargetNorm = toTarget / toTargetLength
        let dot = forward.x * toTargetNorm.x + forward.y * toTargetNorm.y
        let cross = forward.x * toTargetNorm.y - forward.y * toTargetNorm.x
        let angleDegrees = Double(atan2(cross, dot) * 180 / .pi)
        
        viewModel.updateWaypoint(bearingDegrees: angleDegrees, distanceMeters: Double(toTargetLength))
        updateDirectionIndicator(cameraTransform: cameraTransform, cameraPosition: cameraPosition, targetPosition: targetPosition, distanceMeters: Double(toTargetLength))
    }

    private func horizontalDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let dx = a.x - b.x; let dz = a.z - b.z; return sqrt(dx * dx + dz * dz)
    }

    private func horizontalForward(of transform: simd_float4x4) -> SIMD2<Float> {
        let forward = -SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        let flat = SIMD2<Float>(forward.x, forward.z)
        let length = simd_length(flat)
        return length > 0.0001 ? flat / length : SIMD2<Float>(0, -1)
    }

    private func translationMatrix(_ position: SIMD3<Float>) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4<Float>(position.x, position.y, position.z, 1)
        return matrix
    }
}
