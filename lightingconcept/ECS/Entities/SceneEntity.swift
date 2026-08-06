import Foundation

/// Entity dalam ECS hanya identitas.
///
/// File ini sengaja tidak menyimpan posisi, mesh, light, atau function behavior.
/// Data disimpan di Component, sedangkan logic dijalankan oleh System.
/// `SceneEntity` dipakai sebagai key di `ARSceneWorld` untuk mencari component
/// yang dimiliki satu objek scene.
struct SceneEntity: Hashable, Identifiable {
    let id: UUID

    /// ID dapat dibuat baru untuk entity internal, atau disamakan dengan UUID model
    /// agar mudah dijembatani dari `ObjectConfiguration` / `LightConfiguration`.
    init(id: UUID = UUID()) {
        self.id = id
    }
}
