import Foundation
import RealityKit

@MainActor
/// System yang memproses semua entity lampu.
///
/// Dalam ECS, system berisi behavior. Jadi logic untuk:
/// - membuat lampu baru,
/// - menghapus lampu yang tidak ada lagi di ViewModel,
/// - memperbarui transform/warna/intensitas,
/// - menandai lampu terpilih,
/// - mendaftarkan collision,
/// diletakkan di sini, bukan di component/entity.
struct SceneLightSystem {
    static let lightObstacleRadius: Float = 0.07

    /// Menyamakan state ECS dengan daftar `LightConfiguration` dari ViewModel.
    ///
    /// Flow:
    /// 1. Ambil daftar light yang diminta UI.
    /// 2. Hapus ECS light yang model-nya sudah tidak ada.
    /// 3. Untuk setiap light yang masih ada:
    ///    - ambil/buat `SceneEntity` dari world,
    ///    - jika component sudah ada, update RealityKit entity-nya,
    ///    - jika belum ada, buat RealityKit entity lewat factory lalu simpan sebagai component,
    ///    - update collision obstacle.
    ///
    /// Return value adalah warning collision untuk selected light, agar coordinator
    /// bisa meneruskannya ke ViewModel tanpa system langsung mengubah UI state.
    func synchronize(
        world: ARSceneWorld,
        requestedLights: [LightConfiguration],
        selectedLightID: UUID,
        collisionManager: CollisionSystem,
        updateLightPosition: (UUID, SIMD3<Float>) -> Void,
        debugLog: (String) -> Void
    ) -> String? {
        guard let anchor = world.anchor else { return nil }
        let currentIDs = Set(requestedLights.map { $0.id })

        // Entity yang tidak ada lagi di ViewModel harus dibersihkan dari:
        // component store, mapping model -> entity, RealityKit scene, dan collision.
        for (modelID, sceneEntity) in world.lightEntitiesByModelID where !currentIDs.contains(modelID) {
            guard let component = world.lightComponents[sceneEntity] else { continue }
            component.realityKitEntities.root.removeFromParent()
            world.lightComponents[sceneEntity] = nil
            world.lightEntitiesByModelID[modelID] = nil
            collisionManager.removeObstacle(id: modelID)
            debugLog("Light deletion cleaned up from scene")
        }

        var selectedCollisionWarning: String?

        for requestedLight in requestedLights {
            var light = requestedLight
            let selected = light.id == selectedLightID
            // World bertanggung jawab menjaga identity ECS tetap stabil untuk
            // setiap light model.
            let sceneEntity = world.sceneEntity(forLightID: light.id)

            if var component = world.lightComponents[sceneEntity] {
                // Component sudah ada: system cukup resolve collision dan update
                // entity RealityKit yang tersimpan di component.
                let virtualResolution = collisionManager.resolvedPosition(
                    candidatePosition: light.position,
                    movingRadius: Self.lightObstacleRadius,
                    excludingID: light.id
                )
                light.position = virtualResolution.position

                if light.position != requestedLight.position {
                    updateLightPosition(light.id, light.position)
                }

                if selected, virtualResolution.didCollide {
                    selectedCollisionWarning = "Light stopped by another virtual object."
                }

                SceneLightEntityFactory.update(
                    light: component.realityKitEntities.light,
                    fillLight: component.realityKitEntities.fillLight,
                    marker: component.realityKitEntities.marker,
                    ring: component.realityKitEntities.selectionRing,
                    configuration: light,
                    selected: selected
                )
                component.configuration = light
                world.lightComponents[sceneEntity] = component
                collisionManager.updatePosition(id: light.id, position: light.position)
            } else {
                // Component belum ada: ini light baru dari ViewModel, jadi system
                // meminta factory AR membuat entity visual RealityKit.
                let realityKitEntities = SceneLightEntityFactory.makeLight(configuration: light, selected: selected)
                anchor.addChild(realityKitEntities.root)
                world.lightComponents[sceneEntity] = SceneLightComponent(
                    configuration: light,
                    realityKitEntities: realityKitEntities
                )
                collisionManager.registerObstacle(
                    id: light.id,
                    position: light.position,
                    radius: Self.lightObstacleRadius
                )
                debugLog("Light creation: \(light.name)")
            }
        }

        return selectedCollisionWarning
    }

    /// Selection tetap diproses oleh system karena system yang tahu component store.
    /// Input-nya RealityKit entity hasil tap; output-nya UUID model agar coordinator
    /// bisa mengubah `selectedLightID` di ViewModel.
    func selectLight(containing entity: Entity, in world: ARSceneWorld) -> UUID? {
        for (modelID, sceneEntity) in world.lightEntitiesByModelID {
            guard let component = world.lightComponents[sceneEntity] else { continue }
            if entity == component.realityKitEntities.marker || entity == component.realityKitEntities.selectionRing {
                return modelID
            }
        }
        return nil
    }
}
