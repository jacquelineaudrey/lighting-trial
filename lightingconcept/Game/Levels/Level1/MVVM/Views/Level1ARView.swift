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
//        WaypointSystem.registerSystem()
        
        // 2. Setup Root Anchor
        let rootAnchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(rootAnchor)
        viewModel.setupLevel(in: rootAnchor)
        
        // 3. Configure ARKit to open the Camera and detect planes
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
            viewModel.arSceneViewModel.isLiDARAvailable = true
        } else {
            viewModel.arSceneViewModel.isLiDARAvailable = false
        }
        
        arView.session.delegate = context.coordinator
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        // FIX: Add Coaching Overlay directly to the ARView
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.activatesAutomatically = false
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(coachingOverlay)
        context.coordinator.coachingOverlay = coachingOverlay
        
        // 4. Send scene updates to ViewModel for proximity checks
        context.coordinator.subscription = AnyCancellable(arView.scene.subscribe(to: SceneEvents.Update.self) { event in
            guard let cameraTransform = arView.session.currentFrame?.camera.transform else { return }
            viewModel.processSceneUpdate(cameraTransform: cameraTransform)
        })
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        viewModel.syncEntities()
        
        // Show/Hide Coaching overlay based on Phase
        if viewModel.phase == .scanningSurface {
            context.coordinator.coachingOverlay?.setActive(true, animated: true)
        } else {
            context.coordinator.coachingOverlay?.setActive(false, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    class Coordinator: NSObject, ARSessionDelegate, ARCoachingOverlayViewDelegate {
        let viewModel: Level1ViewModel
        var subscription: AnyCancellable?
        
        weak var coachingOverlay: ARCoachingOverlayView? {
            didSet { coachingOverlay?.delegate = self }
        }
        
        init(viewModel: Level1ViewModel) {
            self.viewModel = viewModel
        }
        
        // If the user satisfies the coaching overlay manually, spawn the path
        func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
            if viewModel.phase == .scanningSurface {
                viewModel.placePathIfNeeded()
            }
        }
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            process(anchors)
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            process(anchors)
        }

        // Runs every frame: keeps the viewModel's notion of "where is the child
        // looking right now" fresh, and drives the LiDAR scan progress card so the
        // scanning screen actually shows feedback while the room gets scanned
        // instead of appearing stuck. Matches the `nonisolated` + `Task { @MainActor }`
        // pattern `ARSceneCoordinator` already uses for the same `didUpdate frame:`
        // callback, since ARKit may not deliver it on the main thread.
        nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let transform = frame.camera.transform
            let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            let forward = -SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)

            var meshCount = 0
            var faceCount = 0
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                for anchor in frame.anchors {
                    guard let meshAnchor = anchor as? ARMeshAnchor else { continue }
                    meshCount += 1
                    faceCount += meshAnchor.geometry.faces.count
                }
            }

            Task { @MainActor in
                self.viewModel.updateCameraPose(position: position, forward: forward)
                if meshCount > 0 {
                    self.viewModel.arSceneViewModel.updateLiDARScan(meshCount: meshCount, faceCount: faceCount)
                }
            }
        }
        
        private func process(_ anchors: [ARAnchor]) {
            var meshCount = 0
            var faceCount = 0
            
            for anchor in anchors {
                if let plane = anchor as? ARPlaneAnchor {
                    viewModel.trackLatestHorizontalPlane(plane)
                }
                
                // FIX: Feed LiDAR data to the progress card
                if let mesh = anchor as? ARMeshAnchor {
                    meshCount += 1
                    faceCount += mesh.geometry.faces.count
                }
            }
            
            if meshCount > 0 {
                viewModel.arSceneViewModel.updateLiDARScan(meshCount: meshCount, faceCount: faceCount)
            }
        }
    }
}
