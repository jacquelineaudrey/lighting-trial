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
import ARKit

enum Level1Phase: Equatable {
    case onboarding
    case scanningSurface
    case exploring
    case quiz
    case returningToStart
    case completed
}

struct CheckpointCelebration: Identifiable, Equatable {
    let id = UUID()
    let checkpointNumber: Int
    let checkpointCount: Int
    let shapeName: String
}

@MainActor
final class Level1ViewModel: ObservableObject {

    let checkpoints = Level1Content.checkpoints
    let onboardingDialog = Level1Content.onboardingDialog
    let quizQuestions = Level1Content.quiz
    private let randomizedQuizChoices: [[GameShape]]

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
    @Published private(set) var checkpointCelebration: CheckpointCelebration?

    private var visitedTextures: [Int: Set<Int>] = [:]
    private let progressStore = GameProgressStore.shared
    let arSceneViewModel = ARSceneViewModel()

    // AR State
    private weak var rootAnchor: AnchorEntity?
    private var pathAnchor: AnchorEntity?
    private var hasPlacedPath = false
    private var latestHorizontalPlaneAnchor: ARPlaneAnchor?

    // Current device camera pose (XZ-plane only), refreshed every frame so the
    // checkpoint path can be spawned in front of wherever the child is actually
    // looking when the surface is found — see `updateCameraPose` / `placePathIfNeeded`.
    private var latestCameraPositionXZ: SIMD2<Float>?
    private var latestCameraForwardXZ: SIMD2<Float>?
    private var scanStartTime: Date?
    
    private var checkpointWorldPositions: [SIMD3<Float>] = []
    private var markerWorldPositions: [SIMD3<Float>] = []
    private var checkpointEntities: [ModelEntity] = []
    private var checkpointHighlightEntities: [Entity] = []
    private var directionIndicatorRoot: ModelEntity?
    private var directionIndicatorLabel: ModelEntity?
    private var lastIndicatorDistanceText: String?

    private var lastArrivedIndex: Int?
    
    private let hapticGenerator = UINotificationFeedbackGenerator()
    
    // Config
    private let pathRadius: Float = 3.2
    private let childTargetHeight: Float = 0.50
    private let markerRadius: Float = 1.0
    private let checkpointHeight: Float = 0.50
    init() {
        randomizedQuizChoices = Level1Content.quiz.map { $0.choices.shuffled() }
        hapticGenerator.prepare()
    }

    func setupLevel(in anchor: AnchorEntity) {
        self.rootAnchor = anchor
        setupDirectionIndicator()
    }

    // MARK: - ARKit Plane Tracking
    
    func trackLatestHorizontalPlane(_ anchor: ARAnchor) {
        guard !hasPlacedPath, phase == .scanningSurface, let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .horizontal else { return }
        
        if let existing = latestHorizontalPlaneAnchor {
            if planeArea(planeAnchor) > planeArea(existing) {
                latestHorizontalPlaneAnchor = planeAnchor
            }
        } else {
            latestHorizontalPlaneAnchor = planeAnchor
        }
        
        if let bestPlane = latestHorizontalPlaneAnchor, planeArea(bestPlane) > 0.6 {
            if let start = scanStartTime, Date().timeIntervalSince(start) > 4.0 {
                placePathIfNeeded()
            }
        }
    }
    
    private func planeArea(_ planeAnchor: ARPlaneAnchor) -> Float {
        return planeAnchor.planeExtent.width * planeAnchor.planeExtent.height
    }

    /// Called every frame with the device's current camera transform so we know
    /// where the child is standing/looking at the moment the surface gets locked in.
    func updateCameraPose(position: SIMD3<Float>, forward: SIMD3<Float>) {
        latestCameraPositionXZ = SIMD2<Float>(position.x, position.z)
        let horizontalForward = SIMD2<Float>(forward.x, forward.z)
        let length = simd_length(horizontalForward)
        guard length > 0.0001 else { return }
        latestCameraForwardXZ = horizontalForward / length
    }
    
    // MARK: - Camera Tracking & Arrow
    
