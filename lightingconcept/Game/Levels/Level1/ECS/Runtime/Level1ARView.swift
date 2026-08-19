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
import Photos
import UIKit

struct Level1ARView: UIViewRepresentable {
    @ObservedObject var viewModel: Level1ViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        arView.environment.lighting.intensityExponent = 0
        arView.renderOptions.insert(.disableMotionBlur)
        arView.renderOptions.insert(.disableDepthOfField)
        arView.renderOptions.insert(.disablePersonOcclusion)
        
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
        config.environmentTexturing = .automatic
        config.isLightEstimationEnabled = true
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        }
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        arView.environment.sceneUnderstanding.options.insert(.collision)
        arView.environment.sceneUnderstanding.options.insert(.receivesLighting)
        
        let supportsLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        if supportsLiDAR {
            config.sceneReconstruction = .mesh
        }
        // `makeUIView` dijalankan di dalam update SwiftUI. Menunda publish ke
        // putaran main queue berikutnya menghindari perubahan ObservableObject
        // dari dalam lifecycle update view.
        DispatchQueue.main.async {
            viewModel.arSceneViewModel.isLiDARAvailable = supportsLiDAR
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
            if let guideWorldPosition = viewModel.guideOverlayWorldPosition,
               let projectedPosition = arView.project(guideWorldPosition) {
                viewModel.updateGuideOverlayScreenPosition(projectedPosition)
            } else {
                viewModel.updateGuideOverlayScreenPosition(nil)
            }
            if let objectWorldPosition = viewModel.textureTapObjectWorldPosition,
               let projectedObjectPosition = arView.project(objectWorldPosition) {
                viewModel.updateTextureTapObjectScreenPosition(projectedObjectPosition)
            } else {
                viewModel.updateTextureTapObjectScreenPosition(nil)
            }
        })

        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapRecognizer)
        context.coordinator.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        viewModel.syncEntities()

        if viewModel.isSceneFrozen && !context.coordinator.hasFrozenScene {
            context.coordinator.hasFrozenScene = true
            uiView.session.pause()
        }

        if context.coordinator.lastCaptureFlag != viewModel.pendingDrawingPhotoCapture {
            context.coordinator.lastCaptureFlag = viewModel.pendingDrawingPhotoCapture
            context.coordinator.captureAndSaveSnapshot()
        }
        
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
        var lastCaptureFlag = false
        var hasFrozenScene = false
        weak var arView: ARView?
        
        weak var coachingOverlay: ARCoachingOverlayView? {
            didSet { coachingOverlay?.delegate = self }
        }
        
        init(viewModel: Level1ViewModel) {
            self.viewModel = viewModel
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView else { return }
            let location = recognizer.location(in: arView)
            viewModel.handleTap(on: arView.entity(at: location))
        }

        func captureAndSaveSnapshot() {
            guard let arView else {
                viewModel.completeFrozenSceneSnapshot(success: false, image: nil, message: "Kamera AR belum siap.")
                return
            }

            arView.snapshot(saveToHDR: false) { [weak self] image in
                Task { @MainActor in
                    guard let self else { return }
                    guard let image else {
                        self.viewModel.completeFrozenSceneSnapshot(success: false, image: nil, message: "Foto AR gagal dibuat.")
                        return
                    }
                    self.saveImageToPhotoLibrary(image)
                }
            }
        }

        private func saveImageToPhotoLibrary(_ image: UIImage) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
                guard let self else { return }
                switch status {
                case .authorized, .limited:
                    PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    } completionHandler: { success, error in
                        Task { @MainActor in
                            self.viewModel.completeFrozenSceneSnapshot(
                                success: success,
                                image: success ? image : nil,
                                message: success ? nil : "Foto belum tersimpan. \(error?.localizedDescription ?? "")"
                            )
                        }
                    }
                default:
                    Task { @MainActor in
                        self.viewModel.completeFrozenSceneSnapshot(
                            success: false,
                            image: nil,
                            message: "Izinkan akses Photos untuk menyimpan foto."
                        )
                    }
                }
            }
        }
        
        // The coaching overlay only helps find a horizontal surface. Level 1
        // advances automatically once the scan is stable enough.
        func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
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

            // Capture immutable values before crossing to the main actor. Swift 6
            // rejects capturing the mutable loop counters in this concurrent task.
            let scannedMeshCount = meshCount
            let scannedFaceCount = faceCount

            Task { @MainActor in
                self.viewModel.updateCameraPose(position: position, forward: forward)
                if scannedMeshCount > 0 {
                    self.viewModel.arSceneViewModel.updateLiDARScan(meshCount: scannedMeshCount, faceCount: scannedFaceCount)
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
