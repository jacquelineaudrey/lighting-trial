import SwiftUI
import RealityKit
import ARKit
import Combine

/// Simpan referensi ke `ARView` yang sedang aktif supaya kontrol hold-to-walk
/// di `Level4FlowView` bisa membaca posisi kamera device tiap saat, tanpa
/// perlu jadi ARSessionDelegate kedua (ARSession cuma boleh punya satu delegate,
/// dan `ARSceneCoordinator` sudah memegangnya untuk shadow rendering).
@MainActor
final class ARViewHandle: ObservableObject {
    fileprivate(set) weak var arView: ARView?

    /// Posisi kamera device saat ini di ruang dunia ARKit (meter).
    var currentCameraPosition: SIMD3<Float>? {
        guard let transform = arView?.session.currentFrame?.camera.transform else { return nil }
        return SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
}

/// Sama persis dengan `ARContainerView` yang sudah ada (reuse `ARSceneCoordinator`
/// apa adanya supaya shadow/ground-projection tetap dihitung oleh engine yang
/// sudah teruji) — bedanya cuma menyimpan referensi `ARView` ke `ARViewHandle`.
struct Level4ARContainerView: UIViewRepresentable {
    @ObservedObject var viewModel: ARSceneViewModel
    let handle: ARViewHandle

    func makeCoordinator() -> ARSceneCoordinator {
        ARSceneCoordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.configure(arView: arView)
        handle.arView = arView
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        let coordinator = context.coordinator
        DispatchQueue.main.async {
            coordinator.synchronizeScene()
        }
    }
}
