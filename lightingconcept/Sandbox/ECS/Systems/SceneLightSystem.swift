import Foundation
import RealityKit
import UIKit

/// System RealityKit untuk entity yang punya `SceneLightComponent`.
///
/// State lampu disimpan di component yang ditempel pada root `RealityKit.Entity`.
/// System ini tidak menyimpan dictionary atau cache entity. Sync berat dipanggil
/// hanya saat ViewModel berubah, sedangkan `update(context:)` tetap ringan.
final class SceneLightSystem: System {
    static let lightObstacleRadius: Float = 0.07

    private static let query = EntityQuery(where: .has(SceneLightComponent.self))

    required init(scene: Scene) {
    }

    func update(context: SceneUpdateContext) {
        for _ in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            // Tetap ringan: RealityKit memanggil ini setiap frame.
            // Update warna/intensitas/posisi lampu dilakukan saat sync scene atau gesture,
            // bukan diulang terus-menerus pada render loop.
        }
    }

    @MainActor
    static func synchronize(
        anchor: Entity,
        requestedLights: [LightConfiguration],
        selectedLightID: UUID,
        updateLightPosition: (UUID, SIMD3<Float>) -> Void,
        debugLog: (String) -> Void
    ) -> String? {
        let currentIDs = Set(requestedLights.map { $0.id })

        for entity in entitiesWithLightComponent(in: anchor) {
            guard let component = entity.components[SceneLightComponent.self],
                  !currentIDs.contains(component.configuration.id) else { continue }
            CollisionSystem.removeObstacle(from: entity)
            entity.removeFromParent()
            debugLog("Light deletion cleaned up from scene")
        }

        var selectedCollisionWarning: String?

        for requestedLight in requestedLights {
            var light = requestedLight
            let selected = light.id == selectedLightID

            if let entity = entityWithLightID(light.id, in: anchor) {
                let virtualResolution = CollisionSystem.resolvedPosition(
                    in: anchor,
                    candidatePosition: light.position,
                    movingRadius: lightObstacleRadius,
                    excludingID: light.id
                )
                light.position = virtualResolution.position

                if light.position != requestedLight.position {
                    updateLightPosition(light.id, light.position)
                }

                if selected, virtualResolution.didCollide {
                    selectedCollisionWarning = "Light stopped by another virtual object."
                }

                entity.components.set(SceneLightComponent(configuration: light, isSelected: selected))
                CollisionSystem.setObstacle(on: entity, id: light.id, radius: lightObstacleRadius)
                applyLightConfiguration(to: entity, configuration: light, selected: selected)
            } else {
                let root = makeLightEntity(configuration: light, selected: selected)
                root.components.set(SceneLightComponent(configuration: light, isSelected: selected))
                CollisionSystem.setObstacle(on: root, id: light.id, radius: lightObstacleRadius)
                applyLightConfiguration(to: root, configuration: light, selected: selected)
                anchor.addChild(root)
                debugLog("Light creation: \(light.name)")
            }
        }

        return selectedCollisionWarning
    }

    static func selectLight(containing entity: Entity) -> UUID? {
        var candidate: Entity? = entity
        while let current = candidate {
            if let component = current.components[SceneLightComponent.self] {
                return component.configuration.id
            }
            candidate = current.parent
        }
        return nil
    }

    static func entityWithLightID(_ id: UUID, in root: Entity) -> Entity? {
        entitiesWithLightComponent(in: root).first {
            $0.components[SceneLightComponent.self]?.configuration.id == id
        }
    }

    static func orientation(yawDegrees: Float, pitchDegrees: Float) -> simd_quatf {
        let yaw = simd_quatf(angle: yawDegrees.degreesToRadians, axis: SIMD3<Float>(0, 1, 0))
        let pitch = simd_quatf(angle: pitchDegrees.degreesToRadians, axis: SIMD3<Float>(1, 0, 0))
        return yaw * pitch
    }

    static func forwardVector(yawDegrees: Float, pitchDegrees: Float) -> SIMD3<Float> {
        let orientation = orientation(yawDegrees: yawDegrees, pitchDegrees: pitchDegrees)
        return simd_normalize(orientation.act(SIMD3<Float>(0, 0, -1)))
    }

    /// Returns the yaw and pitch that point RealityKit's local -Z light axis
    /// from a light source toward a target in scene coordinates.
    static func aimingAngles(
        from lightPosition: SIMD3<Float>,
        to targetPosition: SIMD3<Float>
    ) -> (yawDegrees: Float, pitchDegrees: Float)? {
        let delta = targetPosition - lightPosition
        guard simd_length_squared(delta) > 0.000001 else { return nil }

        let horizontalDistance = sqrt(delta.x * delta.x + delta.z * delta.z)
        return (
            yawDegrees: atan2(-delta.x, -delta.z).radiansToDegrees,
            pitchDegrees: atan2(delta.y, horizontalDistance).radiansToDegrees
        )
    }

    private static func makeLightEntity(
        configuration: LightConfiguration,
        selected: Bool
    ) -> Entity {
        let root = Entity()
        root.name = configuration.id.uuidString

        let light = Entity()
        light.name = "Light Emitter"
        root.addChild(light)

        let fillLight = Entity()
        fillLight.name = "Light Fill"
        root.addChild(fillLight)

        let marker = ModelEntity(
            mesh: .generateSphere(radius: 0.035),
            materials: [UnlitMaterial(color: configuration.color.uiColor)]
        )
        marker.name = "Light Marker"
        marker.generateCollisionShapes(recursive: false)
        disableShadows(for: marker)
        root.addChild(marker)

        return root
    }

    private static func applyLightConfiguration(
        to root: Entity,
        configuration: LightConfiguration,
        selected: Bool
    ) {
        guard let light = root.children.first(where: { $0.name == "Light Emitter" }),
              let fillLight = root.children.first(where: { $0.name == "Light Fill" }),
              let marker = root.children.first(where: { $0.name == "Light Marker" }) as? ModelEntity else { return }

        light.components.remove(PointLightComponent.self)
        light.components.remove(SpotLightComponent.self)
        light.components.remove(SpotLightComponent.Shadow.self)
        fillLight.components.remove(PointLightComponent.self)

        switch configuration.type {
        case .point:
            var component = PointLightComponent()
            component.color = configuration.color.uiColor
            component.intensity = configuration.intensity
            component.attenuationRadius = 6
            light.components.set(component)
        case .spot:
            var component = SpotLightComponent()
            component.color = configuration.color.uiColor
            component.intensity = configuration.intensity
            component.attenuationRadius = 8
            component.innerAngleInDegrees = configuration.effectiveInnerAngleDegrees
            component.outerAngleInDegrees = configuration.effectiveOuterAngleDegrees
            light.components.set(component)

            var shadow = SpotLightComponent.Shadow()
            shadow.zNear = .fixed(0.01)
            shadow.zFar = .fixed(8)
            shadow.depthBias = 0.08
            light.components.set(shadow)

            var fill = PointLightComponent()
            fill.color = configuration.color.uiColor
            fill.intensity = configuration.intensity * 0.08
            fill.attenuationRadius = 1.0
            fillLight.components.set(fill)
        }

        root.position = configuration.position
        root.name = configuration.id.uuidString
        light.position = .zero
        light.orientation = orientation(yawDegrees: configuration.yawDegrees, pitchDegrees: configuration.pitchDegrees)
        fillLight.position = .zero
        marker.position = .zero
        marker.scale = SIMD3<Float>(repeating: configuration.markerScale)
        marker.model?.materials = [UnlitMaterial(color: configuration.color.uiColor)]
    }

    private static func disableShadows(for entity: ModelEntity) {
        entity.components.set(DynamicLightShadowComponent(castsShadow: false))
        entity.components.set(GroundingShadowComponent(castsShadow: false, receivesShadow: false))
    }

    private static func entitiesWithLightComponent(in root: Entity) -> [Entity] {
        var result: [Entity] = []
        collectLightEntities(from: root, into: &result)
        return result
    }

    private static func collectLightEntities(from entity: Entity, into result: inout [Entity]) {
        if entity.components[SceneLightComponent.self] != nil {
            result.append(entity)
        }
        for child in entity.children {
            collectLightEntities(from: child, into: &result)
        }
    }
}
