//
//  Level1ViewModel.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import ARKit
import Combine
import Foundation
import RealityKit
import UIKit

enum Level1Phase: Equatable {
    case onboarding
    case scanningSurface
    case surfaceReady
    case lightShadowIntro
    case findingShapes
    case textureTapPrompt
    case textureExploration
    case shapeChange
    case completed
}

enum Level1RadarTarget: String, CaseIterable, Equatable {
    case light
    case shadow
    case object
}

struct Level1Instruction: Equatable {
    let text: String
    let audioFileName: String?
    let radarTarget: Level1RadarTarget?
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
    let textureStops = Level1Content.kubus.textures
    let shapeOptions = Level1Content.checkpoints.map(\.shape)
    let onboardingDialog = Level1Content.onboardingDialog

    @Published private(set) var phase: Level1Phase = .onboarding
    @Published private(set) var onboardingIndex = 0
    @Published private(set) var lightShadowIndex = 0
    @Published private(set) var currentCheckpointIndex = 0
    @Published private(set) var currentTextureIndex = 0
    @Published private(set) var selectedShapeIndex = 0
    @Published private(set) var waypointDistanceMeters: Double = 0
    @Published private(set) var hasWaypointTarget = false
    @Published private(set) var checkpointCelebration: CheckpointCelebration?
    @Published private(set) var selectedRadarTarget: Level1RadarTarget?
    @Published private(set) var showsObjectModeBadge = false
    @Published private(set) var hasChangedShape = false
    @Published private(set) var successFeedbackTrigger = 0

    private var visitedCheckpoints: Set<Int> = [0]
    private var visitedTextures: Set<Int> = [0]
    private let progressStore = GameProgressStore.shared
    let arSceneViewModel = ARSceneViewModel()

    private weak var rootAnchor: AnchorEntity?
    private var pathAnchor: AnchorEntity?
    private var checkpointLightEntities: [Entity] = []
    private var radarEntities: [Level1RadarTarget: Entity] = [:]
    private var radarLabelEntity: Entity?
    private var hasPlacedScene = false
    private var latestHorizontalPlaneAnchor: ARPlaneAnchor?
    private var latestCameraPositionXZ: SIMD2<Float>?
    private var latestCameraForwardXZ: SIMD2<Float>?
    private var scanStartTime: Date?

    private var checkpointEntities: [ModelEntity] = []
    private var checkpointShadowEntities: [Entity] = []
    private var checkpointLocalPositions: [SIMD3<Float>] = []
    private var markerWorldPositions: [SIMD3<Float>] = []
    private var checkpointHighlightEntities: [Entity] = []
    private var directionIndicatorRoot: ModelEntity?
    private var directionIndicatorLabel: ModelEntity?
    private var lastIndicatorDistanceText: String?
    private var lastArrivedIndex: Int?

    private let hapticGenerator = UINotificationFeedbackGenerator()
    private let pathRadius: Float = 3.2
    private let checkpointHeight: Float = 0.50
    private let markerRadius: Float = 1.0

    private let lightShadowInstructions: [Level1Instruction] = [
        Level1Instruction(
            text: "Coba jalan dan lihat keliling kotak! Ada yang terang dan ada yang gelap lho.",
            audioFileName: "level-1/5 coba jalan dan lihat keliling kotak.mp3",
            radarTarget: nil
        ),
        Level1Instruction(
            text: "Coba deh tekan lingkaran ini.",
            audioFileName: "level-1/marker/6 [marker] coba deh tekan lingkaran ini.mp3",
            radarTarget: .light
        ),
        Level1Instruction(
            text: "Yang bagian terang ini Cahaya!",
            audioFileName: "level-1/marker/7 [marker] yang bagian terang ini cahaya.mp3",
            radarTarget: nil
        ),
        Level1Instruction(
            text: "Sekarang tekan lingkaran ini.",
            audioFileName: "level-1/8 sekarang tekan lingkaran ini.mp3",
            radarTarget: .shadow
        ),
        Level1Instruction(
            text: "Bayangan muncul karena kotak menghalangi cahaya!",
            audioFileName: "level-1/marker/9 [marker] Bayangan muncul karena kotak menghalangi cahaya.mp3",
            radarTarget: nil
        ),
        Level1Instruction(
            text: "Yuk, coba tekan lingkaran ini!",
            audioFileName: "level-1/10 Yuk coba tekan lingkaran ini.mp3",
            radarTarget: .object
        ),
        Level1Instruction(
            text: "Ini Kubus! Semua sisinya sama besar, lho!",
            audioFileName: "level-1/marker/objek/[kubus] Ini Kubus Semua sisinya sama besar lho.mp3",
            radarTarget: nil
        )
    ]

