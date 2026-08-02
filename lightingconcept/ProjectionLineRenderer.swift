import RealityKit
import UIKit

final class ProjectionLineRenderer {
    private let root = Entity()
    private var lineEntities: [ModelEntity] = []

    init() {
        root.name = "Educational overlays"
    }

    func attach(to anchor: AnchorEntity) {
        if root.parent == nil {
            anchor.addChild(root)
        }
    }

    func clear() {
        lineEntities.forEach { $0.removeFromParent() }
        lineEntities.removeAll()
    }

    func update(
        objectType: LearningObjectType,
        objectPosition: SIMD3<Float>,
        objectHeight: Float,
        selectedLight: LightConfiguration,
        toggles: OverlayToggles
    ) {
        clear()

        if toggles.showLightDirection {
            let end: SIMD3<Float>
            if selectedLight.type == .spot {
                end = selectedLight.position + LightFactory.forwardVector(
                    yawDegrees: selectedLight.yawDegrees,
                    pitchDegrees: selectedLight.pitchDegrees
                ) * 0.35
            } else {
                end = objectPosition + SIMD3<Float>(0, objectHeight / 2, 0)
            }
            addArrow(from: selectedLight.position, to: end, color: .systemYellow, radius: 0.004)
        }

        if toggles.showLightRays {
            let targetCenter = objectPosition + SIMD3<Float>(0, objectHeight / 2, 0)
            let offsets: [SIMD3<Float>] = [
                SIMD3<Float>(0, 0, 0),
                SIMD3<Float>(0.04, 0.02, 0),
                SIMD3<Float>(-0.04, 0.02, 0),
                SIMD3<Float>(0, -0.02, 0.04)
            ]
            for offset in offsets {
                addLine(from: selectedLight.position, to: targetCenter + offset, color: .systemOrange, radius: 0.0025)
            }
        }

        if toggles.showGroundProjection,
           let direction = ShadowGeometryCalculator.groundShadowDirection(
            lightPosition: selectedLight.position,
            objectPosition: objectPosition
           ) {
            let start = SIMD3<Float>(objectPosition.x, 0.006, objectPosition.z)
            addArrow(from: start, to: start + direction * 0.32, color: .systemBlue, radius: 0.004)
        }

        if toggles.showProjectionLines, objectType == .cube {
            let vertices = ObjectFactory.cubeTopVertices(center: objectPosition)
            for vertex in vertices {
                guard let projected = ShadowGeometryCalculator.projectPointFromLight(
                    lightPosition: selectedLight.position,
                    objectPoint: vertex
                ) else {
                    continue
                }
                addLine(from: selectedLight.position, to: projected + SIMD3<Float>(0, 0.004, 0), color: .systemPurple, radius: 0.002)
                addPoint(at: projected + SIMD3<Float>(0, 0.008, 0), color: .systemPurple)
            }
        }
    }

    private func addArrow(from start: SIMD3<Float>, to end: SIMD3<Float>, color: UIColor, radius: Float) {
        addLine(from: start, to: end, color: color, radius: radius)
        let direction = simd_normalize(end - start)
        let cone = ModelEntity(mesh: .generateCone(height: 0.035, radius: radius * 3), materials: [UnlitMaterial(color: color)])
        cone.position = end
        cone.orientation = orientationForCylinder(from: SIMD3<Float>(0, 1, 0), to: direction)
        root.addChild(cone)
        lineEntities.append(cone)
    }

    private func addLine(from start: SIMD3<Float>, to end: SIMD3<Float>, color: UIColor, radius: Float) {
        let vector = end - start
        let length = simd_length(vector)
        guard length > 0.002, length.isFinite else { return }

        let entity = ModelEntity(mesh: .generateCylinder(height: length, radius: radius), materials: [UnlitMaterial(color: color)])
        entity.position = (start + end) / 2
        entity.orientation = orientationForCylinder(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(vector))
        root.addChild(entity)
        lineEntities.append(entity)
    }

    private func addPoint(at position: SIMD3<Float>, color: UIColor) {
        let point = ModelEntity(mesh: .generateSphere(radius: 0.01), materials: [UnlitMaterial(color: color)])
        point.position = position
        root.addChild(point)
        lineEntities.append(point)
    }

    private func orientationForCylinder(from: SIMD3<Float>, to: SIMD3<Float>) -> simd_quatf {
        let axis = simd_cross(from, to)
        let dot = simd_dot(from, to)
        if simd_length(axis) < 0.0001 {
            return dot > 0 ? simd_quatf() : simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
        }
        return simd_quatf(angle: acos(clamped(dot, -1, 1)), axis: simd_normalize(axis))
    }
}

struct OverlayToggles {
    var showLightDirection: Bool
    var showLightRays: Bool
    var showProjectionLines: Bool
    var showGroundProjection: Bool
}
