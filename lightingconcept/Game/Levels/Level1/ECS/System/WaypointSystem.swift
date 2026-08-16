//
//  WaypointSystem.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import RealityKit
import QuartzCore

final class WaypointSystem: System {
    private static let indicatorQuery = EntityQuery(where: .has(WaypointIndicatorComponent.self))
    private static let cameraQuery = EntityQuery(where: .has(PerspectiveCameraComponent.self))
    
    init(scene: RealityKit.Scene) {}
    
    func update(context: SceneUpdateContext) {
        // FIX: Safely extract the first element since RealityKit's QueryCollection lacks a '.first' property
        var activeCamera: Entity?
        for entity in context.entities(matching: Self.cameraQuery, updatingSystemWhen: .rendering) {
            activeCamera = entity
            break
        }
        
        guard let camera = activeCamera else { return }
        
        let cameraTransform = camera.transformMatrix(relativeTo: nil)
        let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let forward3D = -SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
        let horizontalForward3D = SIMD3<Float>(forward3D.x, 0, forward3D.z)
        let forwardLength = simd_length(horizontalForward3D)

        guard forwardLength > 0.0001 else { return }
        let normalizedForward = horizontalForward3D / forwardLength
        let time = Float(CACurrentMediaTime())

        for entity in context.entities(matching: Self.indicatorQuery, updatingSystemWhen: .rendering) {
            guard let indicator = entity.components[WaypointIndicatorComponent.self],
                  let targetPosition = indicator.targetPosition,
                  entity.isEnabled else { continue }

            let forwardBackward = sin(time * indicator.moveSpeed) * indicator.moveAmplitude
            let verticalFloat = sin(time * indicator.floatSpeed) * indicator.floatAmplitude

            let position = cameraPosition
                + normalizedForward * (indicator.forwardOffset + forwardBackward)
                + SIMD3<Float>(0, indicator.heightOffset + verticalFloat, 0)

            let targetXZ = SIMD3<Float>(targetPosition.x, position.y, targetPosition.z)
            entity.look(at: targetXZ, from: position, relativeTo: nil)
        }
    }
}
