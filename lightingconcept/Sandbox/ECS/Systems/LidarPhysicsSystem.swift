//
//  LidarPhysicsSystem.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import Foundation
import RealityKit

/// Native RealityKit ECS system for LiDAR-aware scene interaction.
///
/// RealityKit owns the frame loop. SwiftUI does not poll or move AR entities.
/// The system queries entities carrying `LidarInteractableComponent`, raycasts
/// against RealityKit collision geometry (including scene-understanding meshes),
/// and updates the component every scene update.
@MainActor
struct LidarPhysicsSystem: RealityKit.System {
    private static let query = EntityQuery(
        where: .has(LidarInteractableComponent.self)
    )

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)
        guard deltaTime.isFinite, deltaTime > 0 else { return }

        context.scene.performQuery(Self.query).forEach { entity in
            guard var component = entity.components[LidarInteractableComponent.self] else {
                return
            }

            let worldPosition = entity.position(relativeTo: nil)
            let rayLength: Float = 2.0
            let down = SIMD3<Float>(0, -1, 0)

            let hits = context.scene.raycast(
                origin: worldPosition,
                direction: down,
                length: rayLength,
                query: .nearest,
                mask: .all,
                relativeTo: nil
            )

            if let hit = hits.first {
                component.surfaceDistance = max(0, worldPosition.y - hit.position.y)
                component.isAnchoredToMesh = component.surfaceDistance <= 0.02

                if component.usesGravity {
                    if component.surfaceDistance > 0.02 {
                        component.velocity.y -= 9.81 * component.mass * deltaTime
                        let nextY = worldPosition.y + component.velocity.y * deltaTime
                        let clampedY = max(nextY, hit.position.y)
                        var nextPosition = worldPosition
                        nextPosition.y = clampedY
                        entity.setPosition(nextPosition, relativeTo: nil)
                    } else {
                        component.velocity.y = 0
                        var groundedPosition = worldPosition
                        groundedPosition.y = hit.position.y
                        entity.setPosition(groundedPosition, relativeTo: nil)
                    }
                }
            } else {
                component.surfaceDistance = .greatestFiniteMagnitude
                component.isAnchoredToMesh = false

                if component.usesGravity {
                    component.velocity.y -= 9.81 * component.mass * deltaTime
                    var nextPosition = worldPosition
                    nextPosition.y += component.velocity.y * deltaTime
                    entity.setPosition(nextPosition, relativeTo: nil)
                }
            }

            entity.components[LidarInteractableComponent.self] = component
        }
    }
}
