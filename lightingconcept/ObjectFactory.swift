import RealityKit
import UIKit

enum ObjectFactory {
    static let cubeSize: Float = 0.12
    static let sphereRadius: Float = 0.06
    static let cuboidSize = SIMD3<Float>(0.17, 0.10, 0.11)
    static let cylinderHeight: Float = 0.14
    static let cylinderRadius: Float = 0.05
    static let coneHeight: Float = 0.14
    static let coneRadius: Float = 0.06
    static let hemisphereRadius: Float = 0.07
    static let squarePyramidSize: Float = 0.13
    static let squarePyramidHeight: Float = 0.15
    static let triangularPyramidSize: Float = 0.15
    static let triangularPyramidHeight: Float = 0.15

    static func makeObject(type: LearningObjectType, texture: MaterialTexture = .defaultGrid) -> ModelEntity {
        let mesh: MeshResource
        let height: Float

        switch type {
        case .cube:
            mesh = .generateBox(size: cubeSize)
            height = cubeSize
        case .sphere:
            mesh = .generateSphere(radius: sphereRadius)
            height = sphereRadius * 2
        case .cuboid:
            mesh = .generateBox(size: cuboidSize)
            height = cuboidSize.y
        case .cylinder:
            mesh = .generateCylinder(height: cylinderHeight, radius: cylinderRadius)
            height = cylinderHeight
        case .cone:
            mesh = .generateCone(height: coneHeight, radius: coneRadius)
            height = coneHeight
        case .hemisphere:
            mesh = makeHemisphere(radius: hemisphereRadius)
            height = hemisphereRadius
        case .squarePyramid:
            mesh = makeSquarePyramid(baseSize: squarePyramidSize, height: squarePyramidHeight)
            height = squarePyramidHeight
        case .triangularPyramid:
            mesh = makeTriangularPyramid(baseSize: triangularPyramidSize, height: triangularPyramidHeight)
            height = triangularPyramidHeight
        }

        let material = texture.makeMaterial()
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = type.rawValue
        entity.position.y = height / 2
        entity.generateCollisionShapes(recursive: false)
        entity.components.set(DynamicLightShadowComponent(castsShadow: true))
        return entity
    }

    static func objectHeight(for type: LearningObjectType) -> Float {
        switch type {
        case .cube:
            cubeSize
        case .sphere:
            sphereRadius * 2
        case .cuboid:
            cuboidSize.y
        case .cylinder:
            cylinderHeight
        case .cone:
            coneHeight
        case .hemisphere:
            hemisphereRadius
        case .squarePyramid:
            squarePyramidHeight
        case .triangularPyramid:
            triangularPyramidHeight
        }
    }

    static func baseDimensions(for type: LearningObjectType) -> SIMD3<Float> {
        switch type {
        case .cube:
            SIMD3<Float>(repeating: cubeSize)
        case .sphere:
            SIMD3<Float>(repeating: sphereRadius * 2)
        case .cuboid:
            cuboidSize
        case .cylinder:
            SIMD3<Float>(cylinderRadius * 2, cylinderHeight, cylinderRadius * 2)
        case .cone:
            SIMD3<Float>(coneRadius * 2, coneHeight, coneRadius * 2)
        case .hemisphere:
            SIMD3<Float>(hemisphereRadius * 2, hemisphereRadius, hemisphereRadius * 2)
        case .squarePyramid:
            SIMD3<Float>(squarePyramidSize, squarePyramidHeight, squarePyramidSize)
        case .triangularPyramid:
            SIMD3<Float>(triangularPyramidSize, triangularPyramidHeight, triangularPyramidSize)
        }
    }

    static func baseDimensions(for object: ObjectConfiguration) -> SIMD3<Float> {
        object.importedModel?.dimensions ?? baseDimensions(for: object.type)
    }

    static func objectHeight(for object: ObjectConfiguration) -> Float {
        baseDimensions(for: object).y
    }

    static func collisionRadius(for object: ObjectConfiguration) -> Float {
        simd_length(baseDimensions(for: object) * object.scale) / 2
    }

    static func cubeTopVertices(center: SIMD3<Float>) -> [SIMD3<Float>] {
        let half = cubeSize / 2
        return [
            center + SIMD3<Float>(-half, half, -half),
            center + SIMD3<Float>(half, half, -half),
            center + SIMD3<Float>(-half, half, half),
            center + SIMD3<Float>(half, half, half)
        ]
    }