    init() {
        hapticGenerator.prepare()
    }

    func setupLevel(in anchor: AnchorEntity) {
        rootAnchor = anchor
        setupDirectionIndicator()
    }

    func trackLatestHorizontalPlane(_ anchor: ARAnchor) {
        guard !hasPlacedScene, phase == .scanningSurface, let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .horizontal else { return }

        if let existing = latestHorizontalPlaneAnchor {
            if planeArea(planeAnchor) > planeArea(existing) {
                latestHorizontalPlaneAnchor = planeAnchor
            }
        } else {
            latestHorizontalPlaneAnchor = planeAnchor
        }

        if let bestPlane = latestHorizontalPlaneAnchor, planeArea(bestPlane) > 0.6,
           let start = scanStartTime, Date().timeIntervalSince(start) > 4.0 {
            placeSceneIfNeeded()
            phase = .lightShadowIntro
            lightShadowIndex = 0
            syncEntities()
        }
    }

    private func planeArea(_ planeAnchor: ARPlaneAnchor) -> Float {
        planeAnchor.planeExtent.width * planeAnchor.planeExtent.height
    }

    func updateCameraPose(position: SIMD3<Float>, forward: SIMD3<Float>) {
        latestCameraPositionXZ = SIMD2<Float>(position.x, position.z)
        let horizontalForward = SIMD2<Float>(forward.x, forward.z)
        let length = simd_length(horizontalForward)
        guard length > 0.0001 else { return }
        latestCameraForwardXZ = horizontalForward / length
    }

    func processSceneUpdate(cameraTransform: simd_float4x4) {
        guard phase == .findingShapes else { return }
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        checkProximity(cameraPosition: cameraPosition)
        updateDirectionIndicator(cameraTransform: cameraTransform, cameraPosition: cameraPosition)
    }

    func handleTap(on entity: Entity?) {
        if let target = radarTarget(for: entity) {
            tapRadarTarget(target)
        } else if phase == .textureTapPrompt, entityBelongsToLearningObject(entity) {
            objectTappedForTexture()
        }
    }

    func advanceDialog() {
        guard phase == .onboarding else { return }
        if onboardingIndex == onboardingDialog.count - 1 {
            phase = .scanningSurface
            scanStartTime = Date()
        } else {
            onboardingIndex += 1
        }
    }

    func continueAfterSurfaceCheck() {
        guard phase == .surfaceReady else { return }
        phase = .lightShadowIntro
        lightShadowIndex = 0
        syncEntities()
    }

    func rescanSurface() {
        guard phase == .surfaceReady || phase == .scanningSurface else { return }
        pathAnchor?.removeFromParent()
        pathAnchor = nil
        checkpointLightEntities.removeAll()
        radarEntities.removeAll()
        radarLabelEntity = nil
        hasPlacedScene = false
        checkpointEntities.removeAll()
        checkpointShadowEntities.removeAll()
        checkpointLocalPositions.removeAll()
        markerWorldPositions.removeAll()
        checkpointHighlightEntities.removeAll()
        latestHorizontalPlaneAnchor = nil
        hasWaypointTarget = false
        scanStartTime = Date()
        phase = .scanningSurface
    }

    func continueLightShadowIntro() {
        guard phase == .lightShadowIntro else { return }
        if lightShadowIndex == lightShadowInstructions.count - 1 {
            phase = .findingShapes
            selectedRadarTarget = nil
            hasWaypointTarget = true
            syncEntities()
        } else {
            lightShadowIndex += 1
            selectedRadarTarget = nil
        }
    }

