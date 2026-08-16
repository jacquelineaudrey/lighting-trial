////
////  HoldInteractionSystem.swift
////  lightingconcept
////
////  Created by Justin Hartanto Widjaja on 13/08/26.
////
//
//import RealityKit
//
//final class HoldInteractionSystem: System {
//    private static let query = EntityQuery(where: .has(HoldInteractionComponent.self))
//    private static let cameraQuery = EntityQuery(where: .has(PerspectiveCameraComponent.self))
//    
//    init(scene: RealityKit.Scene) {}
//    
//    func update(context: SceneUpdateContext) {
//        // Fetch the active AR camera
//        var activeCamera: Entity?
//        for entity in context.entities(matching: Self.cameraQuery, updatingSystemWhen: .rendering) {
//            activeCamera = entity
//            break
//        }
//        
//        guard let camera = activeCamera else { return }
//        let cameraPos = camera.position(relativeTo: nil)
//        
//        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
//            guard var comp = entity.components[HoldInteractionComponent.self] else { continue }
//            
//            if comp.isHeld {
//                if !comp.isInitialized {
//                    // First frame of holding: Record starting positions
//                    comp.startCameraPosition = cameraPos
//                    comp.startEntityPosition = entity.position(relativeTo: nil)
//                    comp.isInitialized = true
//                    entity.components.set(comp)
//                } else {
//                    // Subsequent frames: Apply delta
//                    let delta = cameraPos - comp.startCameraPosition
//                    var newPos = comp.startEntityPosition + delta
//                    
//                    if comp.lockYAxis {
//                        newPos.y = comp.startEntityPosition.y // Objects stay on the ground
//                    }
//                    
//                    entity.setPosition(newPos, relativeTo: nil)
//                }
//            } else {
//                if comp.isInitialized {
//                    // Button was just released: Reset state
//                    comp.isInitialized = false
//                    entity.components.set(comp)
//                }
//            }
//        }
//    }
//}
//
