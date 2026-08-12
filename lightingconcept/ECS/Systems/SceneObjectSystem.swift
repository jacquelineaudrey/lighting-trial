import Foundation
import RealityKit

@MainActor
/// System yang memproses semua entity objek pembelajaran.
///
/// Entity ECS tetap hanya identity (`SceneEntity`). Component menyimpan data.
/// System inilah yang menjalankan behavior: membuat/menghapus RealityKit entity,
/// mengganti mesh saat tipe object berubah, update transform, load imported model,
/// dan mendaftarkan collision.
struct SceneObjectSystem {
    /// Menyamakan state ECS dengan daftar `ObjectConfiguration` dari ViewModel.
    ///
    /// Flow:
    /// 1. ViewModel mengirim daftar object terbaru.
    /// 2. World memberi `SceneEntity` stabil untuk setiap UUID model.
    /// 3. System membandingkan component lama dengan konfigurasi baru.
    /// 4. Jika source berubah, RealityKit entity dibuat ulang lewat factory.
    /// 5. Jika hanya transform/scale berubah, entity lama cukup di-update.
    /// 6. Collision store di-update agar object dan light tidak saling menembus.
    func synchronize(
        world: ARSceneWorld,
        requestedObjects: [ObjectConfiguration],
        selectedTexture: MaterialTexture,
        collisionManager: CollisionSystem,
        reportImportedDimensions: @escaping (UUID, SIMD3<Float>) -> Void,
        reportModelLoadFailure: @escaping (String, any Error) -> Void,
        debugLog: @escaping (String) -> Void
    ) {
        guard let anchor = world.anchor else { return }
        let currentIDs = Set(requestedObjects.map { $0.id })

        // Hapus entity ECS yang object model-nya sudah tidak ada di ViewModel.
        // Cleanup harus mencakup async load task dan RealityKit entity supaya tidak
        // ada resource tertinggal di scene.
        for (modelID, sceneEntity) in world.objectEntitiesByModelID where !currentIDs.contains(modelID) {
            guard let component = world.objectComponents[sceneEntity] else { continue }
            component.loadTask?.cancel()
            component.realityKitEntity.removeFromParent()
            world.objectComponents[sceneEntity] = nil
            world.objectEntitiesByModelID[modelID] = nil
            collisionManager.removeObstacle(id: modelID)
            debugLog("Object deletion cleaned up from scene")
        }

        let textureChanged = world.lastTexture != selectedTexture
        for configuration in requestedObjects {
            // World yang mengatur relasi UUID model -> SceneEntity. Component tidak
            // menyimpan balik identity ini agar arah dependensinya tetap bersih.
            let sceneEntity = world.sceneEntity(forObjectID: configuration.id)
            let sourceKey = objectSourceKey(for: configuration)
            let existing = world.objectComponents[sceneEntity]
            // Source key membedakan "bentuk sumber" entity visual:
            // primitive cube/sphere/etc atau file imported model.
            // Jika source berubah, mesh/material harus dibuat ulang.
            let needsReplacement = existing == nil
                || existing?.sourceKey != sourceKey
                || (configuration.importedModel == nil && textureChanged)

            if needsReplacement {
                existing?.loadTask?.cancel()
                existing?.realityKitEntity.removeFromParent()

                if let importedModel = configuration.importedModel {
                    // Imported model dimuat async. Sementara file dibaca, tampilkan
                    // placeholder agar entity sudah ada di world dan gesture/selection
                    // tidak perlu menunggu proses load selesai.
                    let placeholder = SceneObjectEntityFactory.makeObject(type: .cuboid)
                    anchor.addChild(placeholder)
                    world.objectComponents[sceneEntity] = SceneObjectComponent(
                        configuration: configuration,
                        realityKitEntity: placeholder,
                        sourceKey: sourceKey,
                        loadTask: nil
                    )
                    loadImportedObject(
                        importedModel,
                        objectID: configuration.id,
                        sceneEntity: sceneEntity,
                        sourceKey: sourceKey,
                        world: world,
                        collisionManager: collisionManager,
                        reportImportedDimensions: reportImportedDimensions,
                        reportModelLoadFailure: reportModelLoadFailure,
                        debugLog: debugLog
                    )
                } else {
                    // Primitive object bisa dibuat langsung karena mesh-nya procedural.
                    let realityKitEntity = SceneObjectEntityFactory.makeObject(
                        type: configuration.type,
                        texture: selectedTexture
                    )
                    anchor.addChild(realityKitEntity)
                    world.objectComponents[sceneEntity] = SceneObjectComponent(
                        configuration: configuration,
                        realityKitEntity: realityKitEntity,
                        sourceKey: sourceKey,
                        loadTask: nil
                    )
                    debugLog("Object synchronized: \(configuration.name) - \(configuration.type.rawValue)")
                }
            }

            // Component sudah ada atau baru dibuat; sekarang update data domain,
            // terapkan transform ke RealityKit, lalu daftarkan collision.
            guard var component = world.objectComponents[sceneEntity] else { continue }
            component.configuration = configuration
            Self.applyTransform(to: component.realityKitEntity, configuration: configuration)

            // Native RealityKit ECS component. Continuous LiDAR interaction is
            // handled by LidarPhysicsSystem, not by SwiftUI state updates.
            if component.realityKitEntity.components[LidarInteractableComponent.self] == nil {
                component.realityKitEntity.components[LidarInteractableComponent.self] =
                    LidarInteractableComponent(mass: 1.0, usesGravity: false)
            }

            world.objectComponents[sceneEntity] = component
            collisionManager.registerObstacle(
                id: configuration.id,
                position: Self.obstaclePosition(for: configuration),
                radius: SceneObjectEntityFactory.collisionRadius(for: configuration)
            )
        }

        world.lastTexture = selectedTexture
    }

