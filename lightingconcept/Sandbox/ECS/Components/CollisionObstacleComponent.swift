import Foundation
import RealityKit

/// Component data untuk entity yang ikut collision virtual sederhana.
///
/// Position tidak disimpan di sini karena posisi sudah menjadi transform milik
/// `RealityKit.Entity`. Component cukup menyimpan identity domain dan radius yang
/// dipakai `CollisionSystem` untuk menghitung jarak antar entity.
struct CollisionObstacleComponent: Component {
    var id: UUID
    var radius: Float

    init(id: UUID, radius: Float) {
        self.id = id
        self.radius = radius
    }
}
