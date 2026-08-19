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
        
        // 1. Register Native ECS Systems
        PulseAnimationSystem.registerSystem()
//        WaypointSystem.registerSystem()
        
        // 2. Setup Root Anchor
        let rootAnchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(rootAnchor)
        viewModel.setupLevel(in: rootAnchor)
        
        // 3. Configure ARKit to open the Camera and detect planes
        let config = ARWorldTrackingConfiguration()
        // Bidang vertikal ikut dipindai supaya susunan checkpoint dapat menjaga
        // jarak dari tembok, bukan hanya menempel pada lantai yang ditemukan.
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        config.isLightEstimationEnabled = true
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        }
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        
        let supportsLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        if supportsLiDAR {
            config.sceneReconstruction = .mesh
        }
        context.coordinator.noteInitialSceneReconstructionState(isActive: supportsLiDAR)
        // `makeUIView` dijalankan di dalam update SwiftUI. Menunda publish ke
        // putaran main queue berikutnya menghindari perubahan ObservableObject
        // dari dalam lifecycle update view.
        Task { @MainActor in
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
        let coordinator = context.coordinator
        coordinator.subscription = AnyCancellable(arView.scene.subscribe(to: SceneEvents.Update.self) { _ in
            coordinator.processSceneFrame(in: arView)
        })

        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapRecognizer)
        context.coordinator.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        if viewModel.isSceneFrozen && !context.coordinator.hasFrozenScene {
            context.coordinator.hasFrozenScene = true
            uiView.session.pause()
        } else if !viewModel.isSceneFrozen,
                  context.coordinator.hasFrozenScene,
                  let configuration = uiView.session.configuration {
            context.coordinator.hasFrozenScene = false
            // Melanjutkan sesi yang sama tanpa reset tracking atau anchor.
            uiView.session.run(configuration)
        }

        if context.coordinator.lastCaptureFlag != viewModel.pendingDrawingPhotoCapture {
            context.coordinator.lastCaptureFlag = viewModel.pendingDrawingPhotoCapture
            context.coordinator.captureAndSaveSnapshot()
        }

        context.coordinator.setSceneReconstructionActive(
            viewModel.phase == .scanningSurface,
            in: uiView
        )
        
        // Show/Hide Coaching overlay based on Phase
        let shouldShowCoaching = viewModel.phase == .scanningSurface
            && viewModel.arSceneViewModel.surfaceState == .scanning
        context.coordinator.setCoachingActive(shouldShowCoaching)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    class Coordinator: NSObject, ARSessionDelegate, ARCoachingOverlayViewDelegate {
        let viewModel: Level1ViewModel
        var subscription: AnyCancellable?
        var lastCaptureFlag = false
        var hasFrozenScene = false
        private var isCoachingActive = false
        private var lastSceneUpdateTime: TimeInterval = 0
        private var lastProjectionUpdateTime: TimeInterval = 0
        private var isSceneReconstructionActive: Bool?
        private let sceneUpdateInterval: TimeInterval = 1.0 / 30.0
        private let projectionUpdateInterval: TimeInterval = 1.0 / 30.0
        private let markerSurfaceToneEstimator = EducationalMarkerSurfaceToneEstimator()
        weak var arView: ARView?
        private let realWorldOcclusionManager = LiDARMeshOcclusionManager(
            renderMode: .invisibleOccluder
        )
        
        weak var coachingOverlay: ARCoachingOverlayView? {
            didSet { coachingOverlay?.delegate = self }
        }
        
        init(viewModel: Level1ViewModel) {
            self.viewModel = viewModel
        }

        func processSceneFrame(in arView: ARView) {
            guard !hasFrozenScene,
                  let frame = arView.session.currentFrame else { return }
            let cameraTransform = frame.camera.transform

            if let tone = markerSurfaceToneEstimator.updatedTone(for: frame) {
                viewModel.markerSurfaceToneDidChange(tone)
            }

            let now = ProcessInfo.processInfo.systemUptime
            if now - lastSceneUpdateTime >= sceneUpdateInterval {
                lastSceneUpdateTime = now
                viewModel.processCameraFrame(cameraTransform: cameraTransform)
            }

            guard now - lastProjectionUpdateTime >= projectionUpdateInterval else { return }
            lastProjectionUpdateTime = now

            let guidePosition = viewModel.guideOverlayWorldPosition.flatMap(arView.project)
            viewModel.updateGuideOverlayScreenPosition(guidePosition)

            let objectPosition = viewModel.textureTapObjectWorldPosition.flatMap(arView.project)
            viewModel.updateTextureTapObjectScreenPosition(objectPosition)
        }

        func setCoachingActive(_ isActive: Bool) {
            guard isCoachingActive != isActive else { return }
            isCoachingActive = isActive
            coachingOverlay?.setActive(isActive, animated: true)
        }

        func setSceneReconstructionActive(_ isActive: Bool, in arView: ARView) {
            guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh),
                  isSceneReconstructionActive != isActive,
                  let configuration = arView.session.configuration as? ARWorldTrackingConfiguration else {
                return
            }

            isSceneReconstructionActive = isActive
            if isActive {
                realWorldOcclusionManager.reset()
                configuration.sceneReconstruction = .mesh
            } else {
                // Pertahankan mesh akhir sebagai depth occluder, lalu hentikan
                // pekerjaan rekonstruksi ARKit tanpa reset tracking/anchor game.
                realWorldOcclusionManager.freeze()
                configuration.sceneReconstruction = []
            }
            arView.session.run(configuration)
        }

        func noteInitialSceneReconstructionState(isActive: Bool) {
            isSceneReconstructionActive = isActive
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

        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            realWorldOcclusionManager.remove(anchors: anchors)
            viewModel.removeScannedAnchors(anchors)
        }

        private func process(_ anchors: [ARAnchor]) {
            guard viewModel.phase == .scanningSurface else { return }

            if let arView {
                // Mesh invisible menulis depth sehingga bayangan fallback tidak
                // tergambar menembus furnitur atau tembok dunia nyata.
                _ = realWorldOcclusionManager.update(from: anchors, in: arView)
            }

            for anchor in anchors {
                if let plane = anchor as? ARPlaneAnchor {
                    viewModel.trackPlane(plane)
                }

                if let mesh = anchor as? ARMeshAnchor {
                    viewModel.trackSceneMesh(mesh)
                }
            }
        }

    }
}
