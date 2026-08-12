import RealityKit

/// Component data untuk satu lampu di scene.
///
/// Component ini hanya menyimpan state domain lampu. Entity RealityKit yang memegang
/// component ini adalah root container untuk child visual seperti emitter, marker,
/// dan selection ring. Logic update warna, intensitas, arah, serta selection ada di
/// `SceneLightSystem`.
struct SceneLightComponent: Component {
    var configuration: LightConfiguration
    var isSelected: Bool

    init(configuration: LightConfiguration, isSelected: Bool) {
        self.configuration = configuration
        self.isSelected = isSelected
    }
}
