//
//  PulseAnimationSystem.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import RealityKit
import QuartzCore

final class PulseAnimationSystem: System {
    private static let query = EntityQuery(where: .has(PulseAnimationComponent.self))
    
    init(scene: RealityKit.Scene) {}
    
    func update(context: SceneUpdateContext) {
        // FIX: Use CACurrentMediaTime() because 'time' isn't natively exposed on iOS Scene
        let time = Float(CACurrentMediaTime())
        
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let pulse = entity.components[PulseAnimationComponent.self],
                  pulse.isActiveTarget else { continue }
            
            // Pulse lembut dari ukuran dasar ke ukuran maksimum. Marker tidak
            // lagi mengecil di bawah ukuran normal sehingga tetap mudah ditap.
            let normalizedPulse = (sin(time * pulse.speed) + 1) * 0.5
            let pulseScale = pulse.baseScale + pulse.amplitude * normalizedPulse
            entity.scale = SIMD3<Float>(repeating: pulseScale)
        }
    }
}
