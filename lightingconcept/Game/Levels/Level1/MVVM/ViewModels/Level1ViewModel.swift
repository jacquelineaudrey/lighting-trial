//
//  Level1ViewModel.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//
import Foundation
import Combine
import RealityKit
import UIKit
import ARKit // FIX: Required for ARAnchor and ARPlaneAnchor

enum Level1Phase: Equatable {
    case onboarding
    case scanningSurface
    case exploring
    case quiz
    case returningToStart
    case completed
}

@MainActor
final class Level1ViewModel: ObservableObject {

    let checkpoints = Level1Content.checkpoints
    let onboardingDialog = Level1Content.onboardingDialog
    let quizQuestions = Level1Content.quiz

    @Published private(set) var phase: Level1Phase = .onboarding
    @Published private(set) var onboardingIndex = 0
    @Published private(set) var currentCheckpointIndex = 0
    @Published private(set) var currentTextureIndex = 0
    @Published private(set) var quizIndex = 0
    @Published private(set) var quizScore = 0
    @Published var lastAnswerWasCorrect: Bool?
    
    @Published private(set) var waypointBearingDegrees: Double = 0
    @Published private(set) var waypointDistanceMeters: Double = 0
    @Published private(set) var hasWaypointTarget = false

    private var visitedTextures: [Int: Set<Int>] = [:]
    private let progressStore = GameProgressStore.shared
    let arSceneViewModel = ARSceneViewModel()

    // AR State
    private weak var rootAnchor: AnchorEntity?
    private var pathAnchor: AnchorEntity?
    private var hasPlacedPath = false
    
    // FIX: Re-added missing variable for ARKit plane tracking
    private var latestHorizontalPlaneAnchor: ARPlaneAnchor?
    
    private var checkpointWorldPositions: [SIMD3<Float>] = []
    private var markerWorldPositions: [SIMD3<Float>] = []
    private var checkpointEntities: [ModelEntity] = []
    private var markerEntities: [ModelEntity] = []
    private var directionIndicatorRoot: ModelEntity?
    private var lastArrivedIndex: Int?
    
    private let hapticGenerator = UINotificationFeedbackGenerator()
    
    // Config
    private let pathRadius: Float = 3.2
    private let childTargetHeight: Float = 1.30
    private let markerRadius: Float = 1.0

    init() {
        hapticGenerator.prepare()
    }

    // MARK: - Scene Setup & Placement
    
    func setupLevel(in anchor: AnchorEntity) {
        self.rootAnchor = anchor
        setupDirectionIndicator()
    }
    
    // MARK: - ARKit Plane Tracking
    
    func trackLatestHorizontalPlane(_ anchor: ARAnchor) {
        guard !hasPlacedPath, let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .horizontal else { return }
        
        if let existing = latestHorizontalPlaneAnchor {
            if planeArea(planeAnchor) > planeArea(existing) {
                latestHorizontalPlaneAnchor = planeAnchor
            }
        } else {
            latestHorizontalPlaneAnchor = planeAnchor
        }
        
        if let bestPlane = latestHorizontalPlaneAnchor, planeArea(bestPlane) > 1.0 {
            placePathIfNeeded()
        }
    }
    
    private func planeArea(_ planeAnchor: ARPlaneAnchor) -> Float {
        return planeAnchor.planeExtent.width * planeAnchor.planeExtent.height
    }
    
    // MARK: - ECS Scene Loop & Proximity Check
    
    func processSceneUpdate(_ scene: RealityKit.Scene) {
        guard phase == .exploring || phase == .returningToStart else { return }
        
        let cameraQuery = EntityQuery(where: .has(PerspectiveCameraComponent.self))
        var activeCamera: Entity?
        for entity in scene.performQuery(cameraQuery) {
            activeCamera = entity
            break
        }
        
        guard let camera = activeCamera else { return }
        let camTrans = camera.transformMatrix(relativeTo: nil)
        let camPos = SIMD3<Float>(camTrans.columns.3.x, camTrans.columns.3.y, camTrans.columns.3.z)
        
        checkProximity(cameraPosition: camPos)
    }
    