    func processSceneUpdate(cameraTransform: simd_float4x4) {
        guard phase == .exploring || phase == .returningToStart else { return }
        
        let camPos = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        
        checkProximity(cameraPosition: camPos)
        updateDirectionIndicator(cameraTransform: cameraTransform, cameraPosition: camPos)
    }
    
    private func updateDirectionIndicator(cameraTransform: simd_float4x4, cameraPosition: SIMD3<Float>) {
        guard let root = directionIndicatorRoot, root.isEnabled,
              let targetIndex = nextTargetCheckpointIndex,
              markerWorldPositions.indices.contains(targetIndex) else { return }
        
        let targetPosition = markerWorldPositions[targetIndex]
        
        let forward3D = -SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
        let horizontalForward3D = SIMD3<Float>(forward3D.x, 0, forward3D.z)
        let forwardLength = simd_length(horizontalForward3D)
        guard forwardLength > 0.0001 else { return }
        
        let normalizedForward = horizontalForward3D / forwardLength
        let dx = cameraPosition.x - targetPosition.x
        let dz = cameraPosition.z - targetPosition.z
        let distanceMeters = sqrt(dx * dx + dz * dz)
        let time = Float(CACurrentMediaTime())
        let forwardBackward = sin(time * 2.4) * 0.10
        let verticalFloat = sin(time * 2.0) * 0.015
        let safeOffset = min(1.15, distanceMeters - 0.4)
        let finalOffset = max(0.3, safeOffset)

        let position = cameraPosition
            + normalizedForward * (finalOffset + forwardBackward)
            + SIMD3<Float>(0, -0.35 + verticalFloat, 0)

        let targetXZ = SIMD3<Float>(targetPosition.x, position.y, targetPosition.z)
        root.look(at: targetXZ, from: position, relativeTo: nil)

        updateIndicatorDistanceLabel(meters: Double(distanceMeters), parent: root)
    }
    
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
    
    private func triggerCheckpointReachedFeedback(at worldPosition: SIMD3<Float>) {
        hapticGenerator.notificationOccurred(.success)
        hapticGenerator.prepare()

        let celebration = CheckpointCelebration(
            checkpointNumber: currentCheckpointIndex + 1,
            checkpointCount: checkpoints.count,
            shapeName: currentCheckpoint.shape.displayName
        )
        checkpointCelebration = celebration
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard self?.checkpointCelebration?.id == celebration.id else { return }
            self?.checkpointCelebration = nil
        }
        
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
        // FIX: This used to hardcode originXZ = .zero and forwardXZ = (0, -1), i.e. the
        // fixed ARKit world origin/axis established when the AR session first started
        // (usually while the phone was still pointed at the onboarding dialog, not the
        // floor). That placed the checkpoint path in a fixed world direction that had
        // nothing to do with where the child was actually looking once scanning
        // finished, so the path could easily spawn behind them or out of view — making
        // it look like nothing was placed. Now we spawn relative to the child's current
        // position/facing direction at the moment the surface is confirmed.
        let scanCameraXZ = latestCameraPositionXZ ?? .zero
        let scanForwardXZ = latestCameraForwardXZ ?? SIMD2<Float>(0, -1)
        var floorY: Float = latestHorizontalPlaneAnchor?.transform.columns.3.y ?? -1.2
        
        // FIX 2: Grab the exact real-world coordinates of the scanned floor!
        let planeY = latestHorizontalPlaneAnchor?.transform.columns.3.y ?? -1.2
        floorY = planeY

        // The first cube is always placed in front of the player at the
        // moment scanning completes. The remaining checkpoints form a ring
        // farther in that same direction.
        let firstCheckpointDistance: Float = 1.25
        let pathCenterXZ = scanCameraXZ + scanForwardXZ * (pathRadius + firstCheckpointDistance)
        let firstCheckpointDirection = -scanForwardXZ
        let shapePositionsXZ = (0..<count).map { i -> SIMD2<Float> in
            let angleStep = (2 * Float.pi) / Float(count)
            let baseAngle = atan2(firstCheckpointDirection.y, firstCheckpointDirection.x)
            let angle = baseAngle + angleStep * Float(i)
            return pathCenterXZ + SIMD2<Float>(cos(angle), sin(angle)) * pathRadius
        }

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
            