    func tapRadarTarget(_ target: Level1RadarTarget) {
        guard phase == .lightShadowIntro, currentLightShadowInstruction.radarTarget == target else { return }
        triggerSuccessFeedback()
        selectedRadarTarget = target
        if lightShadowIndex < lightShadowInstructions.count - 1 {
            lightShadowIndex += 1
        }
    }

    func continueToTextureLesson() {
        guard phase == .findingShapes, hasFoundAllShapes else { return }
        phase = .textureTapPrompt
        currentCheckpointIndex = 0
        currentTextureIndex = 0
        visitedTextures = [0]
        showsObjectModeBadge = false
        hasWaypointTarget = false
        syncEntities()
    }

    func objectTappedForTexture() {
        guard phase == .textureTapPrompt else { return }
        showsObjectModeBadge = true
        phase = .textureExploration
        triggerSuccessFeedback()
        syncEntities()
    }

    func selectTexture(at index: Int) {
        guard phase == .textureExploration, textureStops.indices.contains(index) else { return }
        currentTextureIndex = index
        visitedTextures.insert(index)
        triggerSuccessFeedback()
        applyCurrentTextureToPrimaryObject()
    }

    func startShapeChange() {
        guard phase == .textureExploration, hasExploredAllTextures else { return }
        phase = .shapeChange
        hasChangedShape = false
        syncEntities()
    }

    func selectShape(at index: Int) {
        guard phase == .shapeChange, shapeOptions.indices.contains(index) else { return }
        selectedShapeIndex = index
        hasChangedShape = index != 0
        triggerSuccessFeedback()
        applyCurrentShapeToPrimaryObject()
    }

    func finishLevel() {
        guard phase == .shapeChange, hasChangedShape else { return }
        phase = .completed
        progressStore.markLevelCompleted(Level1Content.levelID)
    }

    var currentDialogLine: DialogLine { onboardingDialog[onboardingIndex] }
    var isLastDialogLine: Bool { onboardingIndex == onboardingDialog.count - 1 }
    var currentLightShadowInstruction: Level1Instruction { lightShadowInstructions[lightShadowIndex] }
    var currentCheckpoint: Checkpoint { checkpoints[currentCheckpointIndex] }
    var currentTexture: TextureStop { textureStops[currentTextureIndex] }
    var selectedShape: GameShape { shapeOptions[selectedShapeIndex] }
    var hasFoundAllShapes: Bool { checkpoints.indices.allSatisfy { visitedCheckpoints.contains($0) } }
    var hasExploredAllTextures: Bool { textureStops.indices.allSatisfy { visitedTextures.contains($0) } }
    var nextTargetCheckpointIndex: Int? {
        guard phase == .findingShapes else { return nil }
        return checkpoints.indices.first { !visitedCheckpoints.contains($0) }
    }

    var narrationText: String {
        switch phase {
        case .onboarding:
            currentDialogLine.text
        case .scanningSurface:
            "Arahkan iPad pelan-pelan ke lantai atau meja."
        case .surfaceReady:
            "Permukaan sudah siap."
        case .lightShadowIntro:
            currentLightShadowInstruction.text
        case .findingShapes:
            hasFoundAllShapes ? "Wah, semua bentuk sudah kamu temukan!" : "Selain kotak, coba temukan bentuk yang lain di sekitarmu!"
        case .textureTapPrompt:
            "Coba tekan sekali kotaknya! Kita lihat tekstur yang lain ya!"
        case .textureExploration:
            currentTexture.description
        case .shapeChange:
            hasChangedShape ? "Kerja bagus! Kamu berhasil mengganti bentuk benda ini." : "Coba tekan tombol ini. Kita ganti bentuk yang lain ya!"
        case .completed:
            "Kerja bagus! Kamu berhasil mengganti bentuk benda ini."
        }
    }

