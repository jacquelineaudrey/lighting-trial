import RealityKit

/// Bundle entity RealityKit untuk satu lampu visual di AR scene.
///
/// Ini BUKAN entity ECS.
///
/// Kenapa perlu bundle?
/// Satu lampu di domain aplikasi (`LightConfiguration`) tidak cukup diwakili
/// oleh satu `RealityKit.Entity`. Untuk UX dan rendering, satu lampu terdiri dari:
/// - `root`: parent agar semua child mudah ditempel/dihapus dari scene,
/// - `light`: entity yang memegang `PointLightComponent` atau `SpotLightComponent`,
/// - `fillLight`: point light kecil untuk menjaga object tetap terbaca,
/// - `marker`: bola kecil yang bisa dilihat dan ditap user,
/// - `selectionRing`: indikator visual saat lampu sedang dipilih.
///
/// Dalam flow ECS:
/// `SceneEntity` -> `SceneLightComponent` -> `RealityKitLightEntityBundle`
///
/// Jadi ECS tetap menganggap lampu sebagai satu entity identity, sementara bundle
/// ini hanya detail implementasi AR/RealityKit untuk menampilkan entity tersebut.
struct RealityKitLightEntityBundle {
    let root: Entity
    let light: Entity
    let fillLight: Entity
    let marker: ModelEntity
    let selectionRing: ModelEntity
}
