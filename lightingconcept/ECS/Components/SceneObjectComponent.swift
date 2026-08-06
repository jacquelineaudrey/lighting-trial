import RealityKit

/// Component untuk objek pembelajaran di scene.
struct SceneObjectComponent {
    /// Data domain dari MVVM layer. System membaca konfigurasi ini lalu
    /// menerjemahkannya ke transform/material RealityKit.
    var configuration: ObjectConfiguration

    /// Referensi ke `RealityKit.Entity` yang benar-benar tampil di AR.
    /// Ini bukan entity ECS; ini hanya data rendering yang dibutuhkan system.
    var realityKitEntity: Entity

    /// Dipakai untuk mendeteksi kapan mesh harus diganti, misalnya user mengganti
    /// bentuk primitive atau file imported model.
    var sourceKey: String

    /// Task async untuk load imported model. Disimpan di component agar bisa
    /// dibatalkan saat objek dihapus atau diganti sebelum load selesai.
    var loadTask: Task<Void, Never>?
}
