import RealityKit
import UIKit
import simd

/// Which of the "Learn" tab overlays are currently switched on.
struct OverlayToggles {
    var showLightDirection: Bool
    var showLightRays: Bool
    var showProjectionLines: Bool
    var showGroundProjection: Bool
}

/// Draws the procedural, non-physical geometry that explains how shadows
/// form: a line from the light to the object, rays from the light through
/// the object's silhouette, and the ground-projection direction line.
final class ProjectionLineRenderer {
    private weak var anchor: AnchorEntity?
    private var overlayRoot: Entity?

    func attach(to anchor: AnchorEntity) {
        self.anchor = anchor
        let root = Entity()
        root.name = "ProjectionOverlayRoot"
        anchor.addChild(root)
        overlayRoot = root
    }

    func clear() {
        overlayRoot?.removeFromParent()
        overlayRoot = nil
        anchor = nil
    }

    func update(
        objectType: LearningObjectType,
        objectPosition: SIMD3<Float>,
        objectHeight: Float,
        selectedLight: LightConfiguration,
        toggles: OverlayToggles
    ) {
        guard let overlayRoot else { return }
        overlayRoot.children.removeAll()

        if toggles.showLightDirection {
            addLine(to: overlayRoot, from: selectedLight.position, to: objectPosition, color: .systemYellow, thickness: 0.004)
        }

        if toggles.showLightRays, objectType == .cube {
            let cubeCenter = SIMD3<Float>(objectPosition.x, ObjectFactory.cubeSize / 2, objectPosition.z)
            let points = ShadowGeometryCalculator.cubeProjectionPoints(
                lightPosition: selectedLight.position,
                cubeCenter: cubeCenter
            )
            for point in points {
                addSphere(to: overlayRoot, at: point, color: .systemOrange, radius: 0.006)
                if toggles.showProjectionLines {
                    addLine(to: overlayRoot, from: selectedLight.position, to: point, color: .systemOrange, thickness: 0.0025)
                }
            }
        }

        if toggles.showGroundProjection,
           let direction = ShadowGeometryCalculator.groundShadowDirection(
               lightPosition: selectedLight.position,
               objectPosition: objectPosition
           ) {
            let end = objectPosition + direction * 0.3
            addLine(to: overlayRoot, from: objectPosition, to: end, color: .white, thickness: 0.003)
        }
    }

    private func addLine(to root: Entity, from start: SIMD3<Float>, to end: SIMD3<Float>, color: UIColor, thickness: Float) {
        let vector = end - start
        let distance = simd_length(vector)
        guard distance > 0.001 else { return }

        let mesh = MeshResource.generateCylinder(height: distance, radius: thickness)
        let entity = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: color, isMetallic: false)])
        entity.position = (start + end) / 2

        let up = SIMD3<Float>(0, 1, 0)
        let direction = simd_normalize(vector)
        entity.orientation = simd_quatf(from: up, to: direction)
        root.addChild(entity)
    }

    private func addSphere(to root: Entity, at position: SIMD3<Float>, color: UIColor, radius: Float) {
        let mesh = MeshResource.generateSphere(radius: radius)
        let entity = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: color, isMetallic: false)])
        entity.position = position
        root.addChild(entity)
    }
}
