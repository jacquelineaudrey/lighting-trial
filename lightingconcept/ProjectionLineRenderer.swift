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
        objectYawDegrees: Float,
        lightTarget: SIMD3<Float>,
        selectedLight: LightConfiguration,
        toggles: OverlayToggles
    ) {
        clear()

        // Panah kuning menunjukkan arah cahaya terpilih menuju target object.
        // Ini overlay edukasi, bukan sumber cahaya fisik.
        if toggles.showLightDirection {
            addArrow(from: selectedLight.position, to: lightTarget, color: .systemYellow, radius: 0.0032)
        }

        // Beberapa ray representatif cukup untuk menjelaskan konsep tanpa membuat scene berat.
        if toggles.showLightRays {
            let offsets: [SIMD3<Float>] = [
                SIMD3<Float>(0, 0, 0),
                SIMD3<Float>(0.04, 0.02, 0),
                SIMD3<Float>(-0.04, 0.02, 0),
                SIMD3<Float>(0, -0.02, 0.04)
            ]
            for offset in offsets {
                addLine(from: selectedLight.position, to: lightTarget + offset, color: .systemOrange, radius: 0.0018)
            }
        }

        // Ground projection adalah arah bayangan di bidang datar: menjauhi posisi light.
        if toggles.showGroundProjection,
           let direction = ShadowGeometryCalculator.groundShadowDirection(
            lightPosition: selectedLight.position,
            objectPosition: objectPosition
            ) {
            let start = SIMD3<Float>(objectPosition.x, 0.018, objectPosition.z)
            addArrow(from: start, to: start + direction * 0.32, color: .systemBlue, radius: 0.003)
        }

        // Projection lines khusus cube memakai vertex atas. Garis ini menjelaskan
        // kenapa shadow cube bisa punya sudut dan berubah saat cube dirotasi.
        if toggles.showProjectionLines, objectType == .cube {
            let vertices = cubeTopVertices(
                groundPosition: objectPosition,
                height: objectHeight,
                yawDegrees: objectYawDegrees
            )
            for vertex in vertices {
                guard let projected = ShadowGeometryCalculator.projectPointFromLight(
                    lightPosition: selectedLight.position,
                    objectPoint: vertex
                ) else {
                    continue
                }
                addLine(from: selectedLight.position, to: projected + SIMD3<Float>(0, 0.018, 0), color: .systemPurple, radius: 0.0018)
                addPoint(at: projected + SIMD3<Float>(0, 0.024, 0), color: .systemPurple)
            }
        }
    }

    private func cubeTopVertices(
        groundPosition: SIMD3<Float>,
        height: Float,
        yawDegrees: Float
    ) -> [SIMD3<Float>] {
        let half = height / 2
        let center = groundPosition + SIMD3<Float>(0, half, 0)
        let yaw = simd_quatf(angle: yawDegrees.degreesToRadians, axis: SIMD3<Float>(0, 1, 0))
        let localOffsets = [
            SIMD3<Float>(-half, half, -half),
            SIMD3<Float>(half, half, -half),
            SIMD3<Float>(-half, half, half),
            SIMD3<Float>(half, half, half)
        ]
        return localOffsets.map { center + yaw.act($0) }
    }

    private func addArrow(from start: SIMD3<Float>, to end: SIMD3<Float>, color: UIColor, radius: Float) {
        addLine(from: start, to: end, color: color, radius: radius)
        let direction = simd_normalize(end - start)
        let cone = ModelEntity(mesh: .generateCone(height: 0.024, radius: radius * 3), materials: [UnlitMaterial(color: color)])
        cone.position = end
        cone.orientation = orientationForCylinder(from: SIMD3<Float>(0, 1, 0), to: direction)
        disableShadows(for: cone)
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
        disableShadows(for: entity)
        root.addChild(entity)
        lineEntities.append(entity)
    }

    private func addPoint(at position: SIMD3<Float>, color: UIColor) {
        let point = ModelEntity(mesh: .generateSphere(radius: 0.01), materials: [UnlitMaterial(color: color)])
        point.position = position
        disableShadows(for: point)
        root.addChild(point)
        lineEntities.append(point)
    }

    private func disableShadows(for entity: ModelEntity) {
        entity.components.set(DynamicLightShadowComponent(castsShadow: false))
        entity.components.set(GroundingShadowComponent(castsShadow: false, receivesShadow: false))
    }

    private func orientationForCylinder(from: SIMD3<Float>, to: SIMD3<Float>) -> simd_quatf {
        // Cylinder default berdiri di sumbu Y. Quaternion ini memutar cylinder agar
        // sejajar dengan vector line dari titik start ke end.
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