    /// Mengubah hasil tap RealityKit menjadi UUID model.
    /// Traversal parent dibutuhkan karena user bisa mengetuk child mesh dari
    /// imported model, bukan selalu root entity yang disimpan di component.
    func selectObject(containing entity: Entity, in world: ARSceneWorld) -> UUID? {
        for (modelID, sceneEntity) in world.objectEntitiesByModelID {
            guard let component = world.objectComponents[sceneEntity] else { continue }
            var candidate: Entity? = entity
            while let current = candidate {
                if current == component.realityKitEntity {
                    return modelID
                }
                candidate = current.parent
            }
        }
        return nil
    }

    /// Loader async untuk imported model.
    ///
    /// `sceneEntity` diterima sebagai parameter karena system harus menulis kembali
    /// ke component yang sama setelah load selesai. Guard `sourceKey` memastikan
    /// hasil load lama tidak menimpa component baru jika user mengganti model saat
    /// task masih berjalan.
    private func loadImportedObject(
        _ importedModel: ImportedModelConfiguration,
        objectID: UUID,
        sceneEntity: SceneEntity,
        sourceKey: String,
        world: ARSceneWorld,
        collisionManager: CollisionSystem,
        reportImportedDimensions: @escaping (UUID, SIMD3<Float>) -> Void,
        reportModelLoadFailure: @escaping (String, any Error) -> Void,
        debugLog: @escaping (String) -> Void
    ) {
        world.objectComponents[sceneEntity]?.loadTask = Task { @MainActor in
            do {
                let loadedEntity = try await Entity(contentsOf: importedModel.fileURL)
                try Task.checkCancellation()
                guard let anchor = world.anchor,
                      world.objectComponents[sceneEntity]?.sourceKey == sourceKey,
                      world.objectComponents[sceneEntity]?.configuration.importedModel?.fileURL == importedModel.fileURL else { return }

                let normalizedObject = try makeNormalizedImportedObject(
                    from: loadedEntity,
                    name: importedModel.displayName
                )
                world.objectComponents[sceneEntity]?.realityKitEntity.removeFromParent()
                anchor.addChild(normalizedObject.entity)
                if var component = world.objectComponents[sceneEntity] {
                    component.realityKitEntity = normalizedObject.entity
                    component.loadTask = nil
                    world.objectComponents[sceneEntity] = component
                }
                reportImportedDimensions(objectID, normalizedObject.dimensions)

                if let updatedConfiguration = world.objectComponents[sceneEntity]?.configuration {
                    Self.applyTransform(to: normalizedObject.entity, configuration: updatedConfiguration)
                    collisionManager.registerObstacle(
                        id: objectID,
                        position: Self.obstaclePosition(for: updatedConfiguration),
                        radius: SceneObjectEntityFactory.collisionRadius(for: updatedConfiguration)
                    )
                }
                debugLog("Imported 3D model loaded: \(importedModel.displayName)")
            } catch is CancellationError {
                world.objectComponents[sceneEntity]?.loadTask = nil
            } catch {
                world.objectComponents[sceneEntity]?.loadTask = nil
                reportModelLoadFailure(importedModel.displayName, error)
            }
        }
    }

