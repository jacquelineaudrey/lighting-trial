////
////  Level4ARContainerView.swift
////  lightingconcept
////
////  Created by Justin Hartanto Widjaja on 13/08/26.
////
//
//import SwiftUI
//import RealityKit
//import ARKit
//import Combine
//
///// Simpan referensi ke `ARView` yang sedang aktif supaya kontrol hold-to-walk
///// di `Level4FlowView` bisa membaca posisi kamera device tiap saat, tanpa
///// perlu jadi ARSessionDelegate kedua (ARSession cuma boleh punya satu delegate,
///// dan `ARSceneCoordinator` sudah memegangnya untuk shadow rendering).
//@MainActor
//final class ARViewHandle: ObservableObject {
//    fileprivate(set) weak var arView: ARView?
//
//    /// Posisi kamera device saat ini di ruang dunia ARKit (meter).
//    var currentCameraPosition: SIMD3<Float>? {
//        guard let transform = arView?.session.currentFrame?.camera.transform else { return nil }
//        return SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
//    }
//
//    /// Posisi kamera device saat ini, dikonversi ke ruang LOKAL anchor scene
//    /// (tempat cube & lampu Level 4 sebenarnya ditempel), BUKAN posisi dunia
//    /// mentah. `ARSceneViewModel` menyimpan posisi object/lampu dalam ruang
//    /// lokal anchor itu, jadi delta hold-to-walk (`Level4ViewModel.updateHold`)
//    /// harus dihitung di ruang yang sama juga — pakai `anchor.convert(...)`,
//    /// pola yang sama seperti `ARSceneCoordinator.moveObject`/`moveSelectedLight`
//    /// — supaya arah geser tetap benar walau anchor scene-nya berputar
//    /// (tidak lurus terhadap dunia). Sebelumnya kode ini menambahkan delta
//    /// posisi kamera DUNIA langsung ke posisi lokal, yang secara diam-diam
//    /// berasumsi anchor-nya tidak pernah berotasi terhadap dunia.
//    var currentCameraPositionInSceneAnchorSpace: SIMD3<Float>? {
//        guard let arView,
//              let sceneAnchor = arView.scene.findEntity(named: ARSceneCoordinator.sceneAnchorName),
//              let cameraTransform = arView.session.currentFrame?.camera.transform else { return nil }
//        let worldPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
//        return sceneAnchor.convert(position: worldPosition, from: nil)
//    }
//
//    /// Vektor "maju" kamera SAAT INI, diproyeksikan ke bidang horizontal &
//    /// dikonversi ke ruang LOKAL anchor scene (bukan dunia) — dipakai oleh
//    /// mekanisme hold "anchor tanam pada kamera" di `Level4ViewModel.updateHold`
//    /// supaya lampu/objek terus mengikuti arah hadap device selama tombol
//    /// ditahan, bukan cuma pergeseran posisi (translasi).
//    ///
//    /// `convert(direction:from:)` dipakai (bukan `convert(position:from:)`)
//    /// karena ini vektor arah — cuma rotasi anchor yang relevan, translasinya
//    /// tidak boleh ikut terbawa.
//    var currentHorizontalForwardInSceneAnchorSpace: SIMD3<Float>? {
//        guard let arView,
//              let sceneAnchor = arView.scene.findEntity(named: ARSceneCoordinator.sceneAnchorName),
//              let cameraTransform = arView.session.currentFrame?.camera.transform else { return nil }
//        let worldForward = -SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
//        let localForward = sceneAnchor.convert(direction: worldForward, from: nil)
//        return normalizedHorizontal(localForward)
//    }
//
//    private func normalizedHorizontal(_ vector: SIMD3<Float>) -> SIMD3<Float> {
//        let flat = SIMD3<Float>(vector.x, 0, vector.z)
//        let length = flat.horizontalLength
//        guard length > 0.0001 else { return SIMD3<Float>(0, 0, -1) }
//        return flat / length
//    }
//}
//
///// Sama persis dengan `ARContainerView` yang sudah ada (reuse `ARSceneCoordinator`
///// apa adanya supaya shadow/ground-projection tetap dihitung oleh engine yang
///// sudah teruji) — bedanya cuma menyimpan referensi `ARView` ke `ARViewHandle`.
//struct Level4ARContainerView: UIViewRepresentable {
//    @ObservedObject var viewModel: ARSceneViewModel
//    let handle: ARViewHandle
//
//    func makeCoordinator() -> ARSceneCoordinator {
//        ARSceneCoordinator(viewModel: viewModel)
//    }
//
//    func makeUIView(context: Context) -> ARView {
//        let arView = ARView(frame: .zero)
//        handle.arView = arView
//        // Sama seperti `ARContainerView`: `configure` memicu `viewModel`
//        // publishing (lewat `runSession`'s LiDAR availability flags), dan
//        // `makeUIView` berjalan di tengah SwiftUI view update pass, jadi
//        // publish di sini langsung memicu "Publishing changes from within
//        // view updates is not allowed." Ditunda ke run loop berikutnya.
//        DispatchQueue.main.async {
//            context.coordinator.configure(arView: arView)
//        }
//        return arView
//    }
//
//    func updateUIView(_ uiView: ARView, context: Context) {
//        let coordinator = context.coordinator
//        DispatchQueue.main.async {
//            coordinator.synchronizeScene()
//        }
//    }
//}
