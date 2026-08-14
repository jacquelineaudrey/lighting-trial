//
//  Level4ARView.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import SwiftUI
import RealityKit

struct Level4ARView: View {
    @ObservedObject var viewModel: Level4ViewModel
    
    // RealityKit natively handles the ARKit tracking to find a horizontal surface.
    @State private var rootAnchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: [0.2, 0.2]))
    @State private var lastSyncedTexture: MaterialTexture?

    var body: some View {
        ZStack {
            RealityView { content in
                // 1. Register Native ECS System
                HoldInteractionSystem.registerSystem()

                // 2. Turn on camera passthrough. `RealityView`'s camera defaults to
                // `.virtual` (no video feed, just a rendered scene), which is why the
                // camera never showed up before — `.spatialTracking` is what makes
                // RealityView run an ARKit session and composite content over the
                // live camera image, same as `ARView`'s `.ar` camera mode.
                content.camera = .spatialTracking
                
                // 3. Add the plane-seeking anchor
                content.add(rootAnchor)
                
                // 4. Setup Scene
                viewModel.setupLevel(in: rootAnchor)
                viewModel.startScanning()
                
                // 5. Update Loop
                _ = content.subscribe(to: SceneEvents.Update.self) { event in
                    // Sync shadows and ECS data
                    viewModel.syncPositionsFromECS(scene: event.scene)
                    
                    // Check if RealityKit successfully locked onto a physical floor
                    if viewModel.phase == .scanningSurface && rootAnchor.isAnchored {
                        viewModel.placeSceneIfNeeded()
                    }
                }
                
            } update: { content in
                // Push SwiftUI state down to ECS components
                viewModel.syncHoldStatesToECS(rootAnchor: rootAnchor)

                // Build/update the actual cube + light RealityKit entities from
                // `arSceneViewModel`'s data. Without this the scene stays empty even
                // after the camera and floor anchor are working, since nothing else
                // in the RealityView flow ever creates the visible object/light.
                SceneObjectSystem.synchronize(
                    anchor: rootAnchor,
                    requestedObjects: viewModel.arSceneViewModel.objects,
                    selectedTexture: viewModel.arSceneViewModel.selectedTexture,
                    lastTexture: &lastSyncedTexture,
                    reportImportedDimensions: { id, dimensions in
                        viewModel.arSceneViewModel.updateImportedModelDimensions(id: id, dimensions: dimensions)
                    },
                    reportModelLoadFailure: { name, error in
                        viewModel.arSceneViewModel.reportModelLoadFailure(named: name, error: error)
                    },
                    debugLog: viewModel.arSceneViewModel.debugLog
                )

                viewModel.arSceneViewModel.collisionWarning = SceneLightSystem.synchronize(
                    anchor: rootAnchor,
                    requestedLights: viewModel.arSceneViewModel.lights,
                    selectedLightID: viewModel.arSceneViewModel.selectedLightID,
                    updateLightPosition: viewModel.arSceneViewModel.updateLightPosition,
                    debugLog: viewModel.arSceneViewModel.debugLog
                )
            }
            
            // Render scanning UI if the floor hasn't been found yet
            if viewModel.phase == .scanningSurface {
                // Assuming you have your Level4ScanningSurfaceOverlay defined in FlowView
                // If you are completely removing UIViewRepresentable, you will also drop the ARCoachingOverlayView
                // and just rely on your custom SwiftUI text instructing the user to move the device.
                Text("📱👇 Arahkan iPad pelan-pelan ke lantai atau meja ya!")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    .padding(.top, 24)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }
}
