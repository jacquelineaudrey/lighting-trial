//
//  WaypointSystem.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import RealityKit
import QuartzCore

final class WaypointSystem: System {
    private static let indicatorQuery = EntityQuery(where: .has(WaypointIndicatorComponent.self))
    private static let cameraQuery = EntityQuery(where: .has(PerspectiveCameraComponent.self))
    
    init(scene: RealityKit.Scene) {}
    
    func update(context: SceneUpdateContext) {
        // FIX: Safely extract the first element since RealityKit's QueryCollection lacks a '.first' property
        var activeCamera: Entity?
        for entity in context.entities(matching: Self.cameraQuery, updatingSystemWhen: .rendering) {
            activeCamera = entity
            break
        }
        
        guard let camera = activeCamera else { return }
        
        let cameraTransform = camera.transformMatrix(relativeTo: nil)
        let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let time = Float(CACurrentMediaTime())

        for entity in context.entities(matching: Self.indicatorQuery, updatingSystemWhen: .rendering) {
            guard let indicator = entity.components[WaypointIndicatorComponent.self],
                  let basePosition = indicator.targetPosition,
                  entity.isEnabled else { continue }

            // 1. Animasi naik-turun (floating) saja pada posisi dasarnya
            let verticalFloat = sin(time * indicator.floatSpeed) * indicator.floatAmplitude

            // 2. Gunakan targetPosition / anchor posisi asli (bukan cameraPosition)
            let currentPosition = SIMD3<Float>(basePosition.x, basePosition.y + verticalFloat, basePosition.z)

            // 3. Update posisi di world space tanpa mengaitkannya ke kamera
            entity.setPosition(currentPosition, relativeTo: nil)

            // 4. Jika indikator adalah panah penunjuk, arahkan ke target;
            // jika indikator adalah objek tujuan itu sendiri, hadapkan ke arah kamera
            let cameraXZ = SIMD3<Float>(cameraPosition.x, currentPosition.y, cameraPosition.z)
            entity.look(at: cameraXZ, from: currentPosition, relativeTo: nil)
        }
    }
}
