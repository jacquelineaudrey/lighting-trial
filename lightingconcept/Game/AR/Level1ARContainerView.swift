import SwiftUI
import RealityKit

/// SwiftUI wrapper around the ARView + Level1ARCoordinator, dipakai sebagai
/// background kamera untuk seluruh flow Level 1 (dialog, eksplorasi, quiz,
/// kembali ke checkpoint pertama semuanya tampil sebagai overlay di atas ini).
struct Level1ARContainerView: UIViewRepresentable {
    @ObservedObject var viewModel: Level1ViewModel

    func makeCoordinator() -> Level1ARCoordinator {
        Level1ARCoordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.configure(arView: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Sinkronisasi tekstur/checkpoint di-drive lewat Combine di dalam
        // coordinator (lihat observeTextureChanges), jadi tidak perlu apa-apa
        // di sini — cukup biarkan SwiftUI tetap observe viewModel supaya view
        // ini di-refresh saat state berubah.
    }
}