    var narrationAudioFileName: String? {
        switch phase {
        case .onboarding:
            currentDialogLine.audioFileName
        case .scanningSurface:
            "level-1/3 coba cari objek berbentuk kotak di sekitarmu.mp3"
        case .surfaceReady:
            "level-1/4 yeay ketemu sekarang lumi hidupin lampu.mp3"
        case .lightShadowIntro:
            currentLightShadowInstruction.audioFileName
        case .findingShapes:
            hasFoundAllShapes ? nil : "level-1/12 Selain kotak coba temukan bentuk yang lain di sekitarmu.mp3"
        case .textureTapPrompt:
            "level-1/14 Coba tekan sekali kotaknya Kita lihat tekstur yang lain yaa.mp3"
        case .textureExploration:
            currentTexture.audioFileName
        case .shapeChange:
            hasChangedShape
                ? "level-1/17 Kerja bagus Kamu berhasil mengganti bentuk benda ini.mp3"
                : "level-1/15 Wah ada banyak bentuk Kamu bisa ganti bentuk yang lain lho.mp3"
        case .completed:
            "level-1/17 Kerja bagus Kamu berhasil mengganti bentuk benda ini.mp3"
        }
    }

    var narrationID: String {
        "\(phase)-\(onboardingIndex)-\(lightShadowIndex)-\(currentCheckpointIndex)-\(currentTextureIndex)-\(selectedShapeIndex)-\(hasFoundAllShapes)-\(hasChangedShape)"
    }

    private func placeSceneIfNeeded() {
        guard !hasPlacedScene, let root = rootAnchor else { return }
        hasPlacedScene = true

        let count = checkpoints.count
        let scanCameraXZ = latestCameraPositionXZ ?? .zero
        let scanForwardXZ = latestCameraForwardXZ ?? SIMD2<Float>(0, -1)
        let floorY = latestHorizontalPlaneAnchor?.transform.columns.3.y ?? -1.2
        let firstCheckpointDistance: Float = 1.25
        let pathCenterXZ = scanCameraXZ + scanForwardXZ * (pathRadius + firstCheckpointDistance)
        let firstCheckpointDirection = -scanForwardXZ

        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4<Float>(pathCenterXZ.x, floorY, pathCenterXZ.y, 1)
        let anchorGroup = AnchorEntity(world: matrix)
        root.addChild(anchorGroup)
        pathAnchor = anchorGroup

        for (index, checkpoint) in checkpoints.enumerated() {
            let angleStep = (2 * Float.pi) / Float(count)
            let baseAngle = atan2(firstCheckpointDirection.y, firstCheckpointDirection.x)
            let angle = baseAngle + angleStep * Float(index)
            let shapeXZ = pathCenterXZ + SIMD2<Float>(cos(angle), sin(angle)) * pathRadius
            let worldPosition = SIMD3<Float>(shapeXZ.x, floorY + 0.005, shapeXZ.y)
            markerWorldPositions.append(worldPosition)

            let localPosition = SIMD3<Float>(shapeXZ.x - pathCenterXZ.x, 0, shapeXZ.y - pathCenterXZ.y)
            checkpointLocalPositions.append(localPosition)

            let shapeEntity = makeCheckpointEntity(for: checkpoint)
            shapeEntity.name = "level1-object-\(checkpoint.shape.id)"
            shapeEntity.position += localPosition
            checkpointEntities.append(shapeEntity)
            anchorGroup.addChild(shapeEntity)

            let shadowEntity = makeShadowEntity(for: checkpoint.shape.objectType)
            shadowEntity.position = localPosition + shadowOffset(for: checkpoint.shape.objectType)
            checkpointShadowEntities.append(shadowEntity)
            anchorGroup.addChild(shadowEntity)

            let lightPosition = localPosition + lightOffset(for: checkpoint.shape.objectType)
            let lightTarget = localPosition + SIMD3<Float>(0, checkpointHeight * 0.55, 0)
            let lightEntity = makeLightEntity(from: lightPosition, aimingAt: lightTarget)
            checkpointLightEntities.append(lightEntity)
            anchorGroup.addChild(lightEntity)

            let highlightEntity = makeCheckpointHighlightEntity()
            highlightEntity.position = SIMD3<Float>(localPosition.x, 0.016, localPosition.z)
            checkpointHighlightEntities.append(highlightEntity)
            anchorGroup.addChild(highlightEntity)
        }

        let primaryObjectPosition = checkpointLocalPositions.first ?? .zero
        let primaryLightPosition = checkpointLightEntities.first?.position ?? primaryObjectPosition + lightOffset(for: .cube)
        let primaryShadowPosition = checkpointShadowEntities.first?.position ?? primaryObjectPosition + shadowOffset(for: .cube)
        let objectRadarPosition = primaryObjectPosition + objectRadarOffset(from: primaryObjectPosition)
        let radarPositions: [Level1RadarTarget: SIMD3<Float>] = [
            .light: primaryLightPosition + SIMD3<Float>(0, 0.035, 0),
            .shadow: primaryShadowPosition + SIMD3<Float>(0, 0.10, 0),
            .object: objectRadarPosition
        ]
        for (target, position) in radarPositions {
            let radar = makeRadarEntity(target: target)
            radar.position = position
            radarEntities[target] = radar
            anchorGroup.addChild(radar)
        }

        syncEntities()
    }

