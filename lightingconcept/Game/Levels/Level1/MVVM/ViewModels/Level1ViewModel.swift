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
import Photos
import UIKit

enum Level1Phase: Equatable {
    case onboarding
    case scanningSurface
    case surfaceReady
    case lightShadowIntro
    case findingShapes
    case returningToFirstObject
    case textureTapPrompt
    case textureExploration
    case shapeChange
    case drawingPrompt
    case drawingReady
    case drawingActive
    case photoPrompt
    case photoComparison
    case completed
}

enum Level1ExperimentPanel: Equatable {
    case texture
    case shape
}

enum Level1DevFlow: String, CaseIterable, Identifiable {
    case onboarding = "Onboarding"
    case lightShadowIntro = "Cahaya & Bayangan"
    case findingShapes = "Cari Bentuk"
    case textureTapPrompt = "Tap Tekstur"
    case textureExploration = "Eksplor Tekstur"
    case shapeChange = "Ganti Bentuk"
    case drawingPrompt = "Mulai Gambar"
    case photoPrompt = "Foto Gambar"
    case completed = "Selesai"

    var id: String { rawValue }
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
    let shapeOptions = Level1Content.allShapes
    let onboardingDialog = Level1Content.onboardingDialog

    @Published private(set) var phase: Level1Phase = .scanningSurface
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
    @Published private(set) var activeExperimentPanel: Level1ExperimentPanel?
    @Published private(set) var hasSelectedTexture = false
    @Published private(set) var hasSelectedShape = false
    @Published private(set) var hasOpenedTextureControls = false
    @Published private(set) var hasOpenedShapeControls = false
    @Published private(set) var hasContinuedToShapeSelection = false
    @Published private(set) var hasChangedShape = false
    @Published private(set) var hidesGuideForDrawing = false
    @Published private(set) var pendingDrawingPhotoCapture = false
    @Published private(set) var isSavingDrawingPhoto = false
    @Published private(set) var frozenSceneImage: UIImage?
    @Published private(set) var userDrawingImage: UIImage?
    @Published private(set) var showsPhotoComparisonPanel = false
    @Published var showsDrawingCamera = false
    @Published private(set) var photoSaveMessage: String?
    @Published var showsFreezeSceneConfirmation = false
    @Published private(set) var isPreparingFrozenScene = false
    @Published private(set) var isSceneFrozen = false
    @Published private(set) var successFeedbackTrigger = 0
    @Published private(set) var guideOverlayScreenPosition: CGPoint?
    @Published private(set) var textureTapObjectScreenPosition: CGPoint?
    @Published private(set) var isNarrationComplete = false
    @Published private(set) var isTransitioning = false
    @Published private(set) var roomScanProgress: Double = 0
    @Published private(set) var roomScanGuidanceText = "Putar badan pelan-pelan dan arahkan kamera ke sekeliling ruangan."

    private var visitedCheckpoints: Set<Int> = []
    private var visitedTextures: Set<Int> = [0]
    private let progressStore = GameProgressStore.shared
    let arSceneViewModel = ARSceneViewModel()

    private weak var rootAnchor: AnchorEntity?
    private var pathAnchor: AnchorEntity?
    private var checkpointLightEntities: [Entity] = []
    private var radarEntities: [Level1RadarTarget: Entity] = [:]
    private var radarWorldPositions: [Level1RadarTarget: SIMD3<Float>] = [:]
    private var radarLabelEntity: Entity?
    private var hasPlacedScene = false
    private var horizontalPlaneAnchors: [UUID: ARPlaneAnchor] = [:]
    private var verticalPlaneObstaclePoints: [UUID: [SIMD3<Float>]] = [:]
    private var meshObstaclePoints: [UUID: [SIMD3<Float>]] = [:]
    private var meshFaceCounts: [UUID: Int] = [:]
    private var meshSampleUpdateTimes: [UUID: TimeInterval] = [:]
    private var scannedHeadingSectors: Set<Int> = []
    private var lastPlacementAttemptTime: TimeInterval = 0
    private var latestCameraPositionXZ: SIMD2<Float>?
    private var latestCameraForwardXZ: SIMD2<Float>?

    private var checkpointEntities: [ModelEntity] = []
    private var checkpointLocalPositions: [SIMD3<Float>] = []
    private var markerWorldPositions: [SIMD3<Float>] = []
    private var markerSurfaceTone: EducationalMarkerStyle.SurfaceTone = .medium
    private var checkpointHighlightEntities: [Entity] = []
    private var checkpointShadowEntities: [Entity] = []
    private var directionIndicatorRoot: ModelEntity?
    private var directionIndicatorLabel: ModelEntity?
    private var lastIndicatorDistanceText: String?
    private var lastIndicatorDistanceBucket: Int?
    private var lastIndicatorDirectionCaption: String?
    private var lastArrivedIndex: Int?
    private var recentlyExplainedCheckpointIndex: Int?
    private let shadowReceiverManager = ShadowReceiverManager()
    private var guideRoot: Entity?
    private var guideCharacter: Entity?
    private var guideCharacterAsset: CharacterGuideAsset?
    private var guideCloud: Entity?
    private var guideText: String?
    private var guideNeedsPlacement = true
    private var activeNarrationID: String?
    private var transitionGateTask: Task<Void, Never>?

    /// Set by the flow view so tap-driven actions can stop the narrator
    /// right away when the player taps to skip before it finishes.
    var onNarrationSkipRequested: (() -> Void)?

    private let hapticGenerator = UINotificationFeedbackGenerator()
    private let preferredCheckpointSpacing: Float = 1.1
    private let minimumCheckpointSpacing: Float = 0.78
    private let maximumCheckpointStepDistance: Float = 1.7
    private let firstCheckpointDistance: Float = 0.8
    // 3/5 dari ukuran objek sebelumnya (0.34 m).
    private let checkpointHeight: Float = 0.204
    private let markerRadius: Float = 0.5
    private let transitionDebounceDuration = Duration.milliseconds(320)
    private let roomScanSectorCount = 8
    private let requiredRoomScanSectorCount = 7
    private let requiredLiDARPlacementProgress: Float = 0.72
    private let planeEdgeClearance: Float = 0.62
    private let realObjectClearance: Float = 0.58
    private let maximumMeshSamplesPerAnchor = 700
    private let minimumMeshSampleUpdateInterval: TimeInterval = 0.45
    private let minimumPlacementAttemptInterval: TimeInterval = 0.75

    // Mengikuti konfigurasi presentasi bayangan Level 3 agar hasil antar-level konsisten.
    private static let shadowLightIntensity: Float = 3_200
    private static let shadowBeamOuterAngle: Float = 54
    private static let shadowAttenuationRadius: Float = 8


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
        setupGuideCharacter()

