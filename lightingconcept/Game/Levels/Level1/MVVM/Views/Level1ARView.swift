//
//  Level1ARView.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//
import SwiftUI
import RealityKit
import ARKit
import Combine

struct Level1ARView: UIViewRepresentable {
    @ObservedObject var viewModel: Level1ViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // 1. Register Native ECS Systems
        PulseAnimationSystem.registerSystem()
        WaypointSystem.registerSystem()
        
        // 2. Setup Root Anchor
        let rootAnchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(rootAnchor)
        viewModel.setupLevel(in: rootAnchor)
        
        // 3. Configure ARKit to open the Camera and detect planes
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        
        arView.session.delegate = context.coordinator
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        // 4. Send scene updates to ViewModel for proximity checks
        context.coordinator.subscription = AnyCancellable(arView.scene.subscribe(to: SceneEvents.Update.self) { event in
            viewModel.processSceneUpdate(event.scene)
        })
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        viewModel.syncEntities()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        let viewModel: Level1ViewModel
        var subscription: AnyCancellable?
        
        init(viewModel: Level1ViewModel) {
            self.viewModel = viewModel
        }
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            process(anchors)
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            process(anchors)
        }
        
        private func process(_ anchors: [ARAnchor]) {
            for anchor in anchors {
                viewModel.trackLatestHorizontalPlane(anchor)
            }
        }
    }
}
