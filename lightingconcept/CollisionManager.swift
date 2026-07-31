import Foundation
import RealityKit
import simd

final class CollisionManager {
    private struct Obstacle {
        var position: SIMD3<Float>
        var radius: Float
    }

    private var obstacles: [UUID: Obstacle] = [:]
    private(set) var lastCollisionBlocked = false

    func registerObstacle(id: UUID, position: SIMD3<Float>, radius: Float) {
        obstacles[id] = Obstacle(position: position, radius: radius)
    }

    func updatePosition(id: UUID, position: SIMD3<Float>) {
        obstacles[id]?.position = position
    }

    func removeObstacle(id: UUID) {
        obstacles[id] = nil
    }

    func removeAll() {
        obstacles.removeAll()
    }

    @discardableResult
    func resolvedPosition(
        candidatePosition: SIMD3<Float>,
        movingRadius: Float,
        excludingID: UUID,
        bounds: ClosedRange<Float> = -0.7...0.7
    ) -> (position: SIMD3<Float>, didCollide: Bool) {
        var resolved = candidatePosition
        resolved.x = min(max(resolved.x, bounds.lowerBound), bounds.upperBound)
        resolved.z = min(max(resolved.z, bounds.lowerBound), bounds.upperBound)
        var collided = false

        // Push-out + clamp are interleaved and repeated, so pushing out of
        // one obstacle can't silently drop you inside another, and clamping
        // to bounds can't silently drop you back inside an obstacle.
        for _ in 0..<4 {
            var movedThisPass = false

            for (id, obstacle) in obstacles where id != excludingID {
                let delta = SIMD3<Float>(resolved.x - obstacle.position.x, 0, resolved.z - obstacle.position.z)
                let distance = simd_length(delta)
                let minimumDistance = movingRadius + obstacle.radius

                guard distance < minimumDistance - 0.0001 else { continue }
                collided = true
                movedThisPass = true

                if distance > 0.0001 {
                    let pushDirection = delta / distance
                    resolved.x = obstacle.position.x + pushDirection.x * minimumDistance
                    resolved.z = obstacle.position.z + pushDirection.z * minimumDistance
                } else {
                    resolved.x = obstacle.position.x + minimumDistance
                }
            }

            resolved.x = min(max(resolved.x, bounds.lowerBound), bounds.upperBound)
            resolved.z = min(max(resolved.z, bounds.lowerBound), bounds.upperBound)

            if !movedThisPass { break }
        }

        lastCollisionBlocked = collided
        return (resolved, collided)
    }
}
