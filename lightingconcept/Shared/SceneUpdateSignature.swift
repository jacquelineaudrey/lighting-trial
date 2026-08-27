import Foundation

/// Signature untuk perubahan objek yang perlu menjalankan `SceneObjectSystem.synchronize`.
/// Dipisah dari signature lampu supaya drag intensitas/beam lampu tidak memicu
/// diff ulang seluruh object array (dan sebaliknya).
struct SceneObjectsSyncSignature: Equatable {
    var objects: [ObjectConfiguration]
    var selectedObjectID: UUID
    var selectedTexture: MaterialTexture
}

/// Signature untuk perubahan lampu yang perlu menjalankan `SceneLightSystem.synchronize`.
/// State UI seperti panel informasi tidak masuk ke sini supaya tidak memicu rebuild AR.
struct SceneLightsSyncSignature: Equatable {
    var lights: [LightConfiguration]
    var selectedLightID: UUID
}

/// Signature untuk `synchronizeLessonECS`. Sebelumnya fungsi ini jalan tanpa syarat
/// di setiap panggilan `synchronizeScene()` (termasuk tiap delta gesture drag),
/// jadi dibatasi ke properti yang benar-benar ditulis ke komponen lesson ECS.
struct LessonECSSignature: Equatable {
    var selectedLightID: UUID
    var lightIntensity: Float
    var lightOuterAngleDegrees: Float
    var lightType: LearningLightType
    var selectedObjectID: UUID
    var castsShadow: Bool
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
    // Intensity intentionally excluded: it never changes overlay geometry,
    // only direction/position/spread do. This prevents intensity drags from
    // triggering projection-line rebuilds.
    var showLightDirection: Bool
    var showLightRays: Bool
    var showProjectionLines: Bool
    var showGroundProjection: Bool
    var showShadowLabels: Bool
    var hiddenShadowConcepts: Set<ShadowConcept>
}

/// Signature untuk panel shadow info. Dipisah dari overlay karena update panel teks
/// tidak perlu membuat ulang line/marker RealityKit.
struct ShadowInfoUpdateSignature: Equatable {
    var selectedObject: ObjectConfiguration
    var selectedLight: LightConfiguration
}
