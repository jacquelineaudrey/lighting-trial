import RealityKit
import simd
import UIKit

/// Fallback visual untuk perangkat yang tidak menampilkan dynamic shadow pada
/// `OcclusionMaterial`. Mesh dibentuk dari proyeksi geometri objek ke lantai,
/// sehingga kontur tetap mengikuti bentuk objek dan posisi lampu Level 1.
enum Level1ShadowRenderer {
    private static let groundY: Float = 0
    private static let surfaceOffset: Float = 0.012
    private static let sampleCount = 24

    static func makeEntity(name: String) -> Entity {
        let entity = Entity()
        entity.name = name
        return entity
    }

    static func update(
        _ entity: Entity,
        objectType: LearningObjectType,
        objectPosition: SIMD3<Float>,
        objectDimensions: SIMD3<Float>,
        lightPosition: SIMD3<Float>,
        texture: MaterialTexture
    ) {
        entity.children.removeAll()

        let samples = surfaceSamples(
            for: objectType,
            objectPosition: objectPosition,
            dimensions: objectDimensions
        )
        let projectedPoints = samples.compactMap {
            projectToGround(point: $0, lightPosition: lightPosition)
        }
        let hull = convexHull(of: projectedPoints)
        guard hull.count >= 3 else {
            entity.isEnabled = false
            return
        }

        let opacityScale: Float = texture.shadowBehavior == .cutout ? 0.72 : 1
        let layers: [(expansion: Float, opacity: Float, height: Float)] = [
            (0.030, 0.10 * opacityScale, surfaceOffset),
            (0.014, 0.18 * opacityScale, surfaceOffset + 0.001),
            (0, 0.36 * opacityScale, surfaceOffset + 0.002)
        ]

        for (index, layer) in layers.enumerated() {
            let points = expanded(hull, by: layer.expansion)
            guard let mesh = makeMesh(points: points, height: layer.height) else { continue }

            let shadowLayer = ModelEntity(
                mesh: mesh,
                materials: [shadowMaterial(opacity: layer.opacity)]
            )
            shadowLayer.name = "Level 1 projected shadow layer \(index)"
            shadowLayer.components.set(DynamicLightShadowComponent(castsShadow: false))
            shadowLayer.components.set(
                GroundingShadowComponent(castsShadow: false, receivesShadow: false)
            )
            entity.addChild(shadowLayer)
        }

        entity.isEnabled = !entity.children.isEmpty
    }

    private static func projectToGround(
        point: SIMD3<Float>,
        lightPosition: SIMD3<Float>
    ) -> SIMD2<Float>? {
        let ray = point - lightPosition
        guard ray.y < -0.0001 else { return nil }

        let distance = (groundY - lightPosition.y) / ray.y
        guard distance >= 0, distance.isFinite, distance <= 12 else { return nil }

        let projected = lightPosition + ray * distance
        return SIMD2<Float>(projected.x, projected.z)
    }

    private static func surfaceSamples(
        for objectType: LearningObjectType,
        objectPosition: SIMD3<Float>,
        dimensions: SIMD3<Float>
    ) -> [SIMD3<Float>] {
        switch objectType {
        case .cube, .cuboid:
            boxSamples(origin: objectPosition, dimensions: dimensions)
        case .sphere:
            sphereSamples(origin: objectPosition, dimensions: dimensions)
        case .cylinder:
            ringSamples(origin: objectPosition, dimensions: dimensions, includesTopRing: true)
        case .cone:
            coneSamples(origin: objectPosition, dimensions: dimensions)
        case .hemisphere:
            hemisphereSamples(origin: objectPosition, dimensions: dimensions)
        case .squarePyramid:
            squarePyramidSamples(origin: objectPosition, dimensions: dimensions)
        case .triangularPyramid:
            triangularPyramidSamples(origin: objectPosition, dimensions: dimensions)
        }
    }

    private static func boxSamples(
        origin: SIMD3<Float>,
        dimensions: SIMD3<Float>
    ) -> [SIMD3<Float>] {
        let halfX = dimensions.x / 2
        let halfZ = dimensions.z / 2
        return [Float(0), dimensions.y].flatMap { y in
            [
                origin + SIMD3<Float>(-halfX, y, -halfZ),
                origin + SIMD3<Float>(halfX, y, -halfZ),
                origin + SIMD3<Float>(halfX, y, halfZ),
                origin + SIMD3<Float>(-halfX, y, halfZ)
            ]
        }
    }

    private static func sphereSamples(
        origin: SIMD3<Float>,
        dimensions: SIMD3<Float>
    ) -> [SIMD3<Float>] {
        let center = origin + SIMD3<Float>(0, dimensions.y / 2, 0)
        var points: [SIMD3<Float>] = []

        for latitudeIndex in 0...8 {
            let latitude = -.pi / 2 + Float(latitudeIndex) * .pi / 8
            let ringScale = cos(latitude)
            let y = sin(latitude) * dimensions.y / 2

            for radialIndex in 0..<sampleCount {
                let angle = Float(radialIndex) * 2 * .pi / Float(sampleCount)
                points.append(
                    center + SIMD3<Float>(
                        cos(angle) * dimensions.x / 2 * ringScale,
                        y,
                        sin(angle) * dimensions.z / 2 * ringScale
                    )
                )
            }
        }
        return points
    }

