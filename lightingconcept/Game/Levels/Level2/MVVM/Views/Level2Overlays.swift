import SwiftUI

// MARK: - Reusable Controls

struct Level2ReplayNarrationButton: View {
    let action: () -> Void

    var body: some View {
        Button("Dengarkan Lagi", systemImage: "speaker.wave.2.fill", action: action)
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityHint("Memutar ulang petunjuk kegiatan")
    }
}

// MARK: - Dialog & Placement

struct Level2DialogOverlay: View {
    let line: DialogLine
    let buttonTitle: String
    let replayNarration: () -> Void
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("🦉").font(.largeTitle.scaled(by: 1.6)).accessibilityHidden(true)
            Text(line.characterName).font(.headline).foregroundStyle(.blue)
            Text(line.text).font(.title3).bold().multilineTextAlignment(.center)
            Level2ReplayNarrationButton(action: replayNarration)
            Button(buttonTitle, action: action)
                .font(.title3).bold().buttonStyle(.borderedProminent)
                .controlSize(.large).frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(.thinMaterial, in: .rect(cornerRadius: 28))
        .padding(.horizontal, 20)
        .padding(.bottom, 36)
    }
}

struct Level2PlacementOverlay: View {
    @ObservedObject var sceneViewModel: ARSceneViewModel
    let replayNarration: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            SurfaceScanInstruction(sceneViewModel: sceneViewModel)
            Text(guidanceText).font(.headline).multilineTextAlignment(.center)
            Button("Taruh Benda di Tengah", systemImage: "cube.fill", action: sceneViewModel.placeSceneAtScreenCenter)
                .buttonStyle(.borderedProminent).controlSize(.large)
                .accessibilityHint("Menaruh benda pada permukaan di tengah layar")
            if let placementFeedback = sceneViewModel.placementFeedback {
                Label(placementFeedback, systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.subheadline).foregroundStyle(.orange).multilineTextAlignment(.center)
            }
            Level2ReplayNarrationButton(action: replayNarration)
        }
        .padding(20)
        .background(.thinMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
    }

    private var guidanceText: String {
        switch sceneViewModel.surfaceState {
        case .scanning: "Arahkan titik tengah layar ke meja atau lantai, lalu tekan tombol di bawah."
        case .found: "Tempatnya ditemukan! Tekan tombol untuk menaruh benda."
        case .placed: "Benda sudah siap!"
        }
    }
}

// MARK: - Learning Tasks

struct Level2ShadowExplorationOverlay: View {
    let viewModel: Level2ViewModel
    let replayNarration: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Label("Misi: Cari Bayangan", systemImage: "figure.walk").font(.title3).bold()
            Text("Jalan pelan mengelilingi benda. Lihat bayangannya dari tiga sisi!")
                .font(.headline).multilineTextAlignment(.center)
            ProgressView(value: Double(viewModel.shadowProgress), total: 3).tint(.blue)
                .accessibilityLabel("Sisi bayangan yang ditemukan")
                .accessibilityValue("\(viewModel.shadowProgress) dari 3 sisi")
            Text("⭐️ \(viewModel.shadowProgress) dari 3 sisi ditemukan").font(.headline)
            Level2ReplayNarrationButton(action: replayNarration)
            if viewModel.hasCompletedShadowTask {
                Label("Hebat! Semua sisi ditemukan!", systemImage: "checkmark.seal.fill")
                    .font(.headline).foregroundStyle(.green)
                Button("Pelajari Bayangan", action: viewModel.continueFromShadowTask)
                    .buttonStyle(.borderedProminent).controlSize(.large)
            } else {
                Text("Lihat jalan di sekitarmu dan pegang iPad dengan erat.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                #if DEBUG
                Button("Lewati Misi Bayangan (Debug)", action: viewModel.completeShadowTaskForDebugging)
                    .font(.footnote).buttonStyle(.bordered)
                #endif
            }
        }
        .padding(20).background(.thinMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16).padding(.bottom, 28)
    }
}

