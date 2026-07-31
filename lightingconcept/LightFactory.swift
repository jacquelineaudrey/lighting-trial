import Foundation
import RealityKit
import UIKit
import SwiftUI

/// The RealityKit entities that represent one light in the scene: the
/// actual light-emitting entity, a small visible marker (so learners can see
/// where an invisible light is), and a selection ring shown when the light
/// is the active one.
struct LightSceneEntities {
    let root: Entity
    let light: Entity
    let marker: ModelEntity
    let selectionRing: ModelEntity
}

/// Creates and updates light entities. Adding a light = calling makeLight
/// and attaching entities.root to the anchor. Deleting a light = removing
/// entities.root from its parent (see ARSceneCoordinator.syncLights, which
/// diffs viewModel.lights against the currently attached lights each frame).
enum LightFactory {
    static func makeLight(configuration: LightConfiguration, selected: Bool) -> LightSceneEntities {
        let root = Entity()
        root.name = "LightRoot-\(configuration.id.uuidString)"

        let light = Entity()
        light.name = "Light-\(configuration.id.uuidString)"
        root.addChild(light)

        let marker = ModelEntity(
            mesh: .generateSphere(radius: 0.012),
            materials: [SimpleMaterial(color: .yellow, isMetallic: false)]
        )
        marker.name = "LightMarker-\(configuration.id.uuidString)"
        root.addChild(marker)

        let ring = ModelEntity(
            mesh: .generateSphere(radius: 0.02),
            materials: [SimpleMaterial(color: .cyan, isMetallic: false)]
        )
        ring.name = "LightSelectionRing-\(configuration.id.uuidString)"
        root.addChild(ring)

        update(light: light, marker: marker, ring: ring, configuration: configuration, selected: selected)

        return LightSceneEntities(root: root, light: light, marker: marker, selectionRing: ring)
    }

    static func update(
        light: Entity,
        marker: ModelEntity,
        ring: ModelEntity,
        configuration: LightConfiguration,
        selected: Bool
    ) {
        light.position = configuration.position
        let yaw = simd_quatf(angle: configuration.yawDegrees * .pi / 180, axis: [0, 1, 0])
        let pitch = simd_quatf(angle: configuration.pitchDegrees * .pi / 180, axis: [1, 0, 0])
        light.orientation = yaw * pitch

        switch configuration.type {
        case .point:
            var point = PointLightComponent()
            point.color = UIColor(configuration.color)
            point.intensity = configuration.intensity
            point.attenuationRadius = 4
            light.components.set(point)
            light.components.remove(SpotLightComponent.self)
            light.components.remove(SpotLightComponent.Shadow.self)

        case .spot:
            var spot = SpotLightComponent()
            spot.color = UIColor(configuration.color)
            spot.intensity = configuration.intensity
            spot.innerAngleInDegrees = configuration.beamSpread.innerAngle
            spot.outerAngleInDegrees = configuration.beamSpread.outerAngle
            spot.attenuationRadius = 4
            light.components.set(spot)
            // SpotLightComponent.Shadow is its own component type, not a
            // property on SpotLightComponent - it has to be added separately.
            light.components.set(SpotLightComponent.Shadow())
            light.components.remove(PointLightComponent.self)
        }

        marker.position = configuration.position
        marker.model?.materials = [SimpleMaterial(color: UIColor(configuration.color), isMetallic: false)]

        ring.position = configuration.position
        ring.isEnabled = selected
    }
}