        // `setupLevel` dipanggil dari `UIViewRepresentable.makeUIView`. Tunda
        // perubahan @Published sampai siklus pembaruan SwiftUI selesai.
        Task { @MainActor [weak self] in
            self?.resetRoomScanTracking()
        }
    }

    func trackPlane(_ planeAnchor: ARPlaneAnchor) {
        guard !hasPlacedScene, phase == .scanningSurface else { return }

        switch planeAnchor.alignment {
        case .horizontal:
            horizontalPlaneAnchors[planeAnchor.identifier] = planeAnchor
        case .vertical:
            verticalPlaneObstaclePoints[planeAnchor.identifier] = obstaclePoints(for: planeAnchor)
        @unknown default:
            break
        }

        updateRoomScanStatus()
        placeSceneIfReady()
    }

    func trackSceneMesh(_ meshAnchor: ARMeshAnchor) {
        guard !hasPlacedScene, phase == .scanningSurface else { return }

        let now = ProcessInfo.processInfo.systemUptime
        if let lastUpdate = meshSampleUpdateTimes[meshAnchor.identifier],
           now - lastUpdate < minimumMeshSampleUpdateInterval {
            return
        }
        meshSampleUpdateTimes[meshAnchor.identifier] = now

        meshObstaclePoints[meshAnchor.identifier] = sampledWorldVertices(from: meshAnchor)
        meshFaceCounts[meshAnchor.identifier] = meshAnchor.geometry.faces.count
        arSceneViewModel.updateLiDARScan(
            meshCount: meshFaceCounts.count,
            faceCount: meshFaceCounts.values.reduce(0, +)
        )
        updateRoomScanStatus()
        placeSceneIfReady()
    }

    func removeScannedAnchors(_ anchors: [ARAnchor]) {
        guard !hasPlacedScene, phase == .scanningSurface else { return }

        for anchor in anchors {
            horizontalPlaneAnchors[anchor.identifier] = nil
            verticalPlaneObstaclePoints[anchor.identifier] = nil
            meshObstaclePoints[anchor.identifier] = nil
            meshFaceCounts[anchor.identifier] = nil
            meshSampleUpdateTimes[anchor.identifier] = nil
        }
        updateRoomScanStatus()
    }

    private func planeArea(_ planeAnchor: ARPlaneAnchor) -> Float {
        planeAnchor.planeExtent.width * planeAnchor.planeExtent.height
    }

    private func trackScannedHeading(_ direction: SIMD2<Float>) {
        guard phase == .scanningSurface, !hasPlacedScene else { return }

        let normalizedAngle = atan2(direction.y, direction.x) + Float.pi
        let sectorWidth = (2 * Float.pi) / Float(roomScanSectorCount)
        let sector = min(Int(normalizedAngle / sectorWidth), roomScanSectorCount - 1)
        guard scannedHeadingSectors.insert(sector).inserted else { return }

        updateRoomScanStatus()
        placeSceneIfReady()
    }

    private func resetRoomScanTracking() {
        horizontalPlaneAnchors.removeAll()
        verticalPlaneObstaclePoints.removeAll()
        meshObstaclePoints.removeAll()
        meshFaceCounts.removeAll()
        meshSampleUpdateTimes.removeAll()
        scannedHeadingSectors.removeAll()
        lastPlacementAttemptTime = 0
        arSceneViewModel.resetLiDARScan()
        if arSceneViewModel.surfaceState != .scanning {
            arSceneViewModel.surfaceState = .scanning
        }
        if roomScanProgress != 0 {
            roomScanProgress = 0
        }
        let initialGuidance = "Putar badan pelan-pelan dan arahkan kamera ke sekeliling ruangan."
        if roomScanGuidanceText != initialGuidance {
            roomScanGuidanceText = initialGuidance
        }
    }

    private var hasCompletedDirectionScan: Bool {
        scannedHeadingSectors.count >= requiredRoomScanSectorCount
    }

    private var hasEnoughLiDARCoverage: Bool {
        !arSceneViewModel.isLiDARAvailable
            || arSceneViewModel.lidarPlacementProgress >= requiredLiDARPlacementProgress
    }

    private var bestPlaneFitProgress: Double {
        let bestCapacity = horizontalPlaneAnchors.values
            .map { theoreticalCheckpointCapacity(on: $0) }
            .max() ?? 0
        return min(Double(bestCapacity) / Double(checkpoints.count), 1)
    }

    private func updateRoomScanStatus() {
        guard phase == .scanningSurface, !hasPlacedScene else { return }

        let planeFitProgress = bestPlaneFitProgress
        let hasEnoughCoverage = hasEnoughLiDARCoverage
        let directionProgress = min(
            Double(scannedHeadingSectors.count) / Double(requiredRoomScanSectorCount),
            1
        )
        let geometryProgress: Double
        if arSceneViewModel.isLiDARAvailable {
            let lidarProgress = min(
                Double(arSceneViewModel.lidarPlacementProgress / requiredLiDARPlacementProgress),
                1
            )
            geometryProgress = min(lidarProgress, planeFitProgress)
        } else {
            geometryProgress = planeFitProgress
        }

        let newProgress = min(directionProgress * 0.7 + geometryProgress * 0.3, 0.97)
        if abs(roomScanProgress - newProgress) >= 0.005 {
            roomScanProgress = newProgress
        }

        let newSurfaceState: SurfaceDetectionState = horizontalPlaneAnchors.isEmpty ? .scanning : .found
        if arSceneViewModel.surfaceState != newSurfaceState {
            arSceneViewModel.surfaceState = newSurfaceState
        }

        let newGuidanceText: String
        if !hasCompletedDirectionScan {
            newGuidanceText = "Putar badan pelan-pelan dan arahkan kamera ke sekeliling ruangan."
        } else if planeFitProgress < 1 {
            newGuidanceText = "Arahkan kamera ke lantai yang luas dan kosong."
        } else if !hasEnoughCoverage {
            newGuidanceText = "Scan juga benda dan tembok di sekitar tempat bermain."
        } else {
            newGuidanceText = "Mencari tempat aman untuk tiga bentuk..."
        }
        if roomScanGuidanceText != newGuidanceText {
            roomScanGuidanceText = newGuidanceText
        }
    }

    private func placeSceneIfReady() {
        guard phase == .scanningSurface,
              !hasPlacedScene,
              hasCompletedDirectionScan,
              hasEnoughLiDARCoverage else { return }

        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPlacementAttemptTime >= minimumPlacementAttemptInterval else { return }
        lastPlacementAttemptTime = now

        guard let placement = safeRoomPlacement() else { return }

        placeScene(using: placement)
        roomScanProgress = 1
        roomScanGuidanceText = "Tempat bermain sudah siap."
        arSceneViewModel.surfaceState = .placed
        phase = .surfaceReady
        syncEntities()
    }

    private func safeRoomPlacement() -> Level1RoomPlacement? {
        let detectedPlanes = Array(horizontalPlaneAnchors.values)
        let detectedFloorPlanes = detectedPlanes.filter { $0.classification == .floor }
        let planes = (detectedFloorPlanes.isEmpty ? detectedPlanes : detectedFloorPlanes)
            .sorted { planeArea($0) > planeArea($1) }
        var bestPlacement: Level1RoomPlacement?
        var bestScore = -Float.greatestFiniteMagnitude

        for plane in planes {
            guard let candidate = safestPlacement(on: plane), candidate.score > bestScore else { continue }
            bestPlacement = candidate.placement
            bestScore = candidate.score
        }
        return bestPlacement
    }

    private func safestPlacement(on plane: ARPlaneAnchor) -> (placement: Level1RoomPlacement, score: Float)? {
        let center = plane.center
        let planeWorldCenter = plane.transform * SIMD4<Float>(center.x, 0, center.z, 1)
        let floorY = planeWorldCenter.y
        let horizontalObstacles = horizontalPlaneAnchors.values
            .filter { $0.identifier != plane.identifier }
            .flatMap { obstaclePoints(forHorizontalPlane: $0, above: floorY) }
        let fixedPlaneObstacles = verticalPlaneObstaclePoints.values.flatMap { $0 }
            + horizontalObstacles
        let meshObstacles = meshObstaclePoints.values
            .flatMap { $0 }
            .filter { $0.y > floorY + 0.10 && $0.y < floorY + 1.8 }

        guard let worldPoints = adaptiveCheckpointPositions(
            on: plane,
            meshObstacles: meshObstacles,
            verticalObstacles: fixedPlaneObstacles
        ) else { return nil }

        let centerXZ = worldPoints.reduce(SIMD2<Float>.zero, +) / Float(worldPoints.count)
        let clearanceScore = layoutClearanceScore(
            worldPoints,
            meshObstacles: meshObstacles,
            verticalObstacles: fixedPlaneObstacles
        )
        let pathScore = zip(worldPoints, worldPoints.dropFirst())
            .map { pair in
                1 / (1 + abs(simd_distance(pair.0, pair.1) - preferredCheckpointSpacing))
            }
            .reduce(0, +)

        return (
            Level1RoomPlacement(
                centerXZ: centerXZ,
                floorY: floorY,
                checkpointXZ: worldPoints
            ),
            clearanceScore + pathScore * 0.2
        )
    }

    private func theoreticalCheckpointCapacity(on plane: ARPlaneAnchor) -> Int {
        let usableWidth = plane.planeExtent.width - planeEdgeClearance * 2
        let usableDepth = plane.planeExtent.height - planeEdgeClearance * 2
        guard usableWidth >= 0, usableDepth >= 0 else { return 0 }

        let columns = max(Int(floor(usableWidth / minimumCheckpointSpacing)) + 1, 1)
        let rows = max(Int(floor(usableDepth / minimumCheckpointSpacing)) + 1, 1)
        return columns * rows
    }

    private func adaptiveCheckpointPositions(
        on plane: ARPlaneAnchor,
        meshObstacles: [SIMD3<Float>],
        verticalObstacles: [SIMD3<Float>]
    ) -> [SIMD2<Float>]? {
        let candidates = placementCandidates(on: plane).compactMap { point -> (SIMD2<Float>, Float)? in
            guard layoutIsClear(
                [point],
                meshObstacles: meshObstacles,
                verticalObstacles: verticalObstacles
            ) else { return nil }

            let clearance = layoutClearanceScore(
                [point],
                meshObstacles: meshObstacles,
                verticalObstacles: verticalObstacles
            )
            return (point, clearance)
        }
        guard candidates.count >= checkpoints.count else { return nil }

        guard let first = candidates.max(by: {
            firstCheckpointScore(point: $0.0, clearance: $0.1)
                < firstCheckpointScore(point: $1.0, clearance: $1.1)
        }) else { return nil }

        var selected = [first.0]
        while selected.count < checkpoints.count {
            let eligible = candidates.filter { candidate in
                guard !selected.contains(where: { simd_distance($0, candidate.0) < 0.08 }) else {
                    return false
                }
                return selected.allSatisfy {
                    simd_distance($0, candidate.0) >= minimumCheckpointSpacing
                }
            }
            guard !eligible.isEmpty else { return nil }

            let previous = selected[selected.count - 1]
            let reachable = eligible.filter {
                simd_distance(previous, $0.0) <= maximumCheckpointStepDistance
            }
            let pool = reachable.isEmpty ? eligible : reachable
            guard let next = pool.max(by: {
                nextCheckpointScore($0, after: previous, selected: selected)
                    < nextCheckpointScore($1, after: previous, selected: selected)
            }) else { return nil }
            selected.append(next.0)
        }
        return selected
    }

    private func placementCandidates(on plane: ARPlaneAnchor) -> [SIMD2<Float>] {
        let usableHalfWidth = plane.planeExtent.width / 2 - planeEdgeClearance
        let usableHalfDepth = plane.planeExtent.height / 2 - planeEdgeClearance
        guard usableHalfWidth >= 0, usableHalfDepth >= 0 else { return [] }

        let xOffsets = placementAxisOffsets(usableHalfExtent: usableHalfWidth)
        let zOffsets = placementAxisOffsets(usableHalfExtent: usableHalfDepth)
        return xOffsets.flatMap { xOffset in
            zOffsets.map { zOffset -> SIMD2<Float> in
                let local = SIMD4<Float>(
                    plane.center.x + xOffset,
                    0,
                    plane.center.z + zOffset,
                    1
                )
                let world = plane.transform * local
                return SIMD2<Float>(world.x, world.z)
            }
        }
    }

    private func placementAxisOffsets(usableHalfExtent: Float) -> [Float] {
        guard usableHalfExtent > 0.05 else { return [0] }

        let span = usableHalfExtent * 2
        let gridSpacing = minimumCheckpointSpacing * 0.5
        let segmentCount = max(Int(floor(span / gridSpacing)), 1)
        return (0...segmentCount).map { index in
            -usableHalfExtent + span * Float(index) / Float(segmentCount)
        }
    }

    private func firstCheckpointScore(point: SIMD2<Float>, clearance: Float) -> Float {
        guard let cameraPosition = latestCameraPositionXZ else { return clearance }

        let cameraOffset = point - cameraPosition
        let distance = simd_length(cameraOffset)
        let distanceScore = -abs(distance - firstCheckpointDistance)
        let directionScore: Float
        if let cameraForward = latestCameraForwardXZ, distance > 0.001 {
            directionScore = simd_dot(cameraOffset / distance, cameraForward)
        } else {
            directionScore = 0
        }
        return clearance * 0.7 + distanceScore * 0.65 + directionScore * 0.35
    }

    private func nextCheckpointScore(
        _ candidate: (SIMD2<Float>, Float),
        after previous: SIMD2<Float>,
        selected: [SIMD2<Float>]
    ) -> Float {
        let stepDistance = simd_distance(previous, candidate.0)
        let minimumSeparation = selected
            .map { simd_distance($0, candidate.0) }
            .min() ?? stepDistance
        return candidate.1 * 0.7
            - abs(stepDistance - preferredCheckpointSpacing) * 0.8
            + min(minimumSeparation, preferredCheckpointSpacing) * 0.2
    }

    private func layoutIsClear(
        _ positions: [SIMD2<Float>],
        meshObstacles: [SIMD3<Float>],
        verticalObstacles: [SIMD3<Float>]
    ) -> Bool {
        positions.allSatisfy { position in
            meshObstacles.allSatisfy {
                simd_distance(position, SIMD2<Float>($0.x, $0.z)) >= realObjectClearance
            } && verticalObstacles.allSatisfy {
                simd_distance(position, SIMD2<Float>($0.x, $0.z)) >= realObjectClearance
            }
        }
    }

    private func layoutClearanceScore(
        _ positions: [SIMD2<Float>],
        meshObstacles: [SIMD3<Float>],
        verticalObstacles: [SIMD3<Float>]
    ) -> Float {
        let obstacleXZ = meshObstacles.map { SIMD2<Float>($0.x, $0.z) }
            + verticalObstacles.map { SIMD2<Float>($0.x, $0.z) }
        guard !obstacleXZ.isEmpty else { return 3 }

        return positions
            .flatMap { position in obstacleXZ.map { simd_distance(position, $0) } }
            .min() ?? 0
    }

    private func obstaclePoints(for plane: ARPlaneAnchor) -> [SIMD3<Float>] {
        let sampleCount = 18
        let halfWidth = plane.planeExtent.width / 2
        return (0..<sampleCount).map { index in
            let fraction = Float(index) / Float(sampleCount - 1)
            let localX = plane.center.x - halfWidth + plane.planeExtent.width * fraction
            let local = SIMD4<Float>(localX, 0, plane.center.z, 1)
            let world = plane.transform * local
            return SIMD3<Float>(world.x, world.y, world.z)
        }
    }

    private func obstaclePoints(forHorizontalPlane plane: ARPlaneAnchor, above floorY: Float) -> [SIMD3<Float>] {
        let center = plane.center
        let worldCenter = plane.transform * SIMD4<Float>(center.x, 0, center.z, 1)
        guard worldCenter.y > floorY + 0.10, worldCenter.y < floorY + 1.8 else { return [] }

        let divisions = 4
        return (0...divisions).flatMap { xIndex in
            (0...divisions).map { zIndex in
                let xFraction = Float(xIndex) / Float(divisions) - 0.5
                let zFraction = Float(zIndex) / Float(divisions) - 0.5
                let local = SIMD4<Float>(
                    center.x + plane.planeExtent.width * xFraction,
                    0,
                    center.z + plane.planeExtent.height * zFraction,
                    1
                )
                let world = plane.transform * local
                return SIMD3<Float>(world.x, world.y, world.z)
            }
        }
    }

    private func sampledWorldVertices(from anchor: ARMeshAnchor) -> [SIMD3<Float>] {
        let source = anchor.geometry.vertices
        guard source.count > 0 else { return [] }
        let sampleStride = max(source.count / maximumMeshSamplesPerAnchor, 1)

        return stride(from: 0, to: source.count, by: sampleStride).map { index in
            let pointer = source.buffer.contents()
                .advanced(by: source.offset + source.stride * index)
                .assumingMemoryBound(to: SIMD3<Float>.self)
            let local = pointer.pointee
            let world = anchor.transform * SIMD4<Float>(local.x, local.y, local.z, 1)
            return SIMD3<Float>(world.x, world.y, world.z)
        }
    }

    func updateCameraPose(position: SIMD3<Float>, forward: SIMD3<Float>) {
        guard !isSceneFrozen else { return }

        latestCameraPositionXZ = SIMD2<Float>(position.x, position.z)
        let horizontalForward = SIMD2<Float>(forward.x, forward.z)
        let length = simd_length(horizontalForward)
        guard length > 0.0001 else { return }
        latestCameraForwardXZ = horizontalForward / length
        let normalizedForward = horizontalForward / length
        if phase == .scanningSurface {
            trackScannedHeading(normalizedForward)
        }
        if showsGuideOverlay {
            updateGuidePosition(cameraPosition: position, horizontalForward: normalizedForward)
        }
    }

    var guideOverlayWorldPosition: SIMD3<Float>? {
        guard showsGuideOverlay, !guideNeedsPlacement, let guide = guideRoot else { return nil }
        return guide.position(relativeTo: nil)
    }

    func updateGuideOverlayScreenPosition(_ position: CGPoint?) {
        guard screenPositionChanged(from: guideOverlayScreenPosition, to: position) else { return }
        guideOverlayScreenPosition = position
    }

    var textureTapObjectWorldPosition: SIMD3<Float>? {
        guard phase == .textureTapPrompt,
              let pathAnchor,
              let objectPosition = checkpointLocalPositions.first else { return nil }

        return pathAnchor.position(relativeTo: nil)
            + objectPosition
            + SIMD3<Float>(0, checkpointHeight * 0.55, 0)
    }

    func updateTextureTapObjectScreenPosition(_ position: CGPoint?) {
        guard screenPositionChanged(from: textureTapObjectScreenPosition, to: position) else { return }
        textureTapObjectScreenPosition = position
    }

    private func screenPositionChanged(from oldValue: CGPoint?, to newValue: CGPoint?) -> Bool {
        switch (oldValue, newValue) {
        case (nil, nil):
            return false
        case let (oldValue?, newValue?):
            let deltaX = oldValue.x - newValue.x
            let deltaY = oldValue.y - newValue.y
            return deltaX * deltaX + deltaY * deltaY >= 4
        default:
            return true
        }
    }

    func processCameraFrame(cameraTransform: simd_float4x4) {
        let position = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        let forward = -SIMD3<Float>(
            cameraTransform.columns.2.x,
            cameraTransform.columns.2.y,
            cameraTransform.columns.2.z
        )
        updateCameraPose(position: position, forward: forward)
        processSceneUpdate(cameraTransform: cameraTransform)
    }

    func processSceneUpdate(cameraTransform: simd_float4x4) {
        let isFindingFirstObject = phase == .onboarding && onboardingIndex == 2
        guard phase == .findingShapes || phase == .returningToFirstObject || isFindingFirstObject else { return }
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        checkProximity(cameraPosition: cameraPosition)
        updateDirectionIndicator(cameraTransform: cameraTransform, cameraPosition: cameraPosition)
    }

    func handleTap(on entity: Entity?) {
        guard !isTransitioning else { return }
        skipNarrationIfNeeded()

        if let target = radarTarget(for: entity) {
            tapRadarTarget(target)
        } else if phase == .textureTapPrompt, entityBelongsToLearningObject(entity) {
            objectTappedForTexture()
        } else if (phase == .textureExploration || phase == .shapeChange), entityBelongsToLearningObject(entity) {
            objectTappedDuringExperiment()
        } else {
            closeExperimentPanel()
            advanceNarrativeFromWorldTap()
        }
    }

    /// Dialog Lumi maju dengan tap di ruang AR. Saat sebuah marker tugas
    /// aktif, tap kosong sengaja tidak melakukan apa-apa sampai marker itu
    /// sendiri disentuh.
    private func advanceNarrativeFromWorldTap() {
        guard beginInteractionTransition() else { return }

        switch phase {
        case .onboarding:
            advanceDialog()
        case .lightShadowIntro where currentLightShadowInstruction.radarTarget == nil:
            continueLightShadowIntro()
        case .findingShapes where recentlyExplainedCheckpointIndex != nil:
            recentlyExplainedCheckpointIndex = nil
            if hasFoundAllShapes {
                phase = .returningToFirstObject
                currentCheckpointIndex = 0
                hasWaypointTarget = true
                lastArrivedIndex = nil
            } else {
                hasWaypointTarget = true
            }
            syncEntities()
        case .drawingPrompt:
            hidesGuideForDrawing = true
            phase = .drawingReady
            syncEntities()
        default:
            break
        }
    }

    func advanceDialog() {
        guard phase == .onboarding else { return }
        // Dialog "Coba cari objek…" adalah tugas waypoint. Ia tidak boleh
        // dilewati dengan tap kosong sebelum pemain benar-benar sampai.
        guard onboardingIndex != 2 || visitedCheckpoints.contains(0) else { return }

        if onboardingIndex == onboardingDialog.count - 1 {
            phase = .lightShadowIntro
            lightShadowIndex = 0
            hasWaypointTarget = false
            syncEntities()
        } else {
            onboardingIndex += 1
            if onboardingIndex == 2 {
                hasWaypointTarget = true
                syncEntities()
            }
        }
    }

    func startLessonAfterRoomScan() {
        guard phase == .surfaceReady else { return }
        phase = .onboarding
        onboardingIndex = 0
        hasWaypointTarget = false
        syncEntities()
    }

    func rescanSurface() {
        guard phase == .surfaceReady || phase == .scanningSurface else { return }
        pathAnchor?.removeFromParent()
        pathAnchor = nil
        checkpointLightEntities.removeAll()
        radarEntities.removeAll()
        radarWorldPositions.removeAll()
        radarLabelEntity = nil
        hasPlacedScene = false
        checkpointEntities.removeAll()
        checkpointLocalPositions.removeAll()
        markerWorldPositions.removeAll()
        checkpointHighlightEntities.removeAll()
        checkpointShadowEntities.removeAll()
        shadowReceiverManager.reset()
        guideNeedsPlacement = true
        guideRoot?.isEnabled = false
        hasWaypointTarget = false
        recentlyExplainedCheckpointIndex = nil
        hasContinuedToShapeSelection = false
        frozenSceneImage = nil
        userDrawingImage = nil
        showsPhotoComparisonPanel = false
        showsDrawingCamera = false
        showsFreezeSceneConfirmation = false
        isPreparingFrozenScene = false
        isSceneFrozen = false
        resetRoomScanTracking()
        phase = .scanningSurface
    }

    func continueLightShadowIntro() {
        guard phase == .lightShadowIntro else { return }
        if lightShadowIndex == lightShadowInstructions.count - 1 {
            phase = .findingShapes
            selectedRadarTarget = nil
            hasWaypointTarget = true
        } else {
            lightShadowIndex += 1
            selectedRadarTarget = nil
        }
        syncEntities()
    }

    /// Dua pilihan Figma dapat dibuka kapan saja setelah anak menyentuh
    /// objek. Keduanya tetap memakai entity RealityKit yang sama.
    func showTextureControls() {
        guard phase == .textureExploration || phase == .shapeChange else { return }
        phase = .textureExploration
        activeExperimentPanel = .texture
        hasOpenedTextureControls = true
        showsObjectModeBadge = true
        syncEntities()
    }

    func showShapeControls() {
        guard phase == .textureExploration || phase == .shapeChange else { return }
        phase = .shapeChange
        activeExperimentPanel = .shape
        hasOpenedShapeControls = true
        showsObjectModeBadge = true
        syncEntities()
    }

    func closeExperimentPanel() {
        guard phase == .textureExploration || phase == .shapeChange else { return }
        activeExperimentPanel = nil
        showsObjectModeBadge = false
    }

    var canContinueToShapeSelection: Bool {
        phase == .textureExploration && hasSelectedTexture && !hasContinuedToShapeSelection
    }

    var canConfirmDrawingChoices: Bool {
        phase == .shapeChange && hasSelectedTexture && hasSelectedShape
    }

    func continueToShapeSelection() {
        guard canContinueToShapeSelection else { return }
        phase = .shapeChange
        activeExperimentPanel = nil
        hasContinuedToShapeSelection = true
        hasOpenedShapeControls = false
        showsObjectModeBadge = true
        syncEntities()
    }

    func tapRadarTarget(_ target: Level1RadarTarget) {
        guard phase == .lightShadowIntro,
              currentLightShadowInstruction.radarTarget == target else { return }
        triggerSuccessFeedback()
        selectedRadarTarget = target
        if lightShadowIndex < lightShadowInstructions.count - 1 {
            lightShadowIndex += 1
        }
        syncEntities()
    }

    func continueToTextureLesson() {
        guard (phase == .findingShapes || phase == .returningToFirstObject), hasFoundAllShapes else { return }
        phase = .textureTapPrompt
        currentCheckpointIndex = 0
        currentTextureIndex = 0
        visitedTextures = [0]
        activeExperimentPanel = nil
        hasSelectedTexture = false
        hasSelectedShape = false
        hasOpenedTextureControls = false
        hasOpenedShapeControls = false
        hasContinuedToShapeSelection = false
        showsObjectModeBadge = false
        hasWaypointTarget = false
        syncEntities()
    }

    func objectTappedDuringExperiment() {
        guard phase == .textureExploration || phase == .shapeChange else { return }
        showsObjectModeBadge = true
        syncEntities()
    }

    func objectTappedForTexture() {
        guard phase == .textureTapPrompt else { return }
        showsObjectModeBadge = true
        activeExperimentPanel = nil
        hasOpenedTextureControls = false
        phase = .textureExploration
        triggerSuccessFeedback()
        syncEntities()
    }

    func selectTexture(at index: Int) {
        guard phase == .textureExploration, textureStops.indices.contains(index) else { return }
        currentTextureIndex = index
        visitedTextures.insert(index)
        hasSelectedTexture = true
        triggerSuccessFeedback()
        applyCurrentTextureToPrimaryObject()
        syncEntities()
    }

    func startShapeChange() {
        guard phase == .textureExploration else { return }
        phase = .shapeChange
        activeExperimentPanel = .shape
        showsObjectModeBadge = true
        syncEntities()
    }

    func selectShape(at index: Int) {
        guard phase == .shapeChange, shapeOptions.indices.contains(index) else { return }
        selectedShapeIndex = index
        hasSelectedShape = true
        hasChangedShape = index != 0
        triggerSuccessFeedback()
        applyCurrentShapeToPrimaryObject()
        syncEntities()
    }

    func confirmDrawingChoices() {
        guard (phase == .textureExploration || phase == .shapeChange), canConfirmDrawingChoices else { return }
        showsFreezeSceneConfirmation = true
    }

    func cancelFreezeSceneConfirmation() {
        guard !isPreparingFrozenScene else { return }
        showsFreezeSceneConfirmation = false
    }

    func confirmFreezeSceneAndStartDrawing() {
        guard (phase == .textureExploration || phase == .shapeChange), canConfirmDrawingChoices else {
            showsFreezeSceneConfirmation = false
            isPreparingFrozenScene = false
            return
        }

        isPreparingFrozenScene = true
        freezeSceneAndStartDrawing()
    }

    private func freezeSceneAndStartDrawing() {
        guard (phase == .textureExploration || phase == .shapeChange), canConfirmDrawingChoices else {
            showsFreezeSceneConfirmation = false
            isPreparingFrozenScene = false
            return
        }

        showsFreezeSceneConfirmation = false
        isPreparingFrozenScene = false
        activeExperimentPanel = nil
        showsObjectModeBadge = false
        hidesGuideForDrawing = false
        isSceneFrozen = true
        phase = .drawingPrompt
        triggerSuccessFeedback()
        syncEntities()
    }

    func finishDrawing() {
        guard (phase == .drawingReady || phase == .drawingActive), isNarrationComplete else { return }
        hidesGuideForDrawing = false
        phase = .photoPrompt
        triggerSuccessFeedback()
        syncEntities()
    }

    func captureDrawingPhoto() {
        guard phase == .photoPrompt, isNarrationComplete, !isSavingDrawingPhoto else { return }
        isSavingDrawingPhoto = true
        pendingDrawingPhotoCapture.toggle()
    }

    func completeFrozenSceneSnapshot(success: Bool, image: UIImage?, message: String?) {
        isSavingDrawingPhoto = false
        guard success, let image else {
            photoSaveMessage = message
            syncEntities()
            return
        }

        frozenSceneImage = image
        showsDrawingCamera = true
        syncEntities()
    }

    func cancelDrawingCamera() {
        showsDrawingCamera = false
    }

    func completeUserDrawingPhoto(_ image: UIImage) {
        showsDrawingCamera = false
        isSavingDrawingPhoto = true
        saveImageToPhotoLibrary(image) { [weak self] success, message in
            guard let self else { return }
            self.isSavingDrawingPhoto = false
            guard success else {
                self.photoSaveMessage = message
                return
            }

            self.userDrawingImage = image
            self.hidesGuideForDrawing = false
            self.showsPhotoComparisonPanel = false
            self.phase = .photoComparison
            self.triggerSuccessFeedback()
            self.syncEntities()
        }
    }

    func showPhotoComparisonPanel() {
        guard phase == .photoComparison, isNarrationComplete else { return }
        showsPhotoComparisonPanel = true
    }

    func hidePhotoComparisonPanel() {
        guard phase == .photoComparison else { return }
        showsPhotoComparisonPanel = false
    }

    func completeLevelAfterPhotoComparison() {
        guard phase == .photoComparison else { return }
        showsPhotoComparisonPanel = false
        phase = .completed
        progressStore.markLevelCompleted(Level1Content.levelID)
        triggerSuccessFeedback()
        syncEntities()
    }

    func clearPhotoSaveMessage() {
        photoSaveMessage = nil
    }

    func narrationWillStart(id: String) {
        activeNarrationID = id
        isNarrationComplete = false
    }

    func narrationDidFinish(id: String) {
        guard activeNarrationID == id else { return }
        isNarrationComplete = true
    }

    /// Stops narration audio still playing and marks it complete, so a tap
    /// can skip straight to the action instead of waiting for it to finish.
    func skipNarrationIfNeeded() {
        guard !isNarrationComplete else { return }
        onNarrationSkipRequested?()
        isNarrationComplete = true
    }

    var showsTapToContinueCaption: Bool {
        guard !isTransitioning else { return false }

        switch phase {
        case .onboarding:
            return onboardingIndex != 2 || visitedCheckpoints.contains(0)
        case .lightShadowIntro:
            return currentLightShadowInstruction.radarTarget == nil
        case .findingShapes:
            return recentlyExplainedCheckpointIndex != nil
        case .drawingPrompt:
            return true
        default:
            return false
        }
    }

    var canGoBackToPreviousState: Bool {
        if showsPhotoComparisonPanel { return true }

        switch phase {
        case .scanningSurface, .surfaceReady, .completed:
            return false
        case .onboarding:
            return onboardingIndex > 0
        default:
            return true
        }
    }

    /// Mundur satu langkah pembelajaran tanpa membuat ulang anchor atau
    /// mereset tracking AR yang sudah ditemukan.
    func goBackToPreviousState() {
        guard canGoBackToPreviousState, beginInteractionTransition() else { return }

        if showsPhotoComparisonPanel {
            showsPhotoComparisonPanel = false
            endInteractionTransition()
            return
        }

        switch phase {
        case .onboarding:
            if onboardingIndex == 3, visitedCheckpoints.contains(0) {
                // Ulangi pencarian kubus, bukan hanya kembali ke caption yang
                // sudah dapat langsung dilewati.
                visitedCheckpoints.remove(0)
                onboardingIndex = 2
                currentCheckpointIndex = 0
                hasWaypointTarget = true
                lastArrivedIndex = 0
            } else {
                onboardingIndex = previousOnboardingIndex
                hasWaypointTarget = onboardingIndex == 2 && !visitedCheckpoints.contains(0)
            }
        case .lightShadowIntro:
            if lightShadowIndex > 0 {
                lightShadowIndex -= 1
            } else {
                phase = .onboarding
                onboardingIndex = onboardingDialog.count - 1
            }
            selectedRadarTarget = nil
            hasWaypointTarget = false
        case .findingShapes:
            goBackFromFindingShapes()
        case .returningToFirstObject:
            restoreLatestShapeExplanation()
        case .textureTapPrompt:
            // Action tepat sebelum prompt tekstur adalah berjalan kembali ke
            // kubus pertama. Tahan proximity sampai pemain keluar dari marker
            // agar state tidak maju otomatis pada frame berikutnya.
            phase = .returningToFirstObject
            currentCheckpointIndex = 0
            recentlyExplainedCheckpointIndex = nil
            hasWaypointTarget = true
            lastArrivedIndex = 0
        case .textureExploration:
            phase = .textureTapPrompt
            activeExperimentPanel = nil
            showsObjectModeBadge = false
        case .shapeChange:
            phase = .textureExploration
            selectedShapeIndex = 0
            hasSelectedShape = false
            hasChangedShape = false
            hasContinuedToShapeSelection = false
            activeExperimentPanel = .texture
            showsObjectModeBadge = true
            applyCurrentShapeToPrimaryObject()
        case .drawingPrompt:
            phase = .shapeChange
            isSceneFrozen = false
            hidesGuideForDrawing = false
            activeExperimentPanel = nil
            showsObjectModeBadge = true
        case .drawingReady, .drawingActive:
            phase = .drawingPrompt
            hidesGuideForDrawing = false
        case .photoPrompt:
            phase = .drawingReady
            hidesGuideForDrawing = true
        case .photoComparison:
            phase = .photoPrompt
            hidesGuideForDrawing = false
        case .scanningSurface, .surfaceReady, .completed:
            break
        }

        isNarrationComplete = false
        syncEntities()
    }

    private func goBackFromFindingShapes() {
        if let explainedIndex = recentlyExplainedCheckpointIndex,
           explainedIndex > 0 {
            // Dari penjelasan bentuk, kembali ke tugas mencari bentuk yang sama.
            visitedCheckpoints.remove(explainedIndex)
            recentlyExplainedCheckpointIndex = nil
            currentCheckpointIndex = max(explainedIndex - 1, 0)
            hasWaypointTarget = true
            lastArrivedIndex = explainedIndex
            return
        }

        if let latestDiscoveredIndex = latestDiscoveredShapeIndex {
            // Dari tugas mencari target berikutnya, kembali satu langkah ke
            // penjelasan bentuk yang barusan ditemukan.
            currentCheckpointIndex = latestDiscoveredIndex
            recentlyExplainedCheckpointIndex = latestDiscoveredIndex
            hasWaypointTarget = false
            lastArrivedIndex = latestDiscoveredIndex
            return
        }

        // Belum ada bentuk tambahan yang ditemukan: action sebelumnya memang
        // merupakan penutup pengenalan cahaya dan bayangan.
        phase = .lightShadowIntro
        lightShadowIndex = lightShadowInstructions.count - 1
        recentlyExplainedCheckpointIndex = nil
        selectedRadarTarget = nil
        hasWaypointTarget = false
    }

    private func restoreLatestShapeExplanation() {
        guard let latestDiscoveredIndex = latestDiscoveredShapeIndex else {
            phase = .findingShapes
            recentlyExplainedCheckpointIndex = nil
            hasWaypointTarget = true
            return
        }

        phase = .findingShapes
        currentCheckpointIndex = latestDiscoveredIndex
        recentlyExplainedCheckpointIndex = latestDiscoveredIndex
        hasWaypointTarget = false
        lastArrivedIndex = latestDiscoveredIndex
    }

    #if DEBUG
    func jumpToDevFlow(_ flow: Level1DevFlow) {
        if !hasPlacedScene {
            placeScene(using: debugRoomPlacement())
        }

        selectedRadarTarget = nil
        activeExperimentPanel = nil
        showsObjectModeBadge = false
        hasWaypointTarget = false
        recentlyExplainedCheckpointIndex = nil
        isSceneFrozen = false
        showsFreezeSceneConfirmation = false
        isPreparingFrozenScene = false
        showsDrawingCamera = false
        showsPhotoComparisonPanel = false
        guideNeedsPlacement = true

        switch flow {
        case .onboarding:
            phase = .onboarding
            onboardingIndex = 0
            visitedCheckpoints.removeAll()
        case .lightShadowIntro:
            phase = .lightShadowIntro
            lightShadowIndex = 0
            visitedCheckpoints = [0]
        case .findingShapes:
            phase = .findingShapes
            visitedCheckpoints = [0]
            currentCheckpointIndex = 1
            hasWaypointTarget = true
        case .textureTapPrompt:
            phase = .textureTapPrompt
            currentCheckpointIndex = 0
            visitedCheckpoints = Set(checkpoints.indices)
        case .textureExploration:
            phase = .textureExploration
            currentCheckpointIndex = 0
            currentTextureIndex = 0
            visitedCheckpoints = Set(checkpoints.indices)
            hasSelectedTexture = false
            hasOpenedTextureControls = false
            showsObjectModeBadge = true
        case .shapeChange:
            phase = .shapeChange
            currentCheckpointIndex = 0
            currentTextureIndex = min(1, textureStops.count - 1)
            selectedShapeIndex = 0
            visitedCheckpoints = Set(checkpoints.indices)
            hasSelectedTexture = true
            hasSelectedShape = false
            hasOpenedShapeControls = false
            showsObjectModeBadge = true
            applyCurrentTextureToPrimaryObject()
        case .drawingPrompt:
            phase = .drawingPrompt
            visitedCheckpoints = Set(checkpoints.indices)
            hasSelectedTexture = true
            hasSelectedShape = true
        case .photoPrompt:
            phase = .photoPrompt
            visitedCheckpoints = Set(checkpoints.indices)
            hasSelectedTexture = true
            hasSelectedShape = true
        case .completed:
            phase = .completed
            visitedCheckpoints = Set(checkpoints.indices)
        }

        syncEntities()
    }
    #endif

    private func saveImageToPhotoLibrary(_ image: UIImage, completion: @escaping (Bool, String?) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            switch status {
            case .authorized, .limited:
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                } completionHandler: { success, error in
                    Task { @MainActor in
                        completion(success, success ? nil : "Foto belum tersimpan. \(error?.localizedDescription ?? "")")
                    }
                }
            default:
                Task { @MainActor in
                    completion(false, "Izinkan akses Photos untuk menyimpan foto.")
                }
            }
        }
    }

    var currentDialogLine: DialogLine { onboardingDialog[onboardingIndex] }
    var isLastDialogLine: Bool { onboardingIndex == onboardingDialog.count - 1 }
    var currentLightShadowInstruction: Level1Instruction { lightShadowInstructions[lightShadowIndex] }
    var currentCheckpoint: Checkpoint { checkpoints[currentCheckpointIndex] }
    var currentTexture: TextureStop { textureStops[currentTextureIndex] }
    var selectedShape: GameShape { shapeOptions[selectedShapeIndex] }
    var hasFoundAllShapes: Bool { checkpoints.indices.allSatisfy { visitedCheckpoints.contains($0) } }
    var hasExploredAllTextures: Bool { textureStops.indices.allSatisfy { visitedTextures.contains($0) } }
    var showsExperimentControls: Bool {
        (phase == .textureExploration || phase == .shapeChange)
            && (showsObjectModeBadge || activeExperimentPanel != nil)
    }
    var showsTextureControlGesture: Bool { phase == .textureExploration && !hasOpenedTextureControls }
    var showsShapeControlGesture: Bool { phase == .shapeChange && !hasOpenedShapeControls }

    private var previousOnboardingIndex: Int {
        return max(onboardingIndex - 1, 0)
    }

    private var latestDiscoveredShapeIndex: Int? {
        visitedCheckpoints
            .filter { $0 > 0 }
            .max()
    }

    var nextTargetCheckpointIndex: Int? {
        if phase == .onboarding, onboardingIndex == 2, !visitedCheckpoints.contains(0) {
            return 0
        }
        if phase == .returningToFirstObject {
            return 0
        }
        guard phase == .findingShapes else { return nil }
        if recentlyExplainedCheckpointIndex != nil { return nil }
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
            findingShapeNarrationText
        case .returningToFirstObject:
            "Ayo kembali ke kubus pertama!"
        case .textureTapPrompt:
            "Coba tekan sekali kotaknya! Kita lihat tekstur yang lain ya!"
        case .textureExploration:
            hasSelectedTexture ? currentTexture.description : "Kamu bisa ganti tekstur yang kamu suka, lho."
        case .shapeChange:
            hasSelectedShape
                ? "Yuk, arahkan kameramu ke bendanya dulu sebelum mulai menggambar!"
                : "Kamu bisa ganti bentuk yang kamu suka, lho."
        case .drawingPrompt:
            "Simsalabim! Gambarnya kita bikin diam ya, biar gampang digambar!"
        case .drawingReady, .drawingActive:
            "Kalau sudah, tekan tombol ini ya!"
        case .photoPrompt:
            "Yeay, gambarmu sudah jadi! Sekarang, yuk foto gambarmu!"
        case .photoComparison:
            "Keren! Gambarmu sudah tersimpan."
        case .completed:
            "Level 1 selesai. Kamu hebat! Sekarang kamu bisa ke level berikutnya!"
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
            findingShapeNarrationAudioFileName
        case .returningToFirstObject:
            "level-1/26 Sekarang, yuk kita balik lagi ke bentuk kubus! Masih ingat kan bentuknya?.mp3"
        case .textureTapPrompt:
            "level-1/14 Coba tekan sekali kotaknya Kita lihat tekstur yang lain yaa.mp3"
        case .textureExploration:
            hasSelectedTexture
                ? currentTexture.audioFileName
                : "level-1/19 Kamu bisa ganti bentuk dan tekstur yang kamu suka lho.mp3"
        case .shapeChange:
            hasSelectedShape
                ? "level-1/27 Yuk, arahkan kameramu ke bendanya dulu sebelum mulai menggambar!.mp3"
                : "level-1/15 Wah ada banyak bentuk Kamu bisa ganti bentuk yang lain lho.mp3"
        case .drawingPrompt:
            "level-1/28 Simsalabim! Gambarnya kita bikin diam ya, biar gampang digambar!.mp3"
        case .drawingReady, .drawingActive:
            "level-1/22 Kalau sudah tekan tombol ini ya.mp3"
        case .photoPrompt:
            "level-1/23 Yeay gambarmu sudah jadi Sekarang yuk foto gambarmu.mp3"
        case .photoComparison:
            "level-1/24 Keren Gambarmu sudah tersimpan.mp3"
        case .completed:
            "level-1/29 Level 1 selesai. Kamu hebat! Sekarang kamu bisa ke level berikutnya!.mp3"
        }
    }

    private var findingShapeNarrationText: String {
        if let foundIndex = recentlyExplainedCheckpointIndex, checkpoints.indices.contains(foundIndex) {
            return explanationText(for: checkpoints[foundIndex].shape)
        }

        if hasFoundAllShapes {
            return "Wah, semua bentuk sudah kamu temukan!"
        }

        guard let targetIndex = nextTargetCheckpointIndex else {
            return "Selain kotak, coba temukan bentuk yang lain di sekitarmu!"
        }
        return searchPromptText(for: checkpoints[targetIndex].shape)
    }

    private var findingShapeNarrationAudioFileName: String? {
        if let foundIndex = recentlyExplainedCheckpointIndex, checkpoints.indices.contains(foundIndex) {
            return explanationAudioFileName(for: checkpoints[foundIndex].shape)
        }

        if hasFoundAllShapes {
            return "level-1/25 Wah, semua bentuk sudah kamu temukan!.mp3"
        }

        guard let targetIndex = nextTargetCheckpointIndex else {
            return "level-1/12 Selain kotak coba temukan bentuk yang lain di sekitarmu.mp3"
        }
        return searchPromptAudioFileName(for: checkpoints[targetIndex].shape)
    }

    private func searchPromptText(for shape: GameShape) -> String {
        switch shape.id {
        case "balok":
            return "Yuk, cari bentuk balok di sekitarmu!"
        case "bola":
            return "Coba cari bentuk bola yang bulat sempurna di sekitarmu!"
        case "piramida":
            return "Coba cari bentuk piramida! Runcing ke atas seperti tenda, kan?"
        case "kerucut":
            return "Coba cari kerucut! Bawahnya bulat, tapi atasnya lancip!"
        case "tabung":
            return "Coba cari bentuk tabung! Seperti celengan yang memanjang ke atas!"
        default:
            return "Coba cari objek berbentuk kotak di sekitarmu!"
        }
    }

    private func searchPromptAudioFileName(for shape: GameShape) -> String? {
        switch shape.id {
        case "balok":
            return "level-1/bentuk/[balok] Yuk, cari bentuk balok di sekitarmu!.mp3"
        case "bola":
            return "level-1/bentuk/[bola] Coba cari bentuk bola yang bulat sempurna di sekitarmu!.mp3"
        case "piramida":
            return "level-1/bentuk/[piramida] Coba cari bentuk piramida! Runcing ke atas seperti tenda, kan_.mp3"
        case "kerucut":
            return "level-1/bentuk/[Kerucut] Coba cari kerucut! Bawahnya bulat, tapi atasnya lancip!.mp3"
        case "tabung":
            return "level-1/bentuk/[tabung] Coba cari bentuk tabung! Seperti celengan yang memanjang ke atas!.mp3"
        default:
            return "level-1/3 coba cari objek berbentuk kotak di sekitarmu.mp3"
        }
    }

    private func explanationText(for shape: GameShape) -> String {
        switch shape.id {
        case "kubus":
            return "Ini Kubus! Semua sisinya sama besar, lho!"
        case "balok":
            return "Ini Balok! Sisi yang berhadapan sama bentuk dan ukurannya."
        case "bola":
            return "Ini Bola! Bentuknya bulat sempurna tanpa titik sudut."
        case "piramida":
            return "Ini Piramida! Bawahnya datar dan puncaknya runcing."
        case "kerucut":
            return "Ini Kerucut! Alasnya lingkaran dan atasnya lancip."
        case "tabung":
            return "Ini Tabung! Alas dan tutupnya berbentuk lingkaran."
        default:
            return "Ini \(shape.displayName)!"
        }
    }

    private func explanationAudioFileName(for shape: GameShape) -> String? {
        switch shape.id {
        case "kubus":
            return "level-1/marker/objek/[kubus] Ini Kubus Semua sisinya sama besar lho.mp3"
        case "balok":
            return "level-1/marker/objek/[balok] Ini Balok! Sisi yang saling berhadapan, bentuk dan ukurannya sama persis, lho!.mp3"
        case "bola":
            return "level-1/marker/objek/[bola] Ini Bola! Bentuknya bulat sempurna dan tidak punya titik sudut sama sekali, lho!.mp3"
        case "piramida":
            return "level-1/marker/objek/[piramida] Ini Piramida! Bawahnya datar dan punya titik puncak yang runcing di atas, lho!.mp3"
        case "kerucut":
            return "level-1/marker/objek/[kerucut] Ini Kerucut! Alasnya berbentuk lingkaran dan atasnya lancip seperti topi ulang tahun, lho!.mp3"
        case "tabung":
            return "level-1/marker/objek/[tabung] Ini Tabung! Alas dan tutupnya berbentuk lingkaran yang ukurannya sama besar, lho!.mp3"
        default:
            return nil
        }
    }

    var narrationID: String {
        let phaseID: String
        switch phase {
        case .drawingActive:
            phaseID = "\(Level1Phase.drawingReady)"
        default:
            phaseID = "\(phase)"
        }

        let choiceID: String
        switch phase {
        case .textureExploration:
            choiceID = "texture-\(currentTextureIndex)"
        case .shapeChange:
            choiceID = "shape-\(selectedShapeIndex)"
        default:
            choiceID = "none"
        }

        let discoveryID = "found-\(visitedCheckpoints.count)-explaining-\(recentlyExplainedCheckpointIndex ?? -1)-target-\(nextTargetCheckpointIndex ?? -1)"
        return "\(phaseID)-\(onboardingIndex)-\(lightShadowIndex)-\(currentCheckpointIndex)-\(hasFoundAllShapes)-\(hasSelectedTexture)-\(hasSelectedShape)-\(choiceID)-\(discoveryID)"
    }

    private func placeScene(using placement: Level1RoomPlacement) {
        guard !hasPlacedScene,
              placement.checkpointXZ.count == checkpoints.count,
              let root = rootAnchor else { return }
        hasPlacedScene = true

        let floorY = placement.floorY
        let pathCenterXZ = placement.centerXZ

        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4<Float>(pathCenterXZ.x, floorY, pathCenterXZ.y, 1)
        let anchorGroup = AnchorEntity(world: matrix)
        root.addChild(anchorGroup)
        pathAnchor = anchorGroup
        shadowReceiverManager.setupReceiver(on: anchorGroup, usesFlatFallback: true, surfaceTexture: .defaultGrid)

        for (index, checkpoint) in checkpoints.enumerated() {
            let shapeXZ = placement.checkpointXZ[index]
            let worldPosition = SIMD3<Float>(shapeXZ.x, floorY + 0.005, shapeXZ.y)
            markerWorldPositions.append(worldPosition)

            let localPosition = SIMD3<Float>(shapeXZ.x - pathCenterXZ.x, 0, shapeXZ.y - pathCenterXZ.y)
            checkpointLocalPositions.append(localPosition)

            let shapeEntity = makeCheckpointEntity(for: checkpoint)
            shapeEntity.name = "level1-object-\(checkpoint.shape.id)"
            shapeEntity.position += localPosition
            checkpointEntities.append(shapeEntity)
            anchorGroup.addChild(shapeEntity)

            let lightPosition = localPosition + lightOffset(for: checkpoint.shape.objectType)
            let lightTarget = localPosition + SIMD3<Float>(0, checkpointHeight * 0.55, 0)
            let lightEntity = makeLightEntity(from: lightPosition, aimingAt: lightTarget)
            checkpointLightEntities.append(lightEntity)
            anchorGroup.addChild(lightEntity)

            let shadowEntity = Level1ShadowRenderer.makeEntity(
                name: "Level 1 projected shadow — \(checkpoint.shape.id)"
            )
            Level1ShadowRenderer.update(
                shadowEntity,
                objectType: checkpoint.shape.objectType,
                objectPosition: localPosition,
                objectDimensions: scaledObjectDimensions(for: checkpoint.shape.objectType),
                lightPosition: lightPosition,
                texture: checkpoint.shape.textures[0].material
            )
            checkpointShadowEntities.append(shadowEntity)
            anchorGroup.addChild(shadowEntity)

            // Checkpoint floor ring sengaja tidak dibuat: Level 1 sekarang
            // fokus pada cahaya, bayangan berbasis geometri, dan objek uji yang sama.
        }

        let primaryObjectPosition = checkpointLocalPositions.first ?? .zero
        let primaryLightPosition = checkpointLightEntities.first?.position ?? primaryObjectPosition + lightOffset(for: .cube)
        let primaryShadowPosition = estimatedShadowPosition(
            objectPosition: primaryObjectPosition,
            lightPosition: primaryLightPosition,
            objectType: checkpoints.first?.shape.objectType ?? .cube
        )
        let objectTargetPosition = primaryObjectPosition + SIMD3<Float>(0, checkpointHeight * 0.62, 0)
        let radarPositions: [Level1RadarTarget: (target: SIMD3<Float>, marker: SIMD3<Float>)] = [
            .light: (
                primaryLightPosition,
                primaryLightPosition
            ),
            .shadow: (
                primaryShadowPosition + SIMD3<Float>(0, 0.025, 0),
                primaryShadowPosition + diagonalMarkerOffset(direction: SIMD3<Float>(-1, 1, 1), distance: 0.40)
            ),
            .object: (
                objectTargetPosition,
                objectTargetPosition + diagonalMarkerOffset(direction: SIMD3<Float>(1, 1, 1), distance: 0.40)
            )
        ]
        for (target, positions) in radarPositions {
            let radar = makeRadarEntity(target: target)
            radar.position = positions.marker
            if target != .light {
                radar.addChild(makeDashedLeader(toward: positions.target - positions.marker))
            }
            radarEntities[target] = radar
            radarWorldPositions[target] = SIMD3<Float>(
                pathCenterXZ.x + positions.marker.x,
                floorY + positions.marker.y,
                pathCenterXZ.y + positions.marker.z
            )
            anchorGroup.addChild(radar)
        }

        syncEntities()
    }

    #if DEBUG
    private func debugRoomPlacement() -> Level1RoomPlacement {
        let cameraXZ = latestCameraPositionXZ ?? .zero
        let forwardXZ = latestCameraForwardXZ ?? SIMD2<Float>(0, -1)
        let rightXZ = SIMD2<Float>(-forwardXZ.y, forwardXZ.x)
        let positions = checkpoints.indices.map { index in
            let forwardDistance = firstCheckpointDistance + Float(index) * preferredCheckpointSpacing
            let sideOffset: Float = index.isMultiple(of: 2) ? -0.28 : 0.28
            return cameraXZ + forwardXZ * forwardDistance + rightXZ * sideOffset
        }
        let centerXZ = positions.reduce(SIMD2<Float>.zero, +) / Float(positions.count)
        return Level1RoomPlacement(centerXZ: centerXZ, floorY: -1.2, checkpointXZ: positions)
    }
    #endif

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
        if phase == .returningToFirstObject, index == 0 {
            currentCheckpointIndex = 0
            hasWaypointTarget = false
            triggerSuccessFeedback()
            continueToTextureLesson()
            return
        }

        guard checkpoints.indices.contains(index), !visitedCheckpoints.contains(index) else { return }
        currentCheckpointIndex = index
        visitedCheckpoints.insert(index)
        triggerSuccessFeedback()
        if phase == .onboarding {
            // Setelah anak mencapai lokasi waypoint, kubus baru ditampilkan
            // bersama dialog "Yeay ketemu!". Lampu tetap belum menyala.
            onboardingIndex = min(onboardingDialog.count - 1, 3)
            hasWaypointTarget = false
            syncEntities()
            return
        }
        recentlyExplainedCheckpointIndex = index
        hasWaypointTarget = false
        syncEntities()
    }

    func syncEntities() {
        syncGuidePresentation()
        moveGuideIfNeeded()
        let showLightAndShadow = phase != .onboarding
            && phase != .scanningSurface
            && phase != .surfaceReady

        for (index, entity) in checkpointEntities.enumerated() {
            switch phase {
            case .onboarding:
                entity.isEnabled = index == 0
            case .lightShadowIntro:
                entity.isEnabled = index == 0
            case .findingShapes:
                entity.isEnabled = visitedCheckpoints.contains(index) || index == nextTargetCheckpointIndex
            case .returningToFirstObject:
                entity.isEnabled = index == 0
            case .textureTapPrompt, .textureExploration, .shapeChange, .drawingPrompt, .drawingReady, .drawingActive, .photoPrompt, .photoComparison, .completed:
                entity.isEnabled = index == 0
            case .scanningSurface, .surfaceReady:
                entity.isEnabled = false
            }
        }

        for (index, light) in checkpointLightEntities.enumerated() {
            light.isEnabled = showLightAndShadow && (checkpointEntities[safe: index]?.isEnabled == true)
        }

        for (index, shadow) in checkpointShadowEntities.enumerated() {
            shadow.isEnabled = showLightAndShadow && (checkpointEntities[safe: index]?.isEnabled == true)
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
        let targetOffset = SIMD3<Float>(
            targetPosition.x - cameraPosition.x,
            0,
            targetPosition.z - cameraPosition.z
        )
        let targetDistance = simd_length(targetOffset)
        let targetDirection = targetDistance > 0.0001 ? targetOffset / targetDistance : normalizedForward
        let cameraRight = SIMD3<Float>(-normalizedForward.z, 0, normalizedForward.x)
        let directionCaption = directionCaption(
            forwardAlignment: simd_dot(targetDirection, normalizedForward),
            rightAlignment: simd_dot(targetDirection, cameraRight)
        )
        let dx = cameraPosition.x - targetPosition.x
        let dz = cameraPosition.z - targetPosition.z
        let distanceMeters = sqrt(dx * dx + dz * dz)
        let time = Float(CACurrentMediaTime())
        let position = cameraPosition
            + normalizedForward * (max(0.3, min(1.15, distanceMeters - 0.4)) + sin(time * 2.4) * 0.10)
            + SIMD3<Float>(0, -0.35 + sin(time * 2.0) * 0.015, 0)

        root.look(at: SIMD3<Float>(targetPosition.x, position.y, targetPosition.z), from: position, relativeTo: nil)
        updateIndicatorDistanceLabel(
            meters: Double(distanceMeters),
            directionCaption: directionCaption,
            parent: root
        )
    }

    private func triggerSuccessFeedback() {
        successFeedbackTrigger += 1
        hapticGenerator.notificationOccurred(.success)
        hapticGenerator.prepare()
    }

    private func beginInteractionTransition() -> Bool {
        guard !isTransitioning else { return false }

        isTransitioning = true
        transitionGateTask?.cancel()
        transitionGateTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: transitionDebounceDuration)
            guard !Task.isCancelled else { return }
            isTransitioning = false
            transitionGateTask = nil
        }
        return true
    }

    private func endInteractionTransition() {
        transitionGateTask?.cancel()
        transitionGateTask = nil
        isTransitioning = false
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
        entity.components.set(
            DynamicLightShadowComponent(castsShadow: currentTexture.material.shadowBehavior != .cutout)
        )
        refreshPrimaryShadowVisual()
    }

    private func applyCurrentShapeToPrimaryObject() {
        guard let entity = checkpointEntities.first else { return }
        let replacement = SceneObjectSystem.makeObject(type: selectedShape.objectType, texture: currentTexture.material)
        entity.model = replacement.model
        entity.collision = replacement.collision
        let finalScale = checkpointHeight / SceneObjectSystem.baseDimensions(for: selectedShape.objectType).y
        entity.components.set(
            DynamicLightShadowComponent(castsShadow: currentTexture.material.shadowBehavior != .cutout)
        )
        entity.scale = SIMD3<Float>(repeating: finalScale)
        refreshPrimaryShadowVisual()
    }

    private func refreshPrimaryShadowVisual() {
        guard let shadow = checkpointShadowEntities.first,
              let objectPosition = checkpointLocalPositions.first,
              let lightPosition = checkpointLightEntities.first?.position else { return }

        Level1ShadowRenderer.update(
            shadow,
            objectType: selectedShape.objectType,
            objectPosition: objectPosition,
            objectDimensions: scaledObjectDimensions(for: selectedShape.objectType),
            lightPosition: lightPosition,
            texture: currentTexture.material
        )
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
            let isVisible = activeTarget == target || explainedTarget == target
            entity.isEnabled = isVisible
            updateRadarAppearance(entity, isSelected: explainedTarget == target)
        }

        radarLabelEntity?.removeFromParent()
        radarLabelEntity = nil

        // Penjelasan setelah marker ditekan ditampilkan lewat bubble Lumi.
        // Label marker terpisah sengaja tidak dibuat agar dialog tidak duplikat.
    }

    private func updateRadarAppearance(_ entity: Entity, isSelected: Bool) {
        guard let center = entity.children.first(where: { $0.name.contains("-center") }) as? ModelEntity,
              let ring = entity.children.first(where: { $0.name.contains("-ring") }) as? ModelEntity else { return }

        let tint = isSelected
            ? markerPalette.selected
            : markerPalette.primary
        center.model?.materials = [UnlitMaterial(color: tint)]
        ring.model?.materials = [EducationalMarkerStyle.ringMaterial(alpha: 1.0, tint: tint)]

        if isSelected {
            center.components.set(PulseAnimationComponent(baseScale: 1, speed: 5.0, amplitude: 0.35, isActiveTarget: true))
        } else {
            center.components.remove(PulseAnimationComponent.self)
            center.scale = SIMD3<Float>(repeating: 1)
        }
    }

    func markerSurfaceToneDidChange(_ tone: EducationalMarkerStyle.SurfaceTone) {
        guard markerSurfaceTone != tone else { return }
        markerSurfaceTone = tone

        let explainedTarget = phase == .lightShadowIntro
            && currentLightShadowInstruction.radarTarget == nil
            ? selectedRadarTarget
            : nil
        for (target, entity) in radarEntities {
            updateRadarAppearance(entity, isSelected: explainedTarget == target)
            refreshConnectorMaterials(in: entity)
        }
        checkpointHighlightEntities.forEach(refreshCheckpointHighlightMaterial)
    }

    private var markerPalette: EducationalMarkerStyle.Palette {
        EducationalMarkerStyle.palette(for: markerSurfaceTone)
    }

    private func refreshConnectorMaterials(in entity: Entity) {
        for child in entity.children {
            if child.name == "level1-marker-connector-dash",
               let dash = child as? ModelEntity {
                dash.model?.materials = [UnlitMaterial(
                    color: markerPalette.primary.withAlphaComponent(0.9)
                )]
            }
            refreshConnectorMaterials(in: child)
        }
    }

    private func refreshCheckpointHighlightMaterial(_ entity: Entity) {
        guard let circle = entity.children.first as? ModelEntity else { return }
        var material = UnlitMaterial(color: markerPalette.primary.withAlphaComponent(0.55))
        material.blending = .transparent(opacity: 0.55)
        circle.model?.materials = [material]
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

    private func updateIndicatorDistanceLabel(
        meters: Double,
        directionCaption: String,
        parent: ModelEntity
    ) {
        // 0.2 m cukup presisi untuk arahan anak dan mencegah pembuatan ulang
        // mesh teks pada setiap perubahan sentimeter.
        let distanceBucket = Int((max(meters, 0.1) * 5).rounded())
        guard distanceBucket != lastIndicatorDistanceBucket
                || directionCaption != lastIndicatorDirectionCaption else { return }
        lastIndicatorDistanceBucket = distanceBucket
        lastIndicatorDirectionCaption = directionCaption

        let displayedDistance = Double(distanceBucket) / 5
        let distanceText = displayedDistance.formatted(
            .number
                .precision(.fractionLength(1))
                .locale(Locale(identifier: "id_ID"))
        )
        let text = "\(distanceText) m \(directionCaption)"
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

    private func directionCaption(
        forwardAlignment: Float,
        rightAlignment: Float
    ) -> String {
        if forwardAlignment < -0.45, abs(rightAlignment) < 0.35 {
            return "putar balik"
        }
        if abs(rightAlignment) < 0.28, forwardAlignment >= 0 {
            return "lurus"
        }
        return rightAlignment > 0 ? "ke kanan" : "ke kiri"
    }

    private func makeCheckpointEntity(for checkpoint: Checkpoint) -> ModelEntity {
        let entity = SceneObjectSystem.makeObject(type: checkpoint.shape.objectType, texture: checkpoint.shape.textures[0].material)
        let scale = checkpointHeight / SceneObjectSystem.baseDimensions(for: checkpoint.shape.objectType).y
        entity.scale = SIMD3<Float>(repeating: scale)
        entity.position.y = checkpointHeight / 2
        var material = SceneObjectSystem.makeMaterial(for: checkpoint.shape.textures[0].material)
        material.faceCulling = .none
        entity.model?.materials = [material]
        entity.components.set(DynamicLightShadowComponent(castsShadow: true))
        return entity
    }

    // MARK: - Lumi AR Guide

    private func setupGuideCharacter() {
        guard guideRoot == nil, let root = rootAnchor else { return }
        let guide = Entity()
        guide.name = "Level 1 Guide — Lumi"
        guide.isEnabled = false
        let asset = currentGuideAsset
        if let character = CharacterGuideFactory.makeCharacter(asset: asset, width: 0.10, height: 0.14) {
            guide.addChild(character)
            guideCharacter = character
            guideCharacterAsset = asset
        }
        root.addChild(guide)
        guideRoot = guide
    }

    private func updateGuidePosition(cameraPosition: SIMD3<Float>, horizontalForward: SIMD2<Float>) {
        guard hasPlacedScene, let guide = guideRoot else { return }
        let forward = SIMD3<Float>(horizontalForward.x, 0, horizontalForward.y)
        let right = SIMD3<Float>(-horizontalForward.y, 0, horizontalForward.x)
        let destination: SIMD3<Float>

        if let activeTarget = activeGuideRadarTarget,
           let radarPosition = radarWorldPositions[activeTarget] {
            let side: Float = radarAppearsOnRight(radarPosition: radarPosition, cameraPosition: cameraPosition, cameraRight: right) ? -1 : 1
            destination = radarPosition + right * (0.14 * side) + SIMD3<Float>(0, 0.02, 0)
        } else {
            destination = cameraPosition + forward * 0.66 + right * 0.30 + SIMD3<Float>(0, -0.54, 0)
        }

        if guideNeedsPlacement {
            guide.position = destination
            guideNeedsPlacement = false
            guide.isEnabled = shouldShowGuide
            syncGuidePresentation()
        } else {
            guide.position += (destination - guide.position) * 0.24
        }
        guide.look(at: cameraPosition, from: guide.position, relativeTo: nil)
        guideCloud?.position = guideCloudPosition(cameraPosition: cameraPosition, cameraRight: right)
    }

    private func syncGuidePresentation() {
        guard let guide = guideRoot else { return }
        guide.isEnabled = shouldShowGuide && !guideNeedsPlacement
        syncGuideCharacterAsset()
        let text = narrationText
        guard guideText != text else { return }
        guideText = text
        guideCloud?.removeFromParent()
        let speechLayout = guideSpeechLayout(for: text)
        let cloud = CharacterGuideFactory.makeSpeechCloud(
            text: speechLayout.text,
            width: speechLayout.width,
            height: speechLayout.height,
            fontSize: 0.013,
            textHorizontalInset: 0.025,
            textVerticalInset: 0.030
        )
        cloud.name = "Lumi Speech Cloud"
        cloud.position = defaultGuideCloudPosition
        guide.addChild(cloud)
        guideCloud = cloud
    }

    private func moveGuideIfNeeded() {
        guideCloud?.position = defaultGuideCloudPosition
    }

    private var shouldShowGuide: Bool {
        false
    }

    var showsGuideOverlay: Bool {
        guard !hidesGuideForDrawing else { return false }
        return phase != .scanningSurface
            && phase != .surfaceReady
            && phase != .drawingActive
            && phase != .completed
    }

    var guideOverlayAssetName: String {
        currentGuideAsset.rawValue
    }

    private var activeGuideRadarTarget: Level1RadarTarget? {
        guard phase == .lightShadowIntro else { return nil }
        return currentLightShadowInstruction.radarTarget ?? selectedRadarTarget
    }

    private var currentGuideAsset: CharacterGuideAsset {
        switch phase {
        case .onboarding:
            switch onboardingIndex {
            case 0:
                return .lumiIdle
            case 1:
                return .lumiPoint
            case 2:
                return .lumiQuestion
            default:
                return .lumiPointWink
            }
        case .surfaceReady:
            return .lumiPoint
        case .lightShadowIntro:
            return currentLightShadowInstruction.radarTarget == nil ? .lumiPointWink : .lumiPoint
        case .findingShapes:
            return recentlyExplainedCheckpointIndex == nil ? .lumiQuestion : .lumiPointWink
        case .returningToFirstObject:
            return .lumiQuestion
        case .textureTapPrompt:
            return .lumiPoint
        case .textureExploration:
            return hasSelectedTexture ? .lumiPointWink : .lumiQuestion
        case .shapeChange:
            return hasSelectedShape ? .lumiPointWink : .lumiPoint
        case .drawingPrompt:
            return .lumiIdle
        case .drawingReady, .photoPrompt:
            return .lumiPointWink
        case .drawingActive, .scanningSurface, .photoComparison, .completed:
            return .lumiIdle
        }
    }

    private func syncGuideCharacterAsset() {
        guard let guide = guideRoot else { return }
        let asset = currentGuideAsset
        guard guideCharacterAsset != asset else { return }

        guard let character = CharacterGuideFactory.makeCharacter(asset: asset, width: 0.10, height: 0.14) else {
            return
        }
        guideCharacter?.removeFromParent()
        guide.addChild(character)
        guideCharacter = character
        guideCharacterAsset = asset
    }

    private var defaultGuideCloudPosition: SIMD3<Float> {
        return SIMD3<Float>(0.22, 0.14, 0)
    }

    private func guideSpeechLayout(for text: String) -> (text: String, width: Float, height: Float) {
        let wrappedText = wrappedGuideText(text, maximumWordsPerLine: 8)
        let lines = wrappedText.split(separator: "\n", omittingEmptySubsequences: false)
        let longestLineCount = lines.map(\.count).max() ?? text.count
        let width = clamped(Float(longestLineCount) * 0.0064 + 0.10, 0.24, 0.56)
        let height = clamped(Float(lines.count) * 0.022 + 0.060, 0.082, 0.24)
        return (wrappedText, width, height)
    }

    private func wrappedGuideText(_ text: String, maximumWordsPerLine: Int) -> String {
        let words = text.split(separator: " ").map(String.init)
        var lines: [String] = []
        var currentWords: [String] = []

        for word in words {
            if currentWords.count == maximumWordsPerLine {
                lines.append(currentWords.joined(separator: " "))
                currentWords = [word]
            } else {
                currentWords.append(word)
            }
        }

        if !currentWords.isEmpty {
            lines.append(currentWords.joined(separator: " "))
        }

        return lines.joined(separator: "\n")
    }

    private func guideCloudPosition(cameraPosition: SIMD3<Float>, cameraRight: SIMD3<Float>) -> SIMD3<Float> {
        defaultGuideCloudPosition
    }

    private func radarAppearsOnRight(
        radarPosition: SIMD3<Float>,
        cameraPosition: SIMD3<Float>,
        cameraRight: SIMD3<Float>
    ) -> Bool {
        simd_dot(radarPosition - cameraPosition, cameraRight) > 0
    }

    private func diagonalMarkerOffset(direction: SIMD3<Float>, distance: Float) -> SIMD3<Float> {
        let length = simd_length(direction)
        guard length > 0.0001 else { return SIMD3<Float>(0, distance, 0) }
        return direction / length * distance
    }

    private func estimatedShadowPosition(
        objectPosition: SIMD3<Float>,
        lightPosition: SIMD3<Float>,
        objectType: LearningObjectType
    ) -> SIMD3<Float> {
        let groundDirection = ShadowGeometryCalculator.groundShadowDirection(
            lightPosition: lightPosition,
            objectPosition: objectPosition
        ) ?? SIMD3<Float>(-1, 0, 0)
        let objectHeight = scaledObjectDimensions(for: objectType).y
        let lightDirection = simd_normalize(objectPosition - lightPosition)
        let estimatedLength = ShadowGeometryCalculator.approximateShadowLength(
            lightDirection: lightDirection,
            objectHeight: objectHeight
        ) ?? 0.38
        // Posisi ini hanya untuk marker edukasi. Siluet bayangan dibuat
        // terpisah oleh Level1ShadowRenderer dari proyeksi geometri objek.
        let length = clamped(estimatedLength * 0.55, 0.18, 0.58)
        return objectPosition + groundDirection * length + SIMD3<Float>(0, 0.025, 0)
    }

    private func makeCheckpointHighlightEntity() -> Entity {
        let root = Entity()
        var material = UnlitMaterial(color: markerPalette.primary.withAlphaComponent(0.55))
        material.blending = .transparent(opacity: 0.55)
        let circle = ModelEntity(mesh: .generateSphere(radius: 0.55), materials: [material])
        circle.scale = SIMD3<Float>(1, 0.035, 1)
        root.addChild(circle)
        return root
    }

    private func makeRadarEntity(target: Level1RadarTarget) -> Entity {
        let root = makeEducationalMarkerEntity(name: "level1-radar-\(target.rawValue)", receivesInput: true)
        root.components.set(CollisionComponent(shapes: [
            .generateSphere(radius: EducationalMarkerStyle.ringTapTargetRadius)
        ]))
        root.components.set(InputTargetComponent())
        return root
    }

    private func makeEducationalMarkerEntity(name: String, receivesInput: Bool) -> Entity {
        let root = Entity()
        root.name = name

        let dot = ModelEntity(
            mesh: .generateSphere(radius: EducationalMarkerStyle.dotRadius),
            materials: [UnlitMaterial(color: markerPalette.primary)]
        )
        dot.name = "\(name)-center"
        dot.components.set(DynamicLightShadowComponent(castsShadow: false))
        if receivesInput {
            dot.components.set(CollisionComponent(shapes: [
                .generateSphere(radius: EducationalMarkerStyle.tapTargetRadius)
            ]))
            dot.components.set(InputTargetComponent())
        }
        root.addChild(dot)

        let ring = ModelEntity(
            mesh: .generatePlane(
                width: EducationalMarkerStyle.ringDiameter,
                height: EducationalMarkerStyle.ringDiameter
            ),
            materials: [EducationalMarkerStyle.ringMaterial(alpha: 1.0, tint: markerPalette.primary)]
        )
        ring.name = "\(name)-ring"
        ring.components.set(BillboardComponent())
        ring.components.set(DynamicLightShadowComponent(castsShadow: false))
        ring.components.set(PulseAnimationComponent(baseScale: 1, speed: 3.8, amplitude: 0.45, isActiveTarget: true))
        if receivesInput {
            ring.components.set(CollisionComponent(shapes: [
                .generateSphere(radius: EducationalMarkerStyle.ringTapTargetRadius)
            ]))
            ring.components.set(InputTargetComponent())
        }
        root.addChild(ring)

        return root
    }

    /// Dibuat sebagai anak dari marker, sehingga ikut berpindah bersamanya.
    /// Titik-titik kecil memberi visual garis putus-putus tanpa update per
    /// frame atau overlay SwiftUI tambahan.
    private func makeDashedLeader(toward targetOffset: SIMD3<Float>) -> Entity {
        let leader = Entity()
        let length = simd_length(targetOffset)
        guard length > 0.001 else { return leader }

        let material = UnlitMaterial(color: markerPalette.primary.withAlphaComponent(0.9))
        let fractions: [Float] = [0.14, 0.26, 0.38, 0.50, 0.62, 0.74, 0.86]

        for fraction in fractions {
            let dash = ModelEntity(mesh: .generateSphere(radius: 0.0032), materials: [material])
            dash.name = "level1-marker-connector-dash"
            dash.position = targetOffset * fraction
            dash.components.set(DynamicLightShadowComponent(castsShadow: false))
            leader.addChild(dash)
        }
        return leader
    }


    private func makeLightEntity(from position: SIMD3<Float>, aimingAt target: SIMD3<Float>) -> Entity {
        let root = Entity()
        root.position = position
        let lightColor = UIColor(red: 1.0, green: 0.86, blue: 0.62, alpha: 1)

        let light = Entity()
        var component = SpotLightComponent()
        component.color = lightColor
        component.intensity = Self.shadowLightIntensity
        component.attenuationRadius = Self.shadowAttenuationRadius
        component.innerAngleInDegrees = Self.shadowBeamOuterAngle * 0.55
        component.outerAngleInDegrees = Self.shadowBeamOuterAngle
        light.components.set(component)
        var shadow = SpotLightComponent.Shadow()
        shadow.zNear = .fixed(0.01)
        shadow.zFar = .fixed(8)
        shadow.depthBias = 0.004
        light.components.set(shadow)
        if let angles = SceneLightSystem.aimingAngles(from: position, to: target) {
            light.orientation = SceneLightSystem.orientation(
                yawDegrees: angles.yawDegrees,
                pitchDegrees: angles.pitchDegrees
            )
        }
        root.addChild(light)

        // Fill light yang sama seperti Level 3 menjaga objek tetap terbaca tanpa
        // menghilangkan kontras bayangan utama.
        let fillLight = Entity()
        var fillComponent = PointLightComponent()
        fillComponent.color = lightColor
        fillComponent.intensity = Self.shadowLightIntensity * 0.08
        fillComponent.attenuationRadius = 1
        fillLight.components.set(fillComponent)
        root.addChild(fillLight)

        let marker = ModelEntity(
            mesh: .generateSphere(radius: 0.08),
            materials: [UnlitMaterial(color: lightColor)]
        )
        marker.components.set(DynamicLightShadowComponent(castsShadow: false))
        root.addChild(marker)
        return root
    }

    private func lightOffset(for objectType: LearningObjectType) -> SIMD3<Float> {
        let heightAdjustment: Float = objectType == .sphere ? 0.04 : 0
        return SIMD3<Float>(0.48, 0.46 + heightAdjustment, -0.42)
    }


    private func scaledObjectDimensions(for objectType: LearningObjectType) -> SIMD3<Float> {
        let base = SceneObjectSystem.baseDimensions(for: objectType)
        let scale = checkpointHeight / base.y
        return base * scale
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
