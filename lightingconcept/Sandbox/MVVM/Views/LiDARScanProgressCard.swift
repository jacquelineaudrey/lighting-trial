//
//  LiDARScanProgressCard.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import SwiftUI

/// Kartu scan LiDAR dengan persentase — SATU-SATUNYA sumber UI scan permukaan
/// di seluruh app. Awalnya cuma dipakai `ContentView` (mode sandbox), sekarang
/// dipakai ulang di `Level1FlowView`/`ScanningSurfaceOverlay` dan
/// `Level4FlowView`/`ScanningSurfaceOverlay` juga, supaya SEMUA level (1 & 4)
/// menampilkan progres scan permukaan yang sama persis — bukan masing-masing
/// bikin UI scan sendiri.
///
/// Selalu diberi `ARSceneViewModel` (baik yang dipakai `ARSceneCoordinator`
/// beneran seperti di sandbox/Level 4, maupun instance yang cuma dipakai
/// sebagai "penampung" progres LiDAR seperti di `Level1ViewModel`) supaya
/// `lidarPlacementProgress`/`isReadyForPlacement` selalu berasal dari mesin
/// hitung yang sama.
struct LiDARScanProgressCard: View {
    @ObservedObject var viewModel: ARSceneViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("LiDAR Surface Scan", systemImage: "cube.transparent")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(viewModel.isReadyForPlacement ? "Ready" : "\(Int(viewModel.lidarPlacementProgress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: viewModel.lidarPlacementProgress)
                .tint(viewModel.isReadyForPlacement ? .green : .cyan)

            Text(viewModel.isReadyForPlacement
                 ? "Area siap. Tap meja atau permukaan datar untuk menaruh object."
                 : "Arahkan kamera perlahan ke meja, sisi benda, dan tepi permukaan. Area cyan adalah bagian yang sudah terbaca.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: 380)
    }
}