    // FIX: Re-added missing proximity checking logic
    private func checkProximity(cameraPosition: SIMD3<Float>) {
        guard let targetIndex = nextTargetCheckpointIndex,
              markerWorldPositions.indices.contains(targetIndex) else { return }
        
        let targetPos = markerWorldPositions[targetIndex]
        let dx = cameraPosition.x - targetPos.x
        let dz = cameraPosition.z - targetPos.z
        let distance = sqrt(dx * dx + dz * dz)
        
        if distance < markerRadius {
            guard lastArrivedIndex != targetIndex else { return }
            lastArrivedIndex = targetIndex
            
            triggerCheckpointReachedFeedback(at: targetPos)
            arrive(atCheckpointIndex: targetIndex)
        } else if lastArrivedIndex == targetIndex {
            lastArrivedIndex = nil
        }
    }
    
    // FIX: Re-added missing haptic feedback logic
    private func triggerCheckpointReachedFeedback(at worldPosition: SIMD3<Float>) {
        hapticGenerator.notificationOccurred(.success)
        hapticGenerator.prepare()
        
        guard let root = rootAnchor else { return }
        
        var material = UnlitMaterial(color: UIColor(red: 0.75, green: 1.0, blue: 0.15, alpha: 1.0))
        material.blending = .transparent(opacity: 0.9)
        let flash = ModelEntity(mesh: .generateSphere(radius: 0.05), materials: [material])
        
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4<Float>(worldPosition.x, worldPosition.y + childTargetHeight / 2, worldPosition.z, 1)
        let flashAnchor = AnchorEntity(world: matrix)
        flashAnchor.addChild(flash)
        root.addChild(flashAnchor)
        
        var expanded = flash.transform
        expanded.scale = SIMD3<Float>(repeating: 9)
        flash.move(to: expanded, relativeTo: flash.parent, duration: 0.22, timingFunction: .easeOut)
        
        Task {
            try? await Task.sleep(for: .seconds(0.22))
            flashAnchor.removeFromParent()
        }
    }
    
    func placePathIfNeeded() {
        guard !hasPlacedPath, let root = rootAnchor else { return }
        hasPlacedPath = true
        
        let count = checkpoints.isEmpty ? 1 : checkpoints.count
        let originXZ = SIMD2<Float>.zero
        let forwardXZ = SIMD2<Float>(0, -1)
        let floorY: Float = latestHorizontalPlaneAnchor?.transform.columns.3.y ?? -1.2
        
        let shapePositionsXZ = (0..<count).map { i -> SIMD2<Float> in
            let centerXZ = originXZ + forwardXZ * pathRadius
            let angleStep = (2 * Float.pi) / Float(count)
            let angle = Float.pi / 2 + angleStep * Float(i)
            return centerXZ + SIMD2<Float>(cos(angle), sin(angle)) * pathRadius
        }
        
        let pathCenterXZ = shapePositionsXZ.reduce(SIMD2<Float>.zero, +) / Float(count)
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4<Float>(pathCenterXZ.x, floorY, pathCenterXZ.y, 1)
        let anchorGroup = AnchorEntity(world: matrix)
        
        root.addChild(anchorGroup)
        pathAnchor = anchorGroup
        
        for (index, checkpoint) in checkpoints.enumerated() {
            let shapeXZ = shapePositionsXZ[index]
            let shapeWorldPosition = SIMD3<Float>(shapeXZ.x, floorY, shapeXZ.y)
            checkpointWorldPositions.append(shapeWorldPosition)
            
            let markerXZ = shapeXZ
            let markerWorldPosition = SIMD3<Float>(markerXZ.x, floorY + 0.005, markerXZ.y)
            markerWorldPositions.append(markerWorldPosition)
            
            let markerLocalPosition = SIMD3<Float>(markerXZ.x - pathCenterXZ.x, 0.005, markerXZ.y - pathCenterXZ.y)
            let markerEntity = makeMarkerEntity()
            markerEntity.position = markerLocalPosition
            
            markerEntity.components.set(PulseAnimationComponent())
            markerEntities.append(markerEntity)
            anchorGroup.addChild(markerEntity)
            
            let shapeLocalPosition = SIMD3<Float>(shapeXZ.x - pathCenterXZ.x, 0, shapeXZ.y - pathCenterXZ.y)
            let shapeEntity = makeCheckpointEntity(for: checkpoint)
            shapeEntity.position += shapeLocalPosition
            checkpointEntities.append(shapeEntity)
            anchorGroup.addChild(shapeEntity)
        }
        
        phase = .exploring
        syncEntities()
    }

