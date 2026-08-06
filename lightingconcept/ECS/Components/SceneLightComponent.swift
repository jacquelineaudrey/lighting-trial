/// Component ECS untuk lampu di scene.
///
/// Component ini adalah data yang dimiliki sebuah `SceneEntity` di `ARSceneWorld`.
/// Ia tidak menentukan identity lampu; identity ada di `SceneEntity` dan mapping-nya
/// diatur oleh world.
struct SceneLightComponent {
    /// Data domain dari UI/ViewModel: tipe lampu, warna, intensitas, posisi,
    /// orientasi, dan beam spread.
    var configuration: LightConfiguration

    /// Handle ke kumpulan entity RealityKit yang menampilkan lampu di AR.
    /// Ini hanya detail rendering runtime. ECS tetap melihatnya sebagai data
    /// component, bukan sebagai entity ECS baru.
    var realityKitEntities: RealityKitLightEntityBundle
}
