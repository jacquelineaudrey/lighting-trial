import RealityKit
import UIKit

/// Places the tappable "Light Side / Shadow Side / Terminator / ..." callout
/// labels used by the Learn tab. Each label is named "Label: <ConceptName>"
/// so ARSceneCoordinator.handleTap can identify which concept was tapped.
final class ShadowAnnotationManager {
    private weak var anchor: AnchorEntity?
    private var labelRoot: Entity?

    func attach(to anchor: AnchorEntity) {
        self.anchor = anchor
        let root = Entity()
        root.name = "ShadowAnnotationRoot"
        anchor.addChild(root)
        labelRoot = root
    }

    func update(
        visible: Bool,
        objectType: LearningObjectType,
        objectPosition: SIMD3<Float>,
        objectHeight: Float,
        selectedLight: LightConfiguration
    ) {
        guard let labelRoot else { return }
        labelRoot.children.removeAll()
        guard visible else { return }

        let concepts: [(ShadowConcept, SIMD3<Float>)] = [
            (.lightSide, objectPosition + SIMD3<Float>(0.12, objectHeight * 0.7, 0)),
            (.shadowSide, objectPosition + SIMD3<Float>(-0.12, objectHeight * 0.7, 0)),
            (.terminator, objectPosition + SIMD3<Float>(0, objectHeight * 0.9, 0.08)),
            (.coreShadow, objectPosition + SIMD3<Float>(-0.08, objectHeight * 0.4, -0.04)),
            (.castShadow, objectPosition + SIMD3<Float>(0.05, 0.002, 0.2)),
            (.contactShadow, objectPosition + SIMD3<Float>(0, 0.002, objectHeight * 0.05)),
            (.highlight, objectPosition + SIMD3<Float>(0.06, objectHeight * 0.85, 0.06)),
            (.reflectedLight, objectPosition + SIMD3<Float>(-0.06, objectHeight * 0.2, 0.02))
        ]

        for (concept, position) in concepts {
            let label = makeLabel(text: concept.rawValue)
            label.name = "Label: \(concept.rawValue)"
            label.position = position
            labelRoot.addChild(label)
        }
    }

    private func makeLabel(text: String) -> ModelEntity {
        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.02),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        let material = SimpleMaterial(color: .white, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.generateCollisionShapes(recursive: true)
        // Keep labels facing the camera. If your installed SDK doesn't have
        // BillboardComponent, delete the next line — labels will just face
        // whatever direction they were created in.
        entity.components.set(BillboardComponent())
        return entity
    }
}