            let shapeLocalPosition = SIMD3<Float>(shapeXZ.x - pathCenterXZ.x, 0, shapeXZ.y - pathCenterXZ.y)
            let shapeEntity = makeCheckpointEntity(for: checkpoint)
            shapeEntity.position += shapeLocalPosition
            checkpointEntities.append(shapeEntity)
            anchorGroup.addChild(shapeEntity)

            let highlightEntity = makeCheckpointHighlightEntity()
            highlightEntity.position = SIMD3<Float>(shapeLocalPosition.x, 0.016, shapeLocalPosition.z)
            highlightEntity.isEnabled = false
            checkpointHighlightEntities.append(highlightEntity)
            anchorGroup.addChild(highlightEntity)
        }
        
        phase = .exploring
        hasWaypointTarget = true
        syncEntities()
    }

    // MARK: - Dialog & Logic
    
    var currentDialogLine: DialogLine { onboardingDialog[onboardingIndex] }
    var isLastDialogLine: Bool { onboardingIndex == onboardingDialog.count - 1 }

    func advanceDialog() {
        guard phase == .onboarding else { return }
        if isLastDialogLine {
            phase = .scanningSurface
            scanStartTime = Date()
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
        // FIX 1: Make the quiz instantly available as soon as you step into the last shape.
        // You no longer have to manually cycle through every texture to unlock it.
        checkpoints.indices.allSatisfy { visitedTextures[$0] != nil }
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
        hasWaypointTarget = false // Hide arrow during the quiz
        syncEntities()
    }

    var currentQuestion: TriviaQuestion { quizQuestions[quizIndex] }
    var currentQuizChoices: [GameShape] { randomizedQuizChoices[quizIndex] }

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
            hasWaypointTarget = true // Reactivate arrow pointing to Start
            syncEntities()
        } else {
            quizIndex += 1
        }
    }

    // MARK: - State Sync to ECS
    
    func syncEntities() {
        for (index, entity) in checkpointEntities.enumerated() {
            if phase == .returningToStart || nextTargetCheckpointIndex == nil {
                entity.isEnabled = true
            } else {
                entity.isEnabled = index <= nextTargetCheckpointIndex!
            }
            
            if index == currentCheckpointIndex && hasArrivedAtCurrentCheckpoint {
                var material = SceneObjectSystem.makeMaterial(for: currentTexture.material)
                material.faceCulling = PhysicallyBasedMaterial.FaceCulling.none
                entity.model?.materials = [material]
            }
        }

        // The active destination gets a bright, non-interactive outline on
        // the floor. This stays visible even when the arrow moves aside to
        // avoid the object.
        for (index, highlight) in checkpointHighlightEntities.enumerated() {
            highlight.isEnabled = index == nextTargetCheckpointIndex
        }

        if let root = directionIndicatorRoot {
            root.isEnabled = hasWaypointTarget
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
        root.addChild(rootEntity)
        directionIndicatorRoot = rootEntity
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

    private func makeCheckpointEntity(for checkpoint: Checkpoint) -> ModelEntity {
        let entity = SceneObjectSystem.makeObject(type: checkpoint.shape.objectType, texture: checkpoint.shape.textures[0].material)
        let naturalHeight = SceneObjectSystem.baseDimensions(for: checkpoint.shape.objectType).y
        let scale = checkpointHeight / naturalHeight
        entity.scale = SIMD3<Float>(repeating: scale)
        entity.position.y = checkpointHeight / 2
        return entity
    }

    private func makeCheckpointHighlightEntity() -> Entity {
        let root = Entity()
        var material = UnlitMaterial(color: UIColor.systemBlue.withAlphaComponent(0.55))
        material.blending = .transparent(opacity: 0.55)
        let circle = ModelEntity(
            mesh: .generateSphere(radius: 0.55),
            materials: [material]
        )
        circle.scale = SIMD3<Float>(1, 0.035, 1)
        root.addChild(circle)

        return root
    }
}