struct Level2SpreadExplorationOverlay: View {
    let viewModel: Level2ViewModel
    let replayNarration: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Label("Misi: Ubah Lebar Cahaya", systemImage: "arrow.left.and.right").font(.title3).bold()
            Text("Rapatkan dan jauhkan dua ibu jari di layar.").font(.headline).multilineTextAlignment(.center)
            ProgressView(value: Double(viewModel.beamSpreadDegrees - Level2ViewModel.minimumBeamAngle), total: Double(Level2ViewModel.maximumBeamAngle - Level2ViewModel.minimumBeamAngle))
                .tint(.orange).accessibilityLabel("Lebar cahaya")
                .accessibilityValue("\(Int(viewModel.beamSpreadDegrees.rounded())) derajat")
            HStack {
                Label("Sempit", systemImage: viewModel.hasReachedNarrowSpread ? "checkmark.circle.fill" : "circle")
                Spacer(); Text("\(Int(viewModel.beamSpreadDegrees.rounded()))°").font(.title3).bold(); Spacer()
                Label("Lebar", systemImage: viewModel.hasReachedWideSpread ? "checkmark.circle.fill" : "circle")
            }.font(.subheadline)
            Text("Percobaan \(viewModel.spreadProgress) dari 2").font(.subheadline).foregroundStyle(.secondary)
            Level2ReplayNarrationButton(action: replayNarration)
            if viewModel.hasCompletedSpreadTask {
                Label("Cahaya sempit dan lebar sudah dicoba!", systemImage: "checkmark.seal.fill")
                    .font(.headline).foregroundStyle(.green).multilineTextAlignment(.center)
                Button("Lanjut", action: viewModel.continueFromSpreadTask).buttonStyle(.borderedProminent).controlSize(.large)
            }
        }
        .padding(20).background(.thinMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16).padding(.bottom, 28)
    }
}

struct Level2IntensityExplorationOverlay: View {
    let viewModel: Level2ViewModel
    let replayNarration: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Label("Misi: Terang dan Redup", systemImage: "sun.max.fill").font(.title3).bold()
            Text("Usap naik atau turun di sisi kiri atau kanan layar.").font(.headline).multilineTextAlignment(.center)
            ProgressView(value: Double(viewModel.intensityPercentage), total: 100).tint(.yellow)
                .accessibilityLabel("Kekuatan cahaya")
                .accessibilityValue("\(viewModel.intensityPercentage) persen, \(intensityName)")
            HStack {
                Label("Redup", systemImage: viewModel.hasReachedDimIntensity ? "checkmark.circle.fill" : "circle")
                Spacer(); Label(intensityName, systemImage: intensitySymbol).font(.title3).bold(); Spacer()
                Label("Terang", systemImage: viewModel.hasReachedBrightIntensity ? "checkmark.circle.fill" : "circle")
            }.font(.subheadline)
            Text("Percobaan \(viewModel.intensityProgress) dari 2").font(.subheadline).foregroundStyle(.secondary)
            Level2ReplayNarrationButton(action: replayNarration)
            if viewModel.hasCompletedIntensityTask {
                Label("Cahaya redup dan terang sudah dicoba!", systemImage: "checkmark.seal.fill")
                    .font(.headline).foregroundStyle(.green).multilineTextAlignment(.center)
                Button("Lanjut", action: viewModel.continueFromIntensityTask).buttonStyle(.borderedProminent).controlSize(.large)
            }
        }
        .padding(20).background(.thinMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16).padding(.bottom, 28)
    }

    private var intensityName: String {
        viewModel.intensityPercentage < 34 ? "Redup" : viewModel.intensityPercentage > 70 ? "Terang" : "Sedang"
    }

    private var intensitySymbol: String {
        viewModel.intensityPercentage < 34 ? "sun.min.fill" : viewModel.intensityPercentage > 70 ? "sun.max.fill" : "sun.max"
    }
}

// MARK: - Completion

struct Level2ReviewOverlay: View {
    let replayNarration: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ingat Tiga Penemuanmu! 🌟").font(.title2).bold().frame(maxWidth: .infinity, alignment: .center)
            ForEach(Level2Content.reviewPoints, id: \.self) { point in
                Label(point, systemImage: "star.fill").font(.headline).foregroundStyle(.primary)
            }
            Level2ReplayNarrationButton(action: replayNarration).frame(maxWidth: .infinity)
            Button("Selesaikan Level 2", action: onFinish).buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
        }
        .padding(22).background(.thinMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16).padding(.bottom, 28)
    }
}

struct Level2CompletedOverlay: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("🏆").font(.largeTitle.scaled(by: 1.7)).accessibilityHidden(true)
            Text("Level 2 Selesai!").font(.title).bold()
            Text("Kamu hebat, Detektif Cahaya!").font(.title3).bold().multilineTextAlignment(.center)
            Button("Kembali ke Menu", action: onFinish).buttonStyle(.borderedProminent).controlSize(.large)
        }
        .padding(24).background(.thinMaterial, in: .rect(cornerRadius: 28))
        .padding(.horizontal, 24).padding(.bottom, 48)
    }
}
