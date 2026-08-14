//
//  WaypointIndicatorComponent.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import RealityKit

struct WaypointIndicatorComponent: Component {
    var targetPosition: SIMD3<Float>?
    var moveSpeed: Float = 2.4
    var moveAmplitude: Float = 0.10
    var floatSpeed: Float = 2.0
    var floatAmplitude: Float = 0.015
    var forwardOffset: Float = 1.15
    var heightOffset: Float = -0.35
}
