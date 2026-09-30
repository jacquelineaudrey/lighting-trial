//
//  Level5GuideSystem.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 28/09/26.
//

import QuartzCore
import RealityKit

final class Level5GuideSystem:
    System {

    private static let query =
        EntityQuery(
            where:
                .has(
                    Level5GuideComponent.self
                )
        )

    required init(
        scene:
            Scene
    ) {}

    func update(
        context:
            SceneUpdateContext
    ) {

        let time =
            Float(
                CACurrentMediaTime()
            )

        for entity in context.entities(
            matching:
                Self.query,

            updatingSystemWhen:
                .rendering
        ) {

            guard let guide =
                entity.components[
                    Level5GuideComponent.self
                ]
            else {
                continue
            }

            entity.position =
                guide.basePosition
                + SIMD3<Float>(
                    0,
                    sin(
                        time
                        * guide.bobbingSpeed
                    )
                    * guide.bobbingAmplitude,
                    0
                )
        }
    }
}
