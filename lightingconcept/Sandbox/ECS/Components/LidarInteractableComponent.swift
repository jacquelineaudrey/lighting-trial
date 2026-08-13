//
//  LidarInteractableComponent.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import RealityKit

struct LidarInteractableComponent: Component, Codable, Sendable {
    var isAnchoredToMesh: Bool
    var mass: Float
    var velocity: SIMD3<Float>
    var surfaceDistance: Float
    var usesGravity: Bool
    
    init(
        mass: Float = 1.0,
        usesGravity: Bool = false
    ) {
        self.isAnchoredToMesh = false
        self.mass = mass
        self.velocity = .zero
        self.surfaceDistance = .greatestFiniteMagnitude
        self.usesGravity = usesGravity
    }
}
