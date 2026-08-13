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

    var body: some View {
        ZStack {
            RealityView { content in
                // 1. Register Native ECS System
                HoldInteractionSystem.registerSystem()
                
                // 2. Add the plane-seeking anchor
                content.add(rootAnchor)
                
                // 3. Setup Scene
                viewModel.setupLevel(in: rootAnchor)
                viewModel.startScanning()
                
                // 4. Update Loop
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
