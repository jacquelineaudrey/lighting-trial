import RealityKit
import UIKit

enum ObjectFactory {
    static let cubeSize: Float = 0.12
    static let sphereRadius: Float = 0.06

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
        case .cylinder:
            mesh = .generateCylinder(height: cubeSize, radius: sphereRadius)
            height = cubeSize
        case .cone:
            mesh = .generateCone(height: cubeSize, radius: sphereRadius)
            height = cubeSize
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
        case .cylinder, .cone:
            cubeSize
        }
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
}