    // MARK: - Dialog & Logic
    
    var currentDialogLine: DialogLine { onboardingDialog[onboardingIndex] }
    var isLastDialogLine: Bool { onboardingIndex == onboardingDialog.count - 1 }

    func advanceDialog() {
        guard phase == .onboarding else { return }
        if isLastDialogLine {
            phase = .scanningSurface
        } else {
            onboardingIndex += 1
        }
    }

    var currentCheckpoint: Checkpoint { checkpoints[currentCheckpointIndex] }
    var currentTexture: TextureStop { currentCheckpoint.shape.textures[currentTextureIndex] }
    var canGoToPreviousTexture: Bool { currentTextureIndex > 0 }
    var canGoToNextTexture: Bool { currentTextureIndex < currentCheckpoint.shape.textures.count - 1 }

    func nextTexture() {
        guard phase == .exploring, canGoToNextTexture else { return }
        currentTextureIndex += 1
        markTextureVisited()
        syncEntities()
    }

    func previousTexture() {
        guard phase == .exploring, canGoToPreviousTexture else { return }
        currentTextureIndex -= 1
        markTextureVisited()
        syncEntities()
    }

    private func markTextureVisited() {
        visitedTextures[currentCheckpointIndex, default: []].insert(currentTextureIndex)
    }

    var hasExploredAllCheckpoints: Bool {
        checkpoints.indices.allSatisfy { index in
            (visitedTextures[index]?.count ?? 0) >= checkpoints[index].shape.textures.count
        }
    }

    var hasArrivedAtCurrentCheckpoint: Bool { visitedTextures[currentCheckpointIndex] != nil }

    var nextTargetCheckpointIndex: Int? {
        guard phase == .exploring || phase == .returningToStart else { return nil }
        return phase == .returningToStart ? 0 : checkpoints.indices.first { visitedTextures[$0] == nil }
    }

    func arrive(atCheckpointIndex index: Int) {
        guard checkpoints.indices.contains(index) else { return }
        if phase == .exploring {
            currentCheckpointIndex = index
            currentTextureIndex = 0
            markTextureVisited()
        } else if phase == .returningToStart, index == 0 {
            phase = .completed
            progressStore.markLevelCompleted(Level1Content.levelID)
        }
        syncEntities()
    }

    func startQuiz() {
        guard phase == .exploring, hasExploredAllCheckpoints else { return }
        phase = .quiz
        quizIndex = 0
        quizScore = 0
        lastAnswerWasCorrect = nil
    }

    var currentQuestion: TriviaQuestion { quizQuestions[quizIndex] }

    @discardableResult
    func answer(with shape: GameShape) -> Bool {
        guard phase == .quiz, lastAnswerWasCorrect == nil else { return false }
        let isCorrect = shape.id == currentQuestion.correctShapeID
        lastAnswerWasCorrect = isCorrect
        if isCorrect { quizScore += 1 }
        return isCorrect
    }

    func nextQuestion() {
        guard phase == .quiz else { return }
        lastAnswerWasCorrect = nil
        if quizIndex == quizQuestions.count - 1 {
            phase = .returningToStart
            hasWaypointTarget = true
            syncEntities()
        } else {
            quizIndex += 1
        }
    }

    // MARK: - State Sync to ECS
    
