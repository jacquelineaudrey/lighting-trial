import Combine
import Foundation
import RealityKit
import SwiftUI

@MainActor
final class Level4ViewModel: ObservableObject, ARSceneTelemetryDelegate {
    @Published private(set) var phase: Level4Phase = .placingScene
    @Published private(set) var guideOverlayScreenPosition: CGPoint?
    @Published private(set) var hasSelectedObject = false
    @Published private(set) var isDeviceFollowing = false
    @Published private(set) var gestureTouchPoint: CGPoint?

    let sceneViewModel = ARSceneViewModel()
    private let progressStore: GameProgressStore
    private weak var guideParent: Entity?
    private var guideRoot: Entity?
    private var guideNeedsPlacement = true
    private let guideForwardDistance: Float = 0.66
    private let guideRightDistance: Float = 0.30
    private let guideVerticalOffset: Float = -0.54
    private let guideFollowLerp: Float = 0.24

    init(progressStore: GameProgressStore? = nil) {
        self.progressStore = progressStore ?? .shared
        configureScene()
    }

    var dialog: Level4Dialog? {
        switch phase {
        case let .introduction(index): Level4Content.introduction[safe: index]
        case let .objectExplanation(index): Level4Content.objectExplanation[safe: index]
        case let .lightIntroduction(index): Level4Content.lightIntroduction[safe: index]
        case let .lightExplanation(index): Level4Content.lightExplanation[safe: index]
        case let .closing(index): Level4Content.closing[safe: index]
        default: nil
        }
    }

    var narrationText: String { dialog?.text ?? "" }
    var narrationID: String {
        switch phase {
        case let .introduction(index): "level4-intro-\(index)"
        case let .objectExplanation(index): "level4-object-explanation-\(index)"
        case let .lightIntroduction(index): "level4-light-intro-\(index)"
        case let .lightExplanation(index): "level4-light-explanation-\(index)"
        case let .closing(index): "level4-closing-\(index)"
        default: "level4-\(String(describing: phase))"
        }
    }
    var shouldSpeakNarration: Bool { dialog != nil }
    var showsGuideOverlay: Bool { dialog != nil }
    var guideAssetName: String { dialog?.assetName ?? "lumiIdle" }

    func advanceDialog() {
        switch phase {
        case let .introduction(index):
            phase = index + 1 < Level4Content.introduction.count ? .introduction(index + 1) : .selectingObject
        case let .objectExplanation(index):
            phase = index + 1 < Level4Content.objectExplanation.count
                ? .objectExplanation(index + 1)
                : .lightIntroduction(0)
        case let .lightIntroduction(index):
            phase = index + 1 < Level4Content.lightIntroduction.count
                ? .lightIntroduction(index + 1)
                : .selectingLight
        case let .lightExplanation(index):
            phase = index + 1 < Level4Content.lightExplanation.count
                ? .lightExplanation(index + 1)
                : .exploring
        case let .closing(index):
            phase = index + 1 < Level4Content.closing.count ? .closing(index + 1) : .review
        default:
            break
        }
    }

    var canSelectObject: Bool {
        phase == .selectingObject || phase == .movingObject || phase == .exploring
    }

    var canSelectLight: Bool {
        phase == .selectingLight || phase == .movingLight || phase == .exploring
    }

    var canMoveObject: Bool {
        phase == .movingObject || (phase == .exploring && sceneViewModel.interactionMode == .moveObject)
    }

    var canMoveLight: Bool {
        phase == .movingLight || (phase == .exploring && sceneViewModel.interactionMode == .moveLight)
    }

    var topModeTitle: String {
        switch sceneViewModel.interactionMode {
        case .moveObject: "Kamu jadi objek!"
        case .moveLight: "Kamu jadi cahaya!"
        }
    }

    func selectObject(_ id: UUID) {
        guard canSelectObject else { return }
        sceneViewModel.selectedObjectID = id
        sceneViewModel.interactionMode = .moveObject
        hasSelectedObject = true
        if phase == .selectingObject {
            phase = .objectMovementTutorial
        }
    }

    func selectLight(_ id: UUID) {
        guard canSelectLight else { return }
        sceneViewModel.selectedLightID = id
        sceneViewModel.interactionMode = .moveLight
        if phase == .selectingLight {
            phase = .lightMovementTutorial
        }
    }

    func startObjectMovementPractice() {
        guard phase == .objectMovementTutorial else { return }
        phase = .movingObject
    }

    func startLightMovementPractice() {
        guard phase == .lightMovementTutorial else { return }
        phase = .movingLight
    }

    func beginDeviceFollow(at point: CGPoint) -> Bool {
        guard (canMoveObject && hasSelectedObject) || canMoveLight else { return false }
        gestureTouchPoint = point
        isDeviceFollowing = true
        return true
    }

    func updateDeviceFollowTouch(at point: CGPoint) {
        guard isDeviceFollowing else { return }
        gestureTouchPoint = point
    }

    func endObjectDeviceFollow(position: SIMD3<Float>?) {
        if let position {
            sceneViewModel.updateSelectedObject { $0.position = position }
        }
        clearDeviceFollowState()
    }

    func endLightDeviceFollow(configuration: LightConfiguration?) {
        if let configuration,
           configuration.id == sceneViewModel.selectedLightID {
            sceneViewModel.updateSelectedLight { light in
                light.position = configuration.position
                light.yawDegrees = configuration.yawDegrees
                light.pitchDegrees = configuration.pitchDegrees
            }
        }
        clearDeviceFollowState()
    }

