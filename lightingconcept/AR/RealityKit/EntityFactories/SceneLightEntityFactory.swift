import RealityKit
import SwiftUI
import UIKit

/// Runtime references for the RealityKit entities that make up one scene light.
///
/// This is an infrastructure value returned by the entity factory. ECS state
/// remains in the corresponding components; this bundle only keeps the
/// RealityKit entity references together for callers that need them.
struct RealityKitLightEntityBundle {
    let root: Entity
    let light: Entity
    let fillLight: Entity
    let marker: ModelEntity
    let selectionRing: ModelEntity
}

/// Factory khusus untuk membuat dan memperbarui entity lampu di RealityKit.
/// File ini tidak menghitung projection line; tugasnya hanya menerjemahkan
/// `LightConfiguration` menjadi komponen RealityKit seperti PointLight/SpotLight.
enum SceneLightEntityFactory {
    static func makeLight(configuration: LightConfiguration, selected: Bool) -> RealityKitLightEntityBundle {
        let root = Entity()
        root.name = configuration.name

        let light = Entity()
        light.name = "\(configuration.name) emitter"
        root.addChild(light)

        let fillLight = Entity()
        fillLight.name = "\(configuration.name) omnidirectional fill"
        root.addChild(fillLight)

        let marker = makeMarker(configuration: configuration)
        root.addChild(marker)

        let ring = makeSelectionRing(visible: selected)
        root.addChild(ring)

        update(light: light, fillLight: fillLight, marker: marker, ring: ring, configuration: configuration, selected: selected)
        return RealityKitLightEntityBundle(root: root, light: light, fillLight: fillLight, marker: marker, selectionRing: ring)
    }

    static func update(
        light: Entity,
        fillLight: Entity,
        marker: ModelEntity,
        ring: ModelEntity,
        configuration: LightConfiguration,
        selected: Bool
    ) {
        light.components.remove(PointLightComponent.self)
        light.components.remove(SpotLightComponent.self)
        light.components.remove(SpotLightComponent.Shadow.self)
        fillLight.components.remove(PointLightComponent.self)

        switch configuration.type {
        case .point:
            // Point light menyebar ke semua arah. Di SDK ini point light dipakai untuk
            // pencahayaan object, sedangkan cast shadow yang stabil memakai spotlight.
            var component = PointLightComponent()
            component.color = configuration.color.uiColor
            component.intensity = configuration.intensity
            component.attenuationRadius = 6
            light.components.set(component)
        case .spot:
            // Spot light adalah sumber utama shadow: punya arah, beam angle, dan shadow component.
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
            // Depth bias terlalu besar membuat shadow terlihat terangkat/hilang;
            // nilai kecil ini menjaga contact shadow lebih dekat ke object.
            shadow.depthBias = 0.08
            light.components.set(shadow)

            // Fill light kecil hanya menjaga object tetap terbaca dari berbagai sudut.
            // Nilainya rendah agar tidak menghapus kontras shadow utama.
            var fill = PointLightComponent()
            fill.color = configuration.color.uiColor
            fill.intensity = configuration.intensity * 0.08
            fill.attenuationRadius = 1.0
            fillLight.components.set(fill)
        }

        light.position = configuration.position
        // Orientation inilah yang menentukan arah spotlight. Direction overlay juga
        // mengambil arah dari yaw/pitch yang sama supaya visualisasi cocok dengan lampu.
        light.orientation = orientation(yawDegrees: configuration.yawDegrees, pitchDegrees: configuration.pitchDegrees)
        fillLight.position = configuration.position
        marker.position = configuration.position
        marker.model?.materials = [markerMaterial(color: configuration.color)]
        ring.position = configuration.position + SIMD3<Float>(0, -0.026, 0)
        ring.isEnabled = selected
    }

    static func orientation(yawDegrees: Float, pitchDegrees: Float) -> simd_quatf {
        // Kombinasi yaw + pitch mengarahkan spotlight. RealityKit memakai sumbu -Z
        // sebagai arah depan light, sehingga helper ini dipakai juga oleh overlay.
        let yaw = simd_quatf(angle: yawDegrees.degreesToRadians, axis: SIMD3<Float>(0, 1, 0))
        let pitch = simd_quatf(angle: pitchDegrees.degreesToRadians, axis: SIMD3<Float>(1, 0, 0))
        return yaw * pitch
    }

    static func forwardVector(yawDegrees: Float, pitchDegrees: Float) -> SIMD3<Float> {
        let orientation = orientation(yawDegrees: yawDegrees, pitchDegrees: pitchDegrees)
        // RealityKit memakai local -Z sebagai arah "depan" light. Setelah diputar oleh
        // yaw/pitch, vector ini menjadi arah datang cahaya di coordinate space light.
        return simd_normalize(orientation.act(SIMD3<Float>(0, 0, -1)))
    }

    /// Menghasilkan yaw/pitch yang membuat sumbu depan spotlight RealityKit
    /// (`-Z`) tepat menunjuk dari posisi lampu ke titik target.
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

    private static func makeMarker(configuration: LightConfiguration) -> ModelEntity {
        let marker = ModelEntity(mesh: .generateSphere(radius: 0.035), materials: [markerMaterial(color: configuration.color)])
        marker.name = "\(configuration.name) marker"
        marker.generateCollisionShapes(recursive: false)
        disableShadows(for: marker)
        return marker
    }

    private static func makeSelectionRing(visible: Bool) -> ModelEntity {
        let mesh = MeshResource.generateBox(size: SIMD3<Float>(0.07, 0.004, 0.07))
        let material = UnlitMaterial(color: .systemCyan)
        let ring = ModelEntity(mesh: mesh, materials: [material])
        ring.name = "Selected light indicator"
        ring.isEnabled = visible
        ring.generateCollisionShapes(recursive: false)
        disableShadows(for: ring)
        return ring
    }

    private static func markerMaterial(color: Color) -> UnlitMaterial {
        UnlitMaterial(color: color.uiColor)
    }

    private static func disableShadows(for entity: ModelEntity) {
        entity.components.set(DynamicLightShadowComponent(castsShadow: false))
        entity.components.set(GroundingShadowComponent(castsShadow: false, receivesShadow: false))
    }
}
