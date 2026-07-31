import RealityKit
import SwiftUI
import UIKit

struct LightSceneEntities {
    let root: Entity
    let light: Entity
    let marker: ModelEntity
    let selectionRing: ModelEntity
}

enum LightFactory {
    static func makeLight(configuration: LightConfiguration, selected: Bool) -> LightSceneEntities {
        let root = Entity()
        root.name = configuration.name

        let light = Entity()
        light.name = "\(configuration.name) emitter"
        root.addChild(light)

        let marker = makeMarker(configuration: configuration)
        root.addChild(marker)

        let ring = makeSelectionRing(visible: selected)
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
        light.components.remove(PointLightComponent.self)
        light.components.remove(SpotLightComponent.self)
        light.components.remove(SpotLightComponent.Shadow.self)

        switch configuration.type {
        case .point:
            var component = PointLightComponent()
            component.color = configuration.color.uiColor
            component.intensity = configuration.intensity
            component.attenuationRadius = 2.5
            light.components.set(component)
        case .spot:
            var component = SpotLightComponent()
            component.color = configuration.color.uiColor
            component.intensity = configuration.intensity
            component.attenuationRadius = 3
            component.innerAngleInDegrees = configuration.beamSpread.innerAngle
            component.outerAngleInDegrees = configuration.beamSpread.outerAngle
            light.components.set(component)
            light.components.set(SpotLightComponent.Shadow())
        }

        light.position = configuration.position
        light.orientation = orientation(yawDegrees: configuration.yawDegrees, pitchDegrees: configuration.pitchDegrees)
        marker.position = configuration.position
        marker.model?.materials = [markerMaterial(color: configuration.color)]
        ring.position = configuration.position + SIMD3<Float>(0, -0.026, 0)
        ring.isEnabled = selected
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

    private static func makeMarker(configuration: LightConfiguration) -> ModelEntity {
        let marker = ModelEntity(mesh: .generateSphere(radius: 0.035), materials: [markerMaterial(color: configuration.color)])
        marker.name = "\(configuration.name) marker"
        marker.generateCollisionShapes(recursive: false)
        return marker
    }

    private static func makeSelectionRing(visible: Bool) -> ModelEntity {
        let mesh = MeshResource.generateBox(size: SIMD3<Float>(0.07, 0.004, 0.07))
        let material = UnlitMaterial(color: .systemCyan)
        let ring = ModelEntity(mesh: mesh, materials: [material])
        ring.name = "Selected light indicator"
        ring.isEnabled = visible
        ring.generateCollisionShapes(recursive: false)
        return ring
    }

    private static func markerMaterial(color: Color) -> UnlitMaterial {
        UnlitMaterial(color: color.uiColor)
    }
}