    private static func makeSquarePyramid(baseSize: Float, height: Float) -> MeshResource {
        let halfBase = baseSize / 2
        let halfHeight = height / 2
        let vertices = [
            SIMD3<Float>(-halfBase, -halfHeight, -halfBase),
            SIMD3<Float>(halfBase, -halfHeight, -halfBase),
            SIMD3<Float>(halfBase, -halfHeight, halfBase),
            SIMD3<Float>(-halfBase, -halfHeight, halfBase),
            SIMD3<Float>(0, halfHeight, 0)
        ]
        return makeTriangleMesh(
            name: "Square Pyramid",
            triangles: [
                (vertices[0], vertices[1], vertices[2]),
                (vertices[0], vertices[2], vertices[3]),
                (vertices[0], vertices[4], vertices[1]),
                (vertices[1], vertices[4], vertices[2]),
                (vertices[2], vertices[4], vertices[3]),
                (vertices[3], vertices[4], vertices[0])
            ],
            center: .zero
        )
    }

    private static func makeTriangularPyramid(baseSize: Float, height: Float) -> MeshResource {
        let halfHeight = height / 2
        let baseRadius = baseSize / sqrt(3)
        let vertices = [
            SIMD3<Float>(0, -halfHeight, -baseRadius),
            SIMD3<Float>(-baseSize / 2, -halfHeight, baseRadius / 2),
            SIMD3<Float>(baseSize / 2, -halfHeight, baseRadius / 2),
            SIMD3<Float>(0, halfHeight, 0)
        ]
        return makeTriangleMesh(
            name: "Triangular Pyramid",
            triangles: [
                (vertices[0], vertices[2], vertices[1]),
                (vertices[0], vertices[3], vertices[2]),
                (vertices[2], vertices[3], vertices[1]),
                (vertices[1], vertices[3], vertices[0])
            ],
            center: .zero
        )
    }

    private static func makeHemisphere(radius: Float) -> MeshResource {
        let verticalSegments = 8
        let radialSegments = 24
        let sphereCenter = SIMD3<Float>(0, -radius / 2, 0)
        var triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = []

        for verticalIndex in 0..<verticalSegments {
            let phi0 = Float(verticalIndex) / Float(verticalSegments) * (.pi / 2)
            let phi1 = Float(verticalIndex + 1) / Float(verticalSegments) * (.pi / 2)

            for radialIndex in 0..<radialSegments {
                let theta0 = Float(radialIndex) / Float(radialSegments) * (.pi * 2)
                let theta1 = Float(radialIndex + 1) / Float(radialSegments) * (.pi * 2)
                let upperLeft = hemispherePoint(radius: radius, phi: phi0, theta: theta0)
                let upperRight = hemispherePoint(radius: radius, phi: phi0, theta: theta1)
                let lowerLeft = hemispherePoint(radius: radius, phi: phi1, theta: theta0)
                let lowerRight = hemispherePoint(radius: radius, phi: phi1, theta: theta1)

                if verticalIndex == 0 {
                    triangles.append((upperLeft, lowerLeft, lowerRight))
                } else {
                    triangles.append((upperLeft, lowerLeft, lowerRight))
                    triangles.append((upperLeft, lowerRight, upperRight))
                }
            }
        }

        let baseCenter = SIMD3<Float>(0, -radius / 2, 0)
        for radialIndex in 0..<radialSegments {
            let theta0 = Float(radialIndex) / Float(radialSegments) * (.pi * 2)
            let theta1 = Float(radialIndex + 1) / Float(radialSegments) * (.pi * 2)
            triangles.append((
                baseCenter,
                hemispherePoint(radius: radius, phi: .pi / 2, theta: theta0),
                hemispherePoint(radius: radius, phi: .pi / 2, theta: theta1)
            ))
        }

        return makeTriangleMesh(name: "Hemisphere", triangles: triangles, center: sphereCenter)
    }

    private static func hemispherePoint(radius: Float, phi: Float, theta: Float) -> SIMD3<Float> {
        let ringRadius = sin(phi) * radius
        return SIMD3<Float>(
            cos(theta) * ringRadius,
            cos(phi) * radius - radius / 2,
            sin(theta) * ringRadius
        )
    }

    private static func makeTriangleMesh(
        name: String,
        triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)],
        center: SIMD3<Float>
    ) -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        for triangle in triangles {
            var first = triangle.0
            var second = triangle.1
            var third = triangle.2
            var normal = simd_normalize(simd_cross(second - first, third - first))
            let faceCenter = (first + second + third) / 3

            if simd_dot(normal, faceCenter - center) < 0 {
                swap(&second, &third)
                normal = -normal
            }

            let startIndex = UInt32(positions.count)
            positions.append(contentsOf: [first, second, third])
            normals.append(contentsOf: [normal, normal, normal])
            indices.append(contentsOf: [startIndex, startIndex + 1, startIndex + 2])
        }

        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)

        return (try? MeshResource.generate(from: [descriptor])) ?? .generateBox(size: 0.1)
    }
}