    func confirmObjectWasMoved() {
        guard phase == .movingObject else { return }
        phase = .objectExplanation(0)
    }

    func confirmLightWasMoved() {
        guard phase == .movingLight else { return }
        phase = .lightExplanation(0)
    }

    func finishExploring() {
        guard phase == .exploring else { return }
        phase = .closing(0)
    }

    func finishReview() {
        guard phase == .review else { return }
        progressStore.markLevelCompleted(Level4Content.levelID)
        phase = .completed
    }

    func sceneDidPlace(at worldPosition: SIMD3<Float>) {
        guard phase == .placingScene else { return }
        phase = .introduction(0)
    }

    func sceneDidReset() {
        phase = .placingScene
        hasSelectedObject = false
        isDeviceFollowing = false
        gestureTouchPoint = nil
    }
    func cameraDidUpdate(position: SIMD3<Float>) {}
    func lightDidSelect() {
        selectLight(sceneViewModel.selectedLightID)
    }

    private func clearDeviceFollowState() {
        isDeviceFollowing = false
        gestureTouchPoint = nil
    }

    // MARK: - AR guide anchor

    /// Sama seperti Level 1–3: Lumi punya entity anchor di world-space. Visual
    /// bubble/karakter tetap SwiftUI, sementara posisi layarnya diproyeksikan
    /// dari entity ECS ini setiap frame.
    func attachGuideIfNeeded(to parent: Entity) {
        if guideParent !== parent {
            guideRoot?.removeFromParent()
            guideParent = parent
            guideRoot = nil
            guideNeedsPlacement = true
        }

        guard guideRoot == nil else { return }
        let guide = Entity()
        guide.name = "Level 4 Guide - Lumi"
        guide.isEnabled = false
        parent.addChild(guide)
        guideRoot = guide
    }

    func updateGuide(cameraPosition: SIMD3<Float>, forward cameraForward: SIMD3<Float>) {
        guard let guideRoot else { return }
        let horizontalForward = SIMD2<Float>(cameraForward.x, cameraForward.z)
        let length = simd_length(horizontalForward)
        guard length > 0.0001 else { return }

        let normalizedForward = horizontalForward / length
        let forward = SIMD3<Float>(normalizedForward.x, 0, normalizedForward.y)
        let right = SIMD3<Float>(-normalizedForward.y, 0, normalizedForward.x)
        let destination = cameraPosition
            + forward * guideForwardDistance
            + right * guideRightDistance
            + SIMD3<Float>(0, guideVerticalOffset, 0)

        if guideNeedsPlacement {
            guideRoot.position = destination
            guideNeedsPlacement = false
        } else {
            guideRoot.position += (destination - guideRoot.position) * guideFollowLerp
        }
        guideRoot.look(at: cameraPosition, from: guideRoot.position, relativeTo: nil)
    }

    var guideOverlayWorldPosition: SIMD3<Float>? {
        guard showsGuideOverlay, !guideNeedsPlacement, let guideRoot else { return nil }
        return guideRoot.position(relativeTo: nil)
    }

    func updateGuideOverlayScreenPosition(_ position: CGPoint?) {
        guard showsGuideOverlay else {
            guideOverlayScreenPosition = nil
            return
        }
        switch (guideOverlayScreenPosition, position) {
        case let (current?, next?) where hypot(current.x - next.x, current.y - next.y) < 4:
            return
        case (nil, nil):
            return
        default:
            guideOverlayScreenPosition = position
        }
    }

    private func configureScene() {
        // Shared AR coordinator keeps the ECS-based object/light/shadow scene.
        // This lesson deliberately exposes only the object's movement gesture.
        sceneViewModel.requiresLiDARScanBeforePlacement = true
        sceneViewModel.usesLiDARSceneReconstruction = true
        sceneViewModel.usesLiDARPhysicsInteraction = true
        sceneViewModel.usesRealisticEnvironmentLighting = false
        sceneViewModel.objectDirectManipulationLocked = false
        // Taps select the object; Level 4 owns its hold-and-device-move gesture.
        sceneViewModel.directManipulationRotatesOnly = true
        sceneViewModel.interactionMode = .moveObject
        sceneViewModel.showLightDirection = true
        sceneViewModel.showLightRays = true
        sceneViewModel.showGroundProjection = true
        sceneViewModel.showProjectionLines = false
        sceneViewModel.updateSelectedObject { object in
            object.type = .cube
            object.scale = 0.85
        }

        let cubeCenter = SIMD3<Float>(
            0,
            SceneObjectSystem.cubeSize * 0.85 / 2,
            0
        )
        let lightPosition = SIMD3<Float>(-0.24, 0.34, 0.28)
        sceneViewModel.updateSelectedLight { light in
            light.type = .spot
            light.color = Level6LightColor.yellow.color
            light.position = lightPosition
            light.intensity = 3_200
            light.beamOuterAngleDegrees = 54
            light.markerScale = 0.7
            if let angles = SceneLightSystem.aimingAngles(
                from: lightPosition,
                to: cubeCenter
            ) {
                light.yawDegrees = angles.yawDegrees
                light.pitchDegrees = angles.pitchDegrees
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
