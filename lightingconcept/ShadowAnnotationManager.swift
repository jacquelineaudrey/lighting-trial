import RealityKit
import UIKit

final class ShadowAnnotationManager {
    private let root = Entity()
    private var labels: [ModelEntity] = []

    func attach(to anchor: AnchorEntity) {
        if root.parent == nil {
            anchor.addChild(root)
        }
    }

    func clear() {
        labels.forEach { $0.removeFromParent() }
        labels.removeAll()
    }

    func update(
        visible: Bool,
        objectType: LearningObjectType,
        objectPosition: SIMD3<Float>,
        objectHeight: Float,
        selectedLight: LightConfiguration
    ) {
        clear()
        guard visible else { return }

        let concepts: [(ShadowConcept, SIMD3<Float>)]
        if objectType == .cube {
            concepts = [
                (.lightSide, objectPosition + SIMD3<Float>(-0.08, objectHeight * 0.72, 0)),
                (.shadowSide, objectPosition + SIMD3<Float>(0.08, objectHeight * 0.5, 0)),
                (.castShadow, objectPosition + shadowOffset(light: selectedLight, object: objectPosition, scale: 0.24)),
                (.contactShadow, objectPosition + SIMD3<Float>(0, 0.025, 0.08))
            ]
        } else {
            concepts = [
                (.highlight, objectPosition + SIMD3<Float>(-0.05, objectHeight * 0.86, 0)),
                (.lightSide, objectPosition + SIMD3<Float>(-0.08, objectHeight * 0.62, 0)),
                (.terminator, objectPosition + SIMD3<Float>(0, objectHeight * 0.72, 0.07)),
                (.coreShadow, objectPosition + SIMD3<Float>(0.07, objectHeight * 0.5, 0)),
                (.reflectedLight, objectPosition + SIMD3<Float>(0.04, objectHeight * 0.34, 0.06)),
                (.castShadow, objectPosition + shadowOffset(light: selectedLight, object: objectPosition, scale: 0.24)),
                (.contactShadow, objectPosition + SIMD3<Float>(0, 0.025, 0.08))
            ]
        }

        for (concept, position) in concepts {
            addLabel(concept: concept, position: position)
        }
    }

    private func addLabel(concept: ShadowConcept, position: SIMD3<Float>) {
        let mesh = MeshResource.generateText(
            concept.rawValue,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.026, weight: .semibold),
            containerFrame: CGRect(x: 0, y: 0, width: 0.24, height: 0.08),
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        let material = UnlitMaterial(color: .white)
        let label = ModelEntity(mesh: mesh, materials: [material])
        label.name = "Label: \(concept.rawValue)"
        label.position = position
        label.scale = SIMD3<Float>(repeating: 0.6)
        root.addChild(label)
        labels.append(label)
    }

    private func shadowOffset(light: LightConfiguration, object: SIMD3<Float>, scale: Float) -> SIMD3<Float> {
        guard let direction = ShadowGeometryCalculator.groundShadowDirection(lightPosition: light.position, objectPosition: object) else {
            return SIMD3<Float>(0, 0.02, 0.2)
        }
        return direction * scale + SIMD3<Float>(0, 0.025, 0)
    }
}
