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
        // SwiftUI invokes this method while it is rendering the view. Scene
        // synchronization can update published UI state (for example,
        // `shadowInfo`), so defer it until that render pass has completed.
        // Publishing here directly causes: "Publishing changes from within
        // view updates is not allowed."
        let coordinator = context.coordinator
        DispatchQueue.main.async {
            coordinator.synchronizeScene()
        }
    }
}