    private func checkProximity(cameraPosition: SIMD3<Float>) {
        guard let targetIndex = nextTargetCheckpointIndex,
              markerWorldPositions.indices.contains(targetIndex) else { return }

        let targetPosition = markerWorldPositions[targetIndex]
        let dx = cameraPosition.x - targetPosition.x
        let dz = cameraPosition.z - targetPosition.z
        let distance = sqrt(dx * dx + dz * dz)

        if distance < markerRadius {
            guard lastArrivedIndex != targetIndex else { return }
            lastArrivedIndex = targetIndex
            arrive(atCheckpointIndex: targetIndex)
        } else if lastArrivedIndex == targetIndex {
            lastArrivedIndex = nil
        }
    }

    private func arrive(atCheckpointIndex index: Int) {
        guard checkpoints.indices.contains(index), !visitedCheckpoints.contains(index) else { return }
        currentCheckpointIndex = index
        visitedCheckpoints.insert(index)
        triggerSuccessFeedback()
        showCelebration(for: index)
        syncEntities()
    }

    func syncEntities() {
        let showLightAndShadow = phase != .onboarding && phase != .scanningSurface

        for (index, entity) in checkpointEntities.enumerated() {
            switch phase {
            case .surfaceReady, .lightShadowIntro:
                entity.isEnabled = index == 0
            case .findingShapes:
                entity.isEnabled = visitedCheckpoints.contains(index) || index == nextTargetCheckpointIndex
            case .textureTapPrompt, .textureExploration, .shapeChange, .completed:
                entity.isEnabled = index == 0
            default:
                entity.isEnabled = false
            }
        }

        for (index, shadow) in checkpointShadowEntities.enumerated() {
            shadow.isEnabled = showLightAndShadow && (checkpointEntities[safe: index]?.isEnabled == true)
        }

        for (index, light) in checkpointLightEntities.enumerated() {
            light.isEnabled = showLightAndShadow && (checkpointEntities[safe: index]?.isEnabled == true)
        }

        for (index, highlight) in checkpointHighlightEntities.enumerated() {
            highlight.isEnabled = phase == .findingShapes && index == nextTargetCheckpointIndex
        }

        directionIndicatorRoot?.isEnabled = hasWaypointTarget && nextTargetCheckpointIndex != nil
        syncRadarEntities()
    }

    private func updateDirectionIndicator(cameraTransform: simd_float4x4, cameraPosition: SIMD3<Float>) {
        guard let root = directionIndicatorRoot,
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
        let position = cameraPosition
            + normalizedForward * (max(0.3, min(1.15, distanceMeters - 0.4)) + sin(time * 2.4) * 0.10)
            + SIMD3<Float>(0, -0.35 + sin(time * 2.0) * 0.015, 0)

        root.look(at: SIMD3<Float>(targetPosition.x, position.y, targetPosition.z), from: position, relativeTo: nil)
        updateIndicatorDistanceLabel(meters: Double(distanceMeters), parent: root)
    }

    private func triggerSuccessFeedback() {
        successFeedbackTrigger += 1
        hapticGenerator.notificationOccurred(.success)
        hapticGenerator.prepare()
    }

