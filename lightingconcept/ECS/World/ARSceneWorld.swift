import Foundation
import RealityKit

@MainActor
/// Registry utama ECS untuk AR scene.
///
/// Format data yang dipakai:
/// - `SceneEntity` adalah identity ECS.
/// - `objectComponents[sceneEntity]` menyimpan data object untuk entity itu.
/// - `lightComponents[sceneEntity]` menyimpan data light untuk entity itu.
/// - `objectEntitiesByModelID` dan `lightEntitiesByModelID` adalah bridge dari
///   UUID model MVVM ke identity ECS.
///
/// Kenapa ada bridge UUID model -> SceneEntity?
/// UI masih bekerja dengan `ObjectConfiguration.id` dan `LightConfiguration.id`.
/// Agar UI tidak perlu tahu ECS, world membuat mapping stabil dari UUID model ke
/// `SceneEntity`. System bisa tetap memproses ECS, sementara ViewModel tetap
/// memakai model SwiftUI yang sederhana.
final class ARSceneWorld {
    /// Anchor RealityKit tempat semua entity visual scene ditempel.
    /// Ini bagian integrasi AR, bukan identity ECS.
    var anchor: AnchorEntity?

    /// Mapping dari ID model object ke entity ECS.
    /// World yang memegang relasi ini, bukan component.
    var objectEntitiesByModelID: [UUID: SceneEntity] = [:]

    /// Mapping dari ID model light ke entity ECS.
    var lightEntitiesByModelID: [UUID: SceneEntity] = [:]

    /// Component store untuk objek. Key-nya entity ECS.
    var objectComponents: [SceneEntity: SceneObjectComponent] = [:]

    /// Component store untuk lampu. Key-nya entity ECS.
    var lightComponents: [SceneEntity: SceneLightComponent] = [:]

    /// Cache texture terakhir supaya object system tahu kapan primitive mesh
    /// perlu dibuat ulang dengan material baru.
    var lastTexture: MaterialTexture?

    /// Menghapus seluruh state ECS dan seluruh entity RealityKit yang sedang
    /// ditempel ke scene. Dipakai saat reset/rescan AR.
    func reset() {
        for object in objectComponents.values {
            object.loadTask?.cancel()
            object.realityKitEntity.removeFromParent()
        }
        for light in lightComponents.values {
            light.realityKitEntities.root.removeFromParent()
        }
        anchor?.removeFromParent()
        anchor = nil
        objectEntitiesByModelID.removeAll()
        lightEntitiesByModelID.removeAll()
        objectComponents.removeAll()
        lightComponents.removeAll()
        lastTexture = nil
    }

    /// Mengambil entity ECS untuk object model tertentu.
    /// Jika belum ada, world membuat identity baru dan menyimpan mapping-nya.
    func sceneEntity(forObjectID id: UUID) -> SceneEntity {
        if let existing = objectEntitiesByModelID[id] {
            return existing
        }
        let entity = SceneEntity(id: id)
        objectEntitiesByModelID[id] = entity
        return entity
    }

    /// Mengambil entity ECS untuk light model tertentu.
    func sceneEntity(forLightID id: UUID) -> SceneEntity {
        if let existing = lightEntitiesByModelID[id] {
            return existing
        }
        let entity = SceneEntity(id: id)
        lightEntitiesByModelID[id] = entity
        return entity
    }

    /// Helper bridge untuk AR coordinator yang masih butuh `RealityKit.Entity`
    /// saat gesture, raycast selection, dan overlay menghitung transform visual.
    func objectRealityKitEntity(id: UUID) -> Entity? {
        guard let sceneEntity = objectEntitiesByModelID[id] else { return nil }
        return objectComponents[sceneEntity]?.realityKitEntity
    }
}