    /// Normalisasi imported model ke ukuran kerja aplikasi.
    /// Banyak file USDZ/Reality punya skala berbeda, jadi entity dibungkus dalam
    /// container agar ukuran maksimum konsisten sebelum dipakai di AR.
    private func makeNormalizedImportedObject(
        from loadedEntity: Entity,
        name: String
    ) throws -> (entity: Entity, dimensions: SIMD3<Float>) {
        let normalizer = Entity()
        normalizer.addChild(loadedEntity)
        let bounds = normalizer.visualBounds(recursive: true, relativeTo: normalizer)
        let rawDimensions = bounds.extents
        let largestDimension = max(rawDimensions.x, rawDimensions.y, rawDimensions.z)

        guard largestDimension.isFinite, largestDimension > 0.0001 else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let normalizationScale = ImportedModelConfiguration.targetMaximumDimension / largestDimension
        let dimensions = SIMD3<Float>(
            max(rawDimensions.x * normalizationScale, 0.002),
            max(rawDimensions.y * normalizationScale, 0.002),
            max(rawDimensions.z * normalizationScale, 0.002)
        )
        normalizer.scale = SIMD3<Float>(repeating: normalizationScale)
        normalizer.position = -bounds.center * normalizationScale

        let container = Entity()
        container.name = name
        container.addChild(normalizer)
        container.components.set(CollisionComponent(shapes: [.generateBox(size: dimensions)]))
        enableDynamicShadows(on: loadedEntity)
        return (container, dimensions)
    }

    /// RealityKit shadow component harus diterapkan rekursif karena imported model
    /// biasanya berisi tree entity, bukan satu `ModelEntity` tunggal.
    private func enableDynamicShadows(on entity: Entity) {
        if entity is ModelEntity {
            entity.components.set(DynamicLightShadowComponent(castsShadow: true))
        }
        for child in entity.children {
            enableDynamicShadows(on: child)
        }
    }

    /// Signature sumber visual untuk memutuskan apakah entity perlu dibuat ulang.
    private func objectSourceKey(for object: ObjectConfiguration) -> String {
        if let importedModel = object.importedModel {
            return "imported:\(importedModel.fileURL.path)"
        }
        return "primitive:\(object.type.rawValue)"
    }

    /// Transform system: menerjemahkan data domain ke transform RealityKit.
    /// ObjectConfiguration menyimpan posisi ground, sedangkan RealityKit entity
    /// diposisikan di center mesh, jadi Y dinaikkan setengah tinggi object.
    static func applyTransform(to object: Entity, configuration: ObjectConfiguration) {
        let scaledHeight = SceneObjectEntityFactory.objectHeight(for: configuration) * configuration.scale
        object.position = SIMD3<Float>(
            configuration.position.x,
            scaledHeight / 2,
            configuration.position.z
        )
        object.scale = SIMD3<Float>(repeating: configuration.scale)
        object.orientation = simd_quatf(
            angle: configuration.yawDegrees.degreesToRadians,
            axis: SIMD3<Float>(0, 1, 0)
        )
    }

    /// Posisi obstacle collision memakai center volume, bukan posisi ground.
    static func obstaclePosition(for object: ObjectConfiguration) -> SIMD3<Float> {
        object.position + SIMD3<Float>(
            0,
            SceneObjectEntityFactory.objectHeight(for: object) * object.scale / 2,
            0
        )
    }
}