    func syncEntities() {
        for (index, entity) in markerEntities.enumerated() {
            var pulseComp = entity.components[PulseAnimationComponent.self] ?? PulseAnimationComponent()
            
            if nextTargetCheckpointIndex == index {
                entity.isEnabled = true
                pulseComp.isActiveTarget = true
                var mat = UnlitMaterial(color: .systemBlue.withAlphaComponent(0.65))
                mat.blending = .transparent(opacity: 0.65)
                entity.model?.materials = [mat]
            } else if let target = nextTargetCheckpointIndex, index > target {
                entity.isEnabled = true
                pulseComp.isActiveTarget = false
                entity.scale = SIMD3<Float>(repeating: pulseComp.baseScale)
                var mat = UnlitMaterial(color: .systemGray.withAlphaComponent(0.25))
                mat.blending = .transparent(opacity: 0.25)
                entity.model?.materials = [mat]
            } else {
                entity.isEnabled = false
                pulseComp.isActiveTarget = false
            }
            entity.components.set(pulseComp)
        }
        
        if let root = directionIndicatorRoot {
            root.isEnabled = hasWaypointTarget
            if hasWaypointTarget, let targetIndex = nextTargetCheckpointIndex {
                var indicatorComp = root.components[WaypointIndicatorComponent.self] ?? WaypointIndicatorComponent()
                indicatorComp.targetPosition = markerWorldPositions[targetIndex]
                root.components.set(indicatorComp)
            }
        }
        
        for (index, entity) in checkpointEntities.enumerated() {
            entity.isEnabled = nextTargetCheckpointIndex != nil ? index <= nextTargetCheckpointIndex! : true
            if index == currentCheckpointIndex && hasArrivedAtCurrentCheckpoint {
                var material = SceneObjectSystem.makeMaterial(for: currentTexture.material)
                material.faceCulling = PhysicallyBasedMaterial.FaceCulling.none
                entity.model?.materials = [material]
            }
        }
    }

    // MARK: - ECS Entity Factory Helpers
    
    private func setupDirectionIndicator() {
        guard let root = rootAnchor else { return }
        let rootEntity = ModelEntity()
        rootEntity.isEnabled = false
        
        let mesh = MeshResource.generateText("➔", extrusionDepth: 0.04, font: .systemFont(ofSize: 0.35, weight: .black))
        let arrowMat = SimpleMaterial(color: UIColor(red: 0.05, green: 0.40, blue: 1.0, alpha: 1.0), roughness: 0.2, isMetallic: false)
        let arrowEntity = ModelEntity(mesh: mesh, materials: [arrowMat])
        
        arrowEntity.position = SIMD3<Float>(-mesh.bounds.center.x, -mesh.bounds.center.y, -mesh.bounds.center.z)
        let pivot = Entity()
        pivot.addChild(arrowEntity)
        pivot.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0]) * simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        
        rootEntity.addChild(pivot)
        rootEntity.components.set(WaypointIndicatorComponent())
        
        root.addChild(rootEntity)
        directionIndicatorRoot = rootEntity
    }

    private func makeCheckpointEntity(for checkpoint: Checkpoint) -> ModelEntity {
        // 1. Generate the base entity using your factory
        let entity = SceneObjectSystem.makeObject(type: checkpoint.shape.objectType, texture: checkpoint.shape.textures[0].material)
        
        // 2. Get the natural height directly from the shape type (bypassing ObjectConfiguration)
        let naturalHeight = SceneObjectSystem.baseDimensions(for: checkpoint.shape.objectType).y
        
        // 3. Explicitly define the target height as a Float to clear the Duration error
        let targetHeight: Float = 1.30
        
        let scale = targetHeight / naturalHeight
        entity.scale = SIMD3<Float>(repeating: scale)
        entity.position.y = (naturalHeight * scale) / 2
        
        return entity
    }

    private func makeMarkerEntity() -> ModelEntity {
        var material = UnlitMaterial(color: .systemBlue.withAlphaComponent(0.55))
        material.blending = .transparent(opacity: 0.55)
        let entity = ModelEntity(mesh: .generateSphere(radius: markerRadius), materials: [material])
        entity.scale = SIMD3<Float>(1, 0.04, 1)
        return entity
    }
}
