import RealityKit
import UIKit

/// Builds the placed learning object (cube or sphere). Reconstructed from
/// how ARSceneCoordinator and ShadowGeometryCalculatorTests use it.
enum ObjectFactory {
    static let cubeSize: Float = 0.14
    static let sphereRadius: Float = 0.08

    static func makeObject(type: LearningObjectType, texture: MaterialTexture = .defaultGrid) -> ModelEntity {
        let mesh: MeshResource
        switch type {
        case .cube:
            mesh = .generateBox(size: cubeSize)
        case .sphere:
            mesh = .generateSphere(radius: sphereRadius)
        }

        let entity = ModelEntity(mesh: mesh, materials: [texture.makeMaterial()])
        entity.name = "LearningObject"

        // Needed for the new collision feature: lets CollisionManager /
        // RealityKit reason about this entity's footprint.
        entity.generateCollisionShapes(recursive: true)
        entity.components.set(GroundingShadowComponent(castsShadow: true))

        return entity
    }

    static func objectHeight(for type: LearningObjectType) -> Float {
        switch type {
        case .cube: cubeSize
        case .sphere: sphereRadius * 2
        }
    }

    /// RealityKit's primitive meshes are centred on their local origin. This
    /// is the amount the object must be raised so its base rests on the AR
    /// surface instead of being embedded halfway through it.
    static func groundOffset(for type: LearningObjectType) -> Float {
        switch type {
        case .cube: cubeSize / 2
        case .sphere: sphereRadius
        }
    }

    /// Horizontal bounding radius used by CollisionManager to keep other
    /// AR content from being dragged through this object.
    static func boundingRadius(for type: LearningObjectType) -> Float {
        switch type {
        case .cube: cubeSize * 0.75 // half-diagonal-ish, a bit generous
        case .sphere: sphereRadius
        }
    }
}
