import Foundation
import SwiftUI
import RealityKit

/// SwiftUI wrapper around the ARView + ARSceneCoordinator. SwiftUI calls
/// updateUIView(_:context:) whenever an @Published property on viewModel
/// changes (because this view observes it), which is what drives
/// coordinator.synchronizeScene() each time the user edits a light, texture,
/// toggle, etc.
struct ARContainerView: UIViewRepresentable {
    @ObservedObject var viewModel: ARSceneViewModel

    func makeCoordinator() -> ARSceneCoordinator {
        ARSceneCoordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.configure(arView: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // SwiftUI can call this many times for consecutive @Published changes.
        // The coordinator coalesces those calls so one render pass schedules at
        // most one AR scene sync.
        context.coordinator.requestSceneSynchronization()
    }
}
