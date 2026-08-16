import Foundation

/// Signature untuk perubahan yang benar-benar perlu menjalankan ECS object/light system.
/// State UI seperti panel informasi tidak masuk ke sini supaya tidak memicu rebuild AR.
struct SceneUpdateSignature: Equatable {
    var objects: [ObjectConfiguration]
    var selectedObjectID: UUID
    var selectedTexture: MaterialTexture
    var lights: [LightConfiguration]
    var selectedLightID: UUID
}

/// Signature untuk overlay edukasi. Field light dibatasi ke properti yang memang
/// memengaruhi arah/posisi garis overlay. Perubahan warna/intensitas lampu tidak
/// perlu membuat ulang projection line.
struct SceneOverlayUpdateSignature: Equatable {
    var selectedObject: ObjectConfiguration
    var selectedObjectType: LearningObjectType
    var selectedLightID: UUID
    var selectedLightType: LearningLightType
    var selectedLightPosition: SIMD3<Float>
    var selectedLightYawDegrees: Float
    var selectedLightPitchDegrees: Float
    var selectedLightBeamSpread: BeamSpreadPreset
    var selectedLightOuterAngleDegrees: Float?
    var selectedLightIntensity: Float
    var showLightDirection: Bool
    var showLightRays: Bool
    var showProjectionLines: Bool
    var showGroundProjection: Bool
    var showShadowLabels: Bool
}

/// Signature untuk panel shadow info. Dipisah dari overlay karena update panel teks
/// tidak perlu membuat ulang line/marker RealityKit.
struct ShadowInfoUpdateSignature: Equatable {
    var selectedObject: ObjectConfiguration
    var selectedLight: LightConfiguration
}
