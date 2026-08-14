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
            
            let pulseScale = 1.0 + pulse.amplitude * sin(time * pulse.speed)
            entity.scale = SIMD3<Float>(pulseScale, pulse.baseScale, pulseScale)
        }
    }
}
