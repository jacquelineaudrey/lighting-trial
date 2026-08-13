import Foundation
import RealityKit
import simd

/// System RealityKit untuk entity yang punya `CollisionObstacleComponent`.
///
/// `update(context:)` sengaja ringan karena dipanggil setiap frame oleh RealityKit.
/// Collision resolving dipakai saat gesture atau sync scene, jadi disediakan sebagai
/// static function pada system ini tanpa menyimpan state entity di dalam system.
final class CollisionSystem: System {
    private static let query = EntityQuery(where: .has(CollisionObstacleComponent.self))

    required init(scene: Scene) {
    }

    func update(context: SceneUpdateContext) {
        for _ in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            // Query ini membuat RealityKit menjalankan system untuk entity collision.
            // Tidak ada pekerjaan per-frame yang diperlukan saat ini; collision dihitung
            // hanya saat user menggeser object/light agar CPU tetap rendah.
        }
    }

    static func setObstacle(on entity: Entity, id: UUID, radius: Float) {
        entity.components.set(CollisionObstacleComponent(id: id, radius: radius))
    }

    static func removeObstacle(from entity: Entity) {
        entity.components.remove(CollisionObstacleComponent.self)
    }

    static func resolvedPosition(
        in root: Entity,
        candidatePosition: SIMD3<Float>,
        movingRadius: Float,
        excludingID: UUID,
        bounds: ClosedRange<Float> = -0.7...0.7
    ) -> (position: SIMD3<Float>, didCollide: Bool) {
        var resolved = candidatePosition
        resolved.x = min(max(resolved.x, bounds.lowerBound), bounds.upperBound)
        resolved.z = min(max(resolved.z, bounds.lowerBound), bounds.upperBound)
        var collided = false

        for _ in 0..<4 {
            var movedThisPass = false

            for obstacleEntity in entitiesWithCollisionObstacle(in: root) {
                guard let obstacle = obstacleEntity.components[CollisionObstacleComponent.self],
                      obstacle.id != excludingID else { continue }

                let combinedRadius = movingRadius + obstacle.radius
                let obstaclePosition = obstacleEntity.position(relativeTo: root)
                let verticalDistance = abs(resolved.y - obstaclePosition.y)
                guard verticalDistance < combinedRadius else { continue }

                let delta = SIMD3<Float>(resolved.x - obstaclePosition.x, 0, resolved.z - obstaclePosition.z)
                let horizontalDistance = simd_length(delta)
                let minimumHorizontalDistance = sqrt(
                    max(combinedRadius * combinedRadius - verticalDistance * verticalDistance, 0)
                )

                guard horizontalDistance < minimumHorizontalDistance - 0.0001 else { continue }
                collided = true
                movedThisPass = true

                if horizontalDistance > 0.0001 {
                    let pushDirection = delta / horizontalDistance
                    resolved.x = obstaclePosition.x + pushDirection.x * minimumHorizontalDistance
                    resolved.z = obstaclePosition.z + pushDirection.z * minimumHorizontalDistance
                } else {
                    resolved.x = obstaclePosition.x + minimumHorizontalDistance
                }
            }

            resolved.x = min(max(resolved.x, bounds.lowerBound), bounds.upperBound)
            resolved.z = min(max(resolved.z, bounds.lowerBound), bounds.upperBound)

            if !movedThisPass { break }
        }

        return (resolved, collided)
    }

    private static func entitiesWithCollisionObstacle(in root: Entity) -> [Entity] {
        var result: [Entity] = []
        collectEntitiesWithCollisionObstacle(from: root, into: &result)
        return result
    }

    private static func collectEntitiesWithCollisionObstacle(from entity: Entity, into result: inout [Entity]) {
        if entity.components[CollisionObstacleComponent.self] != nil {
            result.append(entity)
        }
        for child in entity.children {
            collectEntitiesWithCollisionObstacle(from: child, into: &result)
        }
    }
}
