import ARKit
import Combine
import RealityKit

/// Menjaga Lumi dan bubble chat tetap di RealityKit. SwiftUI hanya memberi
/// fase serta teks, sehingga tidak ada update UI per-frame untuk guide ini.
@MainActor
final class Level2GuideController {
    private weak var arView: ARView?
    private var anchor: AnchorEntity?
    private var guide: Entity?
    private var cloud: Entity?
    private var displayedText: String?
    private var needsPlacement = true
    private var cameraSubscription: AnyCancellable?

    func setup(on arView: ARView) {
        guard self.arView == nil else { return }
        self.arView = arView

        let anchor = AnchorEntity(world: .zero)
        let guide = Entity()
        guide.name = "Level 2 Guide — Lumi"
        guide.components.set(Level2GuideComponent(basePosition: .zero))
        guide.isEnabled = false

        if let character = CharacterGuideFactory.makeCharacter(asset: .lumiPoint) {
            character.name = "Lumi Character"
            character.components.set(BillboardComponent())
            guide.addChild(character)
        }

        anchor.addChild(guide)
        arView.scene.addAnchor(anchor)
        self.anchor = anchor
        self.guide = guide
        cameraSubscription = AnyCancellable(arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self, weak arView] _ in
            guard let self else { return }
            guard self.needsPlacement else {
                self.cameraSubscription?.cancel()
                self.cameraSubscription = nil
                return
            }
            guard let transform = arView?.session.currentFrame?.camera.transform else { return }
            self.placeIfNeeded(cameraTransform: transform)
        })
    }

    func sync(phase: Level2Phase, text: String) {
        guard let guide else { return }
        let showsGuide = phase != .completed && phase != .review
        guide.isEnabled = showsGuide && !needsPlacement

        guard showsGuide, displayedText != text else { return }
        displayedText = text
        rebuildCloud(text: text, on: guide)
    }

    /// Called from the existing scene update stream. The guide is positioned
    /// once in front-right of the learner, then never follows the camera.
    func placeIfNeeded(cameraTransform: simd_float4x4) {
        guard needsPlacement, let guide else { return }
        let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let forward3D = -SIMD3<Float>(cameraTransform.columns.2.x, 0, cameraTransform.columns.2.z)
        let length = simd_length(forward3D)
        guard length > 0.0001 else { return }
        let forward = forward3D / length
        let right = SIMD3<Float>(-forward.z, 0, forward.x)
        let position = cameraPosition + forward * 1.15 + right * 0.45 + SIMD3<Float>(0, -0.42, 0)
        guide.position = position
        guide.components.set(Level2GuideComponent(basePosition: position))
        needsPlacement = false
        guide.isEnabled = true
    }

    private func rebuildCloud(text: String, on guide: Entity) {
        cloud?.removeFromParent()
        let cloud = CharacterGuideFactory.makeSpeechCloud(text: text)
        cloud.name = "Lumi Speech Cloud"
        cloud.position = SIMD3<Float>(-0.48, 0.32, 0)
        guide.addChild(cloud)
        self.cloud = cloud
    }
}