    private static func ringSamples(
        origin: SIMD3<Float>,
        dimensions: SIMD3<Float>,
        includesTopRing: Bool
    ) -> [SIMD3<Float>] {
        var points: [SIMD3<Float>] = []
        for radialIndex in 0..<sampleCount {
            let angle = Float(radialIndex) * 2 * .pi / Float(sampleCount)
            let x = cos(angle) * dimensions.x / 2
            let z = sin(angle) * dimensions.z / 2
            points.append(origin + SIMD3<Float>(x, 0, z))
            if includesTopRing {
                points.append(origin + SIMD3<Float>(x, dimensions.y, z))
            }
        }
        return points
    }

    private static func coneSamples(
        origin: SIMD3<Float>,
        dimensions: SIMD3<Float>
    ) -> [SIMD3<Float>] {
        ringSamples(origin: origin, dimensions: dimensions, includesTopRing: false)
            + [origin + SIMD3<Float>(0, dimensions.y, 0)]
    }

    private static func hemisphereSamples(
        origin: SIMD3<Float>,
        dimensions: SIMD3<Float>
    ) -> [SIMD3<Float>] {
        var points = ringSamples(origin: origin, dimensions: dimensions, includesTopRing: false)
        for latitudeIndex in 1...4 {
            let progress = Float(latitudeIndex) / 4
            let angle = progress * .pi / 2
            let ringScale = cos(angle)
            let y = sin(angle) * dimensions.y

            for radialIndex in 0..<sampleCount {
                let radialAngle = Float(radialIndex) * 2 * .pi / Float(sampleCount)
                points.append(
                    origin + SIMD3<Float>(
                        cos(radialAngle) * dimensions.x / 2 * ringScale,
                        y,
                        sin(radialAngle) * dimensions.z / 2 * ringScale
                    )
                )
            }
        }
        return points
    }

    private static func squarePyramidSamples(
        origin: SIMD3<Float>,
        dimensions: SIMD3<Float>
    ) -> [SIMD3<Float>] {
        let halfX = dimensions.x / 2
        let halfZ = dimensions.z / 2
        return [
            origin + SIMD3<Float>(-halfX, 0, -halfZ),
            origin + SIMD3<Float>(halfX, 0, -halfZ),
            origin + SIMD3<Float>(halfX, 0, halfZ),
            origin + SIMD3<Float>(-halfX, 0, halfZ),
            origin + SIMD3<Float>(0, dimensions.y, 0)
        ]
    }

    private static func triangularPyramidSamples(
        origin: SIMD3<Float>,
        dimensions: SIMD3<Float>
    ) -> [SIMD3<Float>] {
        return [
            origin + SIMD3<Float>(0, 0, -dimensions.z / 2),
            origin + SIMD3<Float>(-dimensions.x / 2, 0, dimensions.z / 2),
            origin + SIMD3<Float>(dimensions.x / 2, 0, dimensions.z / 2),
            origin + SIMD3<Float>(0, dimensions.y, 0)
        ]
    }

    private static func convexHull(of points: [SIMD2<Float>]) -> [SIMD2<Float>] {
        let sortedPoints = points.sorted {
            $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x
        }
        var uniquePoints: [SIMD2<Float>] = []
        for point in sortedPoints where uniquePoints.last.map({ simd_distance($0, point) > 0.0001 }) ?? true {
            uniquePoints.append(point)
        }
        guard uniquePoints.count > 2 else { return uniquePoints }

        var lower: [SIMD2<Float>] = []
        for point in uniquePoints {
            while lower.count >= 2,
                  cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0 {
                lower.removeLast()
            }
            lower.append(point)
        }

        var upper: [SIMD2<Float>] = []
        for point in uniquePoints.reversed() {
            while upper.count >= 2,
                  cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0 {
                upper.removeLast()
            }
            upper.append(point)
        }

        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }

    private static func cross(
        _ origin: SIMD2<Float>,
        _ first: SIMD2<Float>,
        _ second: SIMD2<Float>
    ) -> Float {
        let firstOffset = first - origin
        let secondOffset = second - origin
        return firstOffset.x * secondOffset.y - firstOffset.y * secondOffset.x
    }

    private static func expanded(
        _ points: [SIMD2<Float>],
        by amount: Float
    ) -> [SIMD2<Float>] {
        guard amount > 0 else { return points }
        let center = points.reduce(.zero, +) / Float(points.count)
        return points.map { point in
            let offset = point - center
            let length = simd_length(offset)
            guard length > 0.0001 else { return point }
            return point + offset / length * amount
        }
    }

    private static func makeMesh(
        points: [SIMD2<Float>],
        height: Float
    ) -> MeshResource? {
        guard points.count >= 3 else { return nil }
        let positions = points.map { SIMD3<Float>($0.x, height, $0.y) }
        var indices: [UInt32] = []
        for index in 1..<(points.count - 1) {
            indices.append(contentsOf: [0, UInt32(index + 1), UInt32(index)])
        }

        var descriptor = MeshDescriptor(name: "Level 1 projected shadow")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.primitives = .triangles(indices)
        return try? MeshResource.generate(from: [descriptor])
    }

    private static func shadowMaterial(opacity: Float) -> UnlitMaterial {
        var material = UnlitMaterial()
        material.color = .init(tint: .black)
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        material.faceCulling = .none
        material.readsDepth = true
        material.writesDepth = false
        return material
    }
}
