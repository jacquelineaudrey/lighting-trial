import Foundation
import RealityKit
import simd

/// System untuk collision sederhana antar object/light virtual.
///
/// Ini disebut system karena menyimpan dan memproses aturan gerak, bukan sekadar
/// data. Obstacle diregistrasi oleh `SceneObjectSystem` dan `SceneLightSystem`
/// setiap kali object/light dibuat, dipindah, atau dihapus.
final class CollisionSystem {
    /// Data internal untuk collision. Tidak dibuat sebagai component terpisah
    /// karena collision di app ini masih sederhana: cukup posisi pusat + radius.
    private struct Obstacle {
        var position: SIMD3<Float>
        var radius: Float
    }

    /// Key tetap UUID model supaya coordinator/ViewModel mudah meminta pengecualian
    /// untuk object/light yang sedang digerakkan.
    private var obstacles: [UUID: Obstacle] = [:]
    private(set) var lastCollisionBlocked = false

    /// Mendaftarkan atau mengganti obstacle.
    func registerObstacle(id: UUID, position: SIMD3<Float>, radius: Float) {
        obstacles[id] = Obstacle(position: position, radius: radius)
    }

    /// Update posisi obstacle tanpa mengubah radius.
    func updatePosition(id: UUID, position: SIMD3<Float>) {
        obstacles[id]?.position = position
    }

    /// Menghapus obstacle ketika entity model sudah dihapus dari world.
    func removeObstacle(id: UUID) {
        obstacles[id] = nil
    }

    /// Reset total saat scene AR di-reset/rescan.
    func removeAll() {
        obstacles.removeAll()
    }

    /// Mengembalikan posisi yang sudah disesuaikan supaya tidak overlap dengan
    /// obstacle lain dan tetap berada dalam batas area kerja.
    ///
    /// `excludingID` dipakai agar entity yang sedang digerakkan tidak bertabrakan
    /// dengan obstacle miliknya sendiri.
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

        // Push-out dan clamp dilakukan berulang supaya keluar dari satu obstacle
        // tidak diam-diam masuk ke obstacle lain, dan clamp ke batas area tidak
        // memasukkan entity kembali ke overlap.
        for _ in 0..<4 {
            var movedThisPass = false

            for (id, obstacle) in obstacles where id != excludingID {
                let combinedRadius = movingRadius + obstacle.radius
                let verticalDistance = abs(resolved.y - obstacle.position.y)
                guard verticalDistance < combinedRadius else { continue }

                let delta = SIMD3<Float>(resolved.x - obstacle.position.x, 0, resolved.z - obstacle.position.z)
                let horizontalDistance = simd_length(delta)
                let minimumHorizontalDistance = sqrt(
                    max(combinedRadius * combinedRadius - verticalDistance * verticalDistance, 0)
                )

                guard horizontalDistance < minimumHorizontalDistance - 0.0001 else { continue }
                collided = true
                movedThisPass = true

                if horizontalDistance > 0.0001 {
                    let pushDirection = delta / horizontalDistance
                    resolved.x = obstacle.position.x + pushDirection.x * minimumHorizontalDistance
                    resolved.z = obstacle.position.z + pushDirection.z * minimumHorizontalDistance
                } else {
                    resolved.x = obstacle.position.x + minimumHorizontalDistance
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