    private func showCelebration(for checkpointIndex: Int) {
        let celebration = CheckpointCelebration(
            checkpointNumber: max(checkpointIndex, 1),
            checkpointCount: checkpoints.count - 1,
            shapeName: checkpoints[checkpointIndex].shape.displayName
        )
        checkpointCelebration = celebration
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.4))
            guard self?.checkpointCelebration?.id == celebration.id else { return }
            self?.checkpointCelebration = nil
        }
    }

    private func applyCurrentTextureToPrimaryObject() {
        guard let entity = checkpointEntities.first else { return }
        var material = SceneObjectSystem.makeMaterial(for: currentTexture.material)
        material.faceCulling = .none
        entity.model?.materials = [material]
    }

    private func applyCurrentShapeToPrimaryObject() {
        guard let entity = checkpointEntities.first else { return }
        let replacement = SceneObjectSystem.makeObject(type: selectedShape.objectType, texture: currentTexture.material)
        entity.model = replacement.model
        entity.collision = replacement.collision
        let finalScale = checkpointHeight / SceneObjectSystem.baseDimensions(for: selectedShape.objectType).y
        if let primaryShadow = checkpointShadowEntities.first {
            configureShadowEntity(primaryShadow, for: selectedShape.objectType)
            primaryShadow.position = (checkpointLocalPositions.first ?? .zero) + shadowOffset(for: selectedShape.objectType)
        }
        entity.scale = SIMD3<Float>(repeating: 0.05)
        entity.move(
            to: Transform(
                scale: SIMD3<Float>(repeating: finalScale * 1.14),
                rotation: entity.orientation,
                translation: entity.position
            ),
            relativeTo: entity.parent,
            duration: 0.18,
            timingFunction: .easeOut
        )
        Task { @MainActor [weak entity] in
            try? await Task.sleep(for: .seconds(0.18))
            guard let entity else { return }
            entity.move(
                to: Transform(
                    scale: SIMD3<Float>(repeating: finalScale),
                    rotation: entity.orientation,
                    translation: entity.position
                ),
                relativeTo: entity.parent,
                duration: 0.16,
                timingFunction: .easeInOut
            )
        }
    }

    private func entityBelongsToLearningObject(_ entity: Entity?) -> Bool {
        var candidate = entity
        while let current = candidate {
            if current.name.hasPrefix("level1-object") {
                return true
            }
            candidate = current.parent
        }
        return false
    }

    private func radarTarget(for entity: Entity?) -> Level1RadarTarget? {
        var candidate = entity
        while let current = candidate {
            for target in Level1RadarTarget.allCases where current.name.contains("level1-radar-\(target.rawValue)") {
                return target
            }
            candidate = current.parent
        }
        return nil
    }

    private func syncRadarEntities() {
        let activeTarget = phase == .lightShadowIntro ? currentLightShadowInstruction.radarTarget : nil
        let explainedTarget = phase == .lightShadowIntro && currentLightShadowInstruction.radarTarget == nil ? selectedRadarTarget : nil
        for (target, entity) in radarEntities {
            entity.isEnabled = activeTarget == target || explainedTarget == target
        }

        radarLabelEntity?.removeFromParent()
        radarLabelEntity = nil

        guard phase == .lightShadowIntro,
              currentLightShadowInstruction.radarTarget == nil,
              let selectedRadarTarget,
              let radar = radarEntities[selectedRadarTarget],
              let parent = radar.parent else { return }

        let label = makeRadarLabel(text: currentLightShadowInstruction.text)
        label.position = radar.position + labelOffset(for: selectedRadarTarget)
        parent.addChild(label)
        radarLabelEntity = label
    }

    private func setupDirectionIndicator() {
        guard let root = rootAnchor else { return }
        let rootEntity = ModelEntity()
        rootEntity.isEnabled = false

        let mesh = MeshResource.generateText("➔", extrusionDepth: 0.04, font: .systemFont(ofSize: 0.35, weight: .black))
        let arrowEntity = ModelEntity(
            mesh: mesh,
            materials: [SimpleMaterial(color: UIColor(red: 0.44, green: 0.06, blue: 0.74, alpha: 1), roughness: 0.2, isMetallic: false)]
        )
        arrowEntity.position = SIMD3<Float>(-mesh.bounds.center.x, -mesh.bounds.center.y, -mesh.bounds.center.z)

        let pivot = Entity()
        pivot.addChild(arrowEntity)
        pivot.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0]) * simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        rootEntity.addChild(pivot)
        root.addChild(rootEntity)
        directionIndicatorRoot = rootEntity
    }

    private func updateIndicatorDistanceLabel(meters: Double, parent: ModelEntity) {
        let text = String(format: "%.1f Meter ke kiri", max(meters, 0.1))
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
        let scale = checkpointHeight / SceneObjectSystem.baseDimensions(for: checkpoint.shape.objectType).y
        entity.scale = SIMD3<Float>(repeating: scale)
        entity.position.y = checkpointHeight / 2
        var material = SceneObjectSystem.makeMaterial(for: checkpoint.shape.textures[0].material)
        material.faceCulling = .none
        entity.model?.materials = [material]
        return entity
    }

    private func makeCheckpointHighlightEntity() -> Entity {
        let root = Entity()
        var material = UnlitMaterial(color: UIColor.systemBlue.withAlphaComponent(0.55))
        material.blending = .transparent(opacity: 0.55)
        let circle = ModelEntity(mesh: .generateSphere(radius: 0.55), materials: [material])
        circle.scale = SIMD3<Float>(1, 0.035, 1)
        root.addChild(circle)
        return root
    }

    private func makeRadarEntity(target: Level1RadarTarget) -> Entity {
        let root = Entity()
        root.name = "level1-radar-\(target.rawValue)"

        let color: UIColor = target == .shadow ? .systemRed : .white
        var outerMaterial = UnlitMaterial(color: color.withAlphaComponent(0.32))
        outerMaterial.blending = .transparent(opacity: 0.32)
        let outer = ModelEntity(mesh: .generateSphere(radius: 0.10), materials: [outerMaterial])
        outer.name = "level1-radar-\(target.rawValue)-outer"
        outer.scale = SIMD3<Float>(1, 0.04, 1)
        outer.components.set(PulseAnimationComponent(baseScale: 1, speed: 5.2, amplitude: 0.18, isActiveTarget: true))
        outer.components.set(DynamicLightShadowComponent(castsShadow: false))
        outer.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.16)]))
        outer.components.set(InputTargetComponent())
        root.addChild(outer)

        var ringMaterial = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.92))
        ringMaterial.blending = .transparent(opacity: 0.92)
        let ring = ModelEntity(mesh: .generateSphere(radius: 0.068), materials: [ringMaterial])
        ring.name = "level1-radar-\(target.rawValue)-ring"
        ring.scale = SIMD3<Float>(1, 0.035, 1)
        ring.components.set(DynamicLightShadowComponent(castsShadow: false))
        ring.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.14)]))
        ring.components.set(InputTargetComponent())
        root.addChild(ring)

        let center = ModelEntity(
            mesh: .generateSphere(radius: 0.032),
            materials: [UnlitMaterial(color: target == .shadow ? .systemRed : .systemYellow)]
        )
        center.name = "level1-radar-\(target.rawValue)-center"
        center.components.set(DynamicLightShadowComponent(castsShadow: false))
        center.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.12)]))
        center.components.set(InputTargetComponent())
        root.addChild(center)

        root.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.18)]))
        root.components.set(InputTargetComponent())
        return root
    }

    private func makeRadarLabel(text: String) -> Entity {
        let root = Entity()
        root.components.set(BillboardComponent())

        let lines = wrappedRadarLabelText(text)
        let textMesh = MeshResource.generateText(
            lines,
            extrusionDepth: 0.002,
            font: .boldSystemFont(ofSize: 0.052)
        )
        let textEntity = ModelEntity(mesh: textMesh, materials: [UnlitMaterial(color: .black)])
        let textBounds = textMesh.bounds
        let padding = SIMD2<Float>(0.14, 0.10)
        let backgroundWidth = max(0.36, textBounds.extents.x + padding.x)
        let backgroundHeight = max(0.18, textBounds.extents.y + padding.y)
        textEntity.position = SIMD3<Float>(
            -textBounds.center.x,
            -textBounds.center.y,
            0.005
        )

        var backgroundMaterial = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.78))
        backgroundMaterial.blending = .transparent(opacity: 0.78)
        let background = ModelEntity(
            mesh: .generateBox(width: backgroundWidth, height: backgroundHeight, depth: 0.006),
            materials: [backgroundMaterial]
        )
        background.components.set(DynamicLightShadowComponent(castsShadow: false))

        root.addChild(background)
        root.addChild(textEntity)
        return root
    }

    private func wrappedRadarLabelText(_ text: String) -> String {
        let words = text.split(separator: " ")
        var lines: [String] = []
        var currentLine = ""
        let maximumCharactersPerLine = 24

        for word in words {
            let candidate = currentLine.isEmpty ? String(word) : "\(currentLine) \(word)"
            if candidate.count > maximumCharactersPerLine, !currentLine.isEmpty {
                lines.append(currentLine)
                currentLine = String(word)
            } else {
                currentLine = candidate
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines.joined(separator: "\n")
    }

    private func labelOffset(for target: Level1RadarTarget) -> SIMD3<Float> {
        switch target {
        case .light:
            SIMD3<Float>(0.48, 0.03, 0)
        case .shadow:
            SIMD3<Float>(-0.54, 0.08, 0)
        case .object:
            SIMD3<Float>(0.52, 0.12, 0)
        }
    }

    private func makeLightEntity(from position: SIMD3<Float>, aimingAt target: SIMD3<Float>) -> Entity {
        let root = Entity()
        root.position = position

        let light = Entity()
        var component = SpotLightComponent()
        component.color = .yellow
        component.intensity = 4_800
        component.attenuationRadius = 7
        component.innerAngleInDegrees = 18
        component.outerAngleInDegrees = 48
        light.components.set(component)
        if let angles = SceneLightSystem.aimingAngles(from: position, to: target) {
            light.orientation = SceneLightSystem.orientation(
                yawDegrees: angles.yawDegrees,
                pitchDegrees: angles.pitchDegrees
            )
        }
        root.addChild(light)

        let marker = ModelEntity(mesh: .generateSphere(radius: 0.08), materials: [UnlitMaterial(color: .yellow)])
        marker.components.set(DynamicLightShadowComponent(castsShadow: false))
        root.addChild(marker)
        return root
    }

    private func lightOffset(for objectType: LearningObjectType) -> SIMD3<Float> {
        let heightAdjustment: Float = objectType == .sphere ? 0.08 : 0
        return SIMD3<Float>(0.62, 0.78 + heightAdjustment, -0.58)
    }

    private func shadowOffset(for objectType: LearningObjectType) -> SIMD3<Float> {
        let radiusAdjustment: Float = objectType == .sphere ? 0.04 : 0
        return SIMD3<Float>(-0.24 - radiusAdjustment, 0.012, 0.22)
    }

    private func objectRadarOffset(from objectPosition: SIMD3<Float>) -> SIMD3<Float> {
        let radialDirection = SIMD2<Float>(objectPosition.x, objectPosition.z)
        let radialLength = simd_length(radialDirection)
        let outward = radialLength > 0.001 ? radialDirection / radialLength : SIMD2<Float>(0, 1)
        return SIMD3<Float>(outward.x * 0.34, checkpointHeight * 0.72, outward.y * 0.34)
    }

    private func makeShadowEntity(for objectType: LearningObjectType) -> Entity {
        let root = Entity()
        configureShadowEntity(root, for: objectType)
        return root
    }

    private func configureShadowEntity(_ root: Entity, for objectType: LearningObjectType) {
        root.children.removeAll()
        root.orientation = simd_quatf(angle: -.pi / 9, axis: [0, 1, 0])

        let baseRadius: Float = objectType == .sphere ? 0.34 : 0.40
        let layers: [(scale: SIMD3<Float>, alpha: Float)] = [
            (SIMD3<Float>(1.35, 0.012, 0.58), 0.035),
            (SIMD3<Float>(1.65, 0.010, 0.78), 0.022),
            (SIMD3<Float>(1.95, 0.008, 0.96), 0.010)
        ]

        for (index, layer) in layers.enumerated() {
            var material = UnlitMaterial(color: UIColor.black.withAlphaComponent(CGFloat(layer.alpha)))
            material.blending = .transparent(opacity: .init(floatLiteral: layer.alpha))
            let ellipse = ModelEntity(mesh: .generateSphere(radius: baseRadius), materials: [material])
            ellipse.name = "level1-soft-shadow-\(index)"
            ellipse.scale = layer.scale
            ellipse.components.set(DynamicLightShadowComponent(castsShadow: false))
            root.addChild(ellipse)
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
