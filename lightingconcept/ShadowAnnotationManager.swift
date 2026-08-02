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
        let lightSide = horizontalDirection(from: objectPosition, to: selectedLight.position)
        let shadowSide = -lightSide
        let sideLift = SIMD3<Float>(0, objectHeight * 0.55, 0)
        let topLift = SIMD3<Float>(0, objectHeight * 0.82, 0)
        if objectType == .cube {
            concepts = [
                (.lightSide, objectPosition + lightSide * 0.11 + topLift),
                (.shadowSide, objectPosition + shadowSide * 0.11 + sideLift),
                (.castShadow, objectPosition + shadowOffset(light: selectedLight, object: objectPosition, scale: 0.24)),
                (.contactShadow, objectPosition + shadowSide * 0.08 + SIMD3<Float>(0, 0.025, 0))
            ]
        } else {
            let perpendicular = SIMD3<Float>(-lightSide.z, 0, lightSide.x)
            concepts = [
                (.highlight, objectPosition + lightSide * 0.07 + topLift),
                (.lightSide, objectPosition + lightSide * 0.1 + sideLift),
                (.terminator, objectPosition + perpendicular * 0.09 + SIMD3<Float>(0, objectHeight * 0.68, 0)),
                (.coreShadow, objectPosition + shadowSide * 0.1 + SIMD3<Float>(0, objectHeight * 0.5, 0)),
                (.reflectedLight, objectPosition + shadowSide * 0.06 + SIMD3<Float>(0, objectHeight * 0.32, 0)),
                (.castShadow, objectPosition + shadowOffset(light: selectedLight, object: objectPosition, scale: 0.24)),
                (.contactShadow, objectPosition + shadowSide * 0.08 + SIMD3<Float>(0, 0.025, 0))
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
        label.components.set(DynamicLightShadowComponent(castsShadow: false))
        label.components.set(GroundingShadowComponent(castsShadow: false, receivesShadow: false))
        root.addChild(label)
        labels.append(label)
    }

    private func horizontalDirection(from start: SIMD3<Float>, to end: SIMD3<Float>) -> SIMD3<Float> {
        let direction = SIMD3<Float>(end.x - start.x, 0, end.z - start.z)
        let length = simd_length(direction)
        guard length > 0.0001 else {
            return SIMD3<Float>(-1, 0, 0)
        }
        return direction / length
    }

    private func shadowOffset(light: LightConfiguration, object: SIMD3<Float>, scale: Float) -> SIMD3<Float> {
        guard let direction = ShadowGeometryCalculator.groundShadowDirection(lightPosition: light.position, objectPosition: object) else {
            return SIMD3<Float>(0, 0.02, 0.2)
        }
        return direction * scale + SIMD3<Float>(0, 0.025, 0)
    }
}
