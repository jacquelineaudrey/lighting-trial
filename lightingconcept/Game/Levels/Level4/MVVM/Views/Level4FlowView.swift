////
////  Level4FlowView.swift
////  lightingconcept
////
////  Created by Justin Hartanto Widjaja on 13/08/26.
////
//
//import SwiftUI
//
//struct Level4FlowView: View {
//    @StateObject private var viewModel = Level4ViewModel()
//    @Environment(\.dismiss) private var dismiss
//    @State private var showsExitConfirmation = false
//
//    var body: some View {
//        ZStack(alignment: .bottom) {
//            Level4ARView(viewModel: viewModel)
//                .ignoresSafeArea()
//
//            switch viewModel.phase {
//            case .onboarding:
//                Level4DialogOverlay(
//                    line: viewModel.currentOnboardingLine,
//                    buttonTitle: viewModel.isLastOnboardingLine ? "Ayo Coba!" : "Lanjut",
//                    action: viewModel.advanceOnboarding
//                )
//            case .scanningSurface:
//                Level4ScanningSurfaceOverlay(viewModel: viewModel)
//            case .positioning:
//                PositioningOverlay(viewModel: viewModel)
//            case .transitionTrivia:
//                Level4DialogOverlay(
//                    line: viewModel.currentTransitionLine,
//                    buttonTitle: viewModel.isLastTransitionLine ? "Mulai Jelajah!" : "Lanjut",
//                    action: viewModel.advanceTransition
//                )
//            case .exploring:
//                ExploringOverlay(viewModel: viewModel)
//            case .closing:
//                Level4DialogOverlay(
//                    line: viewModel.currentClosingLine,
//                    buttonTitle: viewModel.isLastClosingLine ? "Lihat Rangkuman" : "Lanjut",
//                    action: viewModel.advanceClosing
//                )
//            case .review:
//                ReviewOverlay(points: viewModel.reviewPoints, onFinish: viewModel.finishReview)
//            case .completed:
//                Level4CompletedOverlay { dismiss() }
//            }
//        }
//        .overlay(alignment: .topLeading) {
//            if viewModel.phase != .completed {
//                Button(action: { showsExitConfirmation = true }) {
//                    Image(systemName: "xmark")
//                        .font(.system(size: 20, weight: .bold))
//                        .foregroundColor(.white)
//                        .padding(12)
//                        .background(.black.opacity(0.4), in: Circle())
//                }
//                .padding(.leading, 16)
//                .padding(.top, 12)
//            }
//        }
//        .confirmationDialog("Keluar dari Level?", isPresented: $showsExitConfirmation, titleVisibility: .visible) {
//            Button("Keluar", role: .destructive) { dismiss() }
//            Button("Batal", role: .cancel) { }
//        } message: {
//            Text("Progres kamu di level ini tidak akan disimpan.")
//        }
//        .animation(.easeInOut, value: viewModel.phase)
//        .navigationBarBackButtonHidden(true)
//    }
//}
//
//// MARK: - Overlays & Buttons
//
//private struct HoldToWalkButton: View {
//    let title: String
//    let systemImage: String
//    let tint: Color
//    let role: HoldRole
//    @ObservedObject var viewModel: Level4ViewModel
//
//    var body: some View {
//        let isHolding = viewModel.activeHoldRole == role
//        
//        Label(title, systemImage: systemImage)
//            .font(.headline)
//            .frame(maxWidth: .infinity)
//            .padding(.vertical, 14)
//            .background(isHolding ? tint : tint.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
//            .foregroundStyle(.white)
//            .scaleEffect(isHolding ? 1.05 : 1)
//            .onLongPressGesture(
//                minimumDuration: .infinity,
//                maximumDistance: .infinity,
//                pressing: { pressing in
//                    viewModel.setHold(role: role, isHeld: pressing)
//                },
//                perform: {}
//            )
//            .onDisappear {
//                viewModel.setHold(role: role, isHeld: false)
//            }
//    }
//}
//
//private struct PositioningOverlay: View {
//    @ObservedObject var viewModel: Level4ViewModel
//
//    var body: some View {
//        VStack(spacing: 14) {
//            Text("Tahan tombol lalu gerakkan iPad untuk memindahkan posisi. Geser layar tanpa menahan tombol hanya mengubah arah.")
//                .font(.subheadline.bold())
//                .multilineTextAlignment(.center)
//
//            HStack(spacing: 12) {
//                HoldToWalkButton(title: "Jadi Lampu", systemImage: "lightbulb.fill", tint: .orange, role: .light, viewModel: viewModel)
//                HoldToWalkButton(title: "Jadi Objek", systemImage: "cube.fill", tint: .blue, role: .object, viewModel: viewModel)
//            }
//
//            if viewModel.hasPositionedOnce {
//                Button("Lanjut") { viewModel.proceedToTransitionTrivia() }
//                    .buttonStyle(.borderedProminent)
//            } else {
//                Text("Coba geser dulu salah satunya ya!")
//                    .font(.footnote)
//                    .foregroundStyle(.secondary)
//            }
//        }
//        .padding(18)
//        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
//        .padding(.horizontal, 16)
//        .padding(.bottom, 30)
//    }
//}
//
//private struct ExploringOverlay: View {
//    @ObservedObject var viewModel: Level4ViewModel
//
//    var body: some View {
//        VStack(spacing: 14) {
//            Text("Tahan tombol untuk memindahkan. Geser layar untuk mengubah arah lampu atau objek, lalu lihat bayangannya berubah 👀")
//                .font(.subheadline.bold())
//                .multilineTextAlignment(.center)
//
//            HStack(spacing: 12) {
//                HoldToWalkButton(title: "Jadi Lampu", systemImage: "lightbulb.fill", tint: .orange, role: .light, viewModel: viewModel)
//                HoldToWalkButton(title: "Jadi Objek", systemImage: "cube.fill", tint: .blue, role: .object, viewModel: viewModel)
//            }
//
//            Button("Selesai Menjelajah") { viewModel.finishExploring() }
//                .buttonStyle(.bordered)
//        }
//        .padding(18)
//        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
//        .padding(.horizontal, 16)
//        .padding(.bottom, 30)
//    }
//}
//
//private struct Level4DialogOverlay: View {
//    let line: DialogLine
//    let buttonTitle: String
//    let action: () -> Void
//
//    var body: some View {
//        VStack(spacing: 14) {
//            Text("🦉").font(.system(size: 56))
//            Text(line.characterName)
//                .font(.headline)
//                .foregroundStyle(.blue)
//            Text(line.text)
//                .font(.system(size: 19, weight: .medium, design: .rounded))
//                .multilineTextAlignment(.center)
//
//            Button(action: action) {
//                Text(buttonTitle)
//                    .font(.title3.bold())
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(.blue, in: RoundedRectangle(cornerRadius: 18))
//                    .foregroundStyle(.white)
//            }
//        }
//        .padding(22)
//        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 26))
//        .padding(.horizontal, 20)
//        .padding(.bottom, 40)
//    }
//}
//
//private struct Level4ScanningSurfaceOverlay: View {
//    @ObservedObject var viewModel: Level4ViewModel
//
//    var body: some View {
//        VStack {
//            Text("📱👇 Arahkan iPad pelan-pelan ke lantai atau meja ya!")
//                .font(.system(size: 18, weight: .bold, design: .rounded))
//                .multilineTextAlignment(.center)
//                .padding(14)
//                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
//                .padding(.top, 24)
//            
//            // Re-add your LiDARScanProgressCard here if needed
//            
//            Button(action: { viewModel.finishScanning() }) {
//                Text("🛠 [Dev] Paksa Lewati Scan")
//                    .font(.footnote.bold())
//                    .padding(10)
//                    .background(.red.opacity(0.8), in: Capsule())
//                    .foregroundColor(.white)
//            }
//            .padding(.top, 8)
//
//            Spacer()
//        }
//        .frame(maxWidth: .infinity)
//    }
//}
//
//private struct ReviewOverlay: View {
//    let points: [String]
//    let onFinish: () -> Void
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 14) {
//            Text("Yuk, Ingat-Ingat Lagi! 📝")
//                .font(.title3.bold())
//                .frame(maxWidth: .infinity, alignment: .center)
//
//            ForEach(points, id: \.self) { point in
//                HStack(alignment: .top, spacing: 8) {
//                    Text("⭐️")
//                    Text(point).font(.subheadline)
//                }
//            }
//
//            Button("Selesai") { onFinish() }
//                .buttonStyle(.borderedProminent)
//                .frame(maxWidth: .infinity)
//        }
//        .padding(20)
//        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
//        .padding(.horizontal, 16)
//        .padding(.bottom, 30)
//    }
//}
//
//private struct Level4CompletedOverlay: View {
//    let onFinish: () -> Void
//
//    var body: some View {
//        VStack(spacing: 16) {
//            Text("🏆").font(.system(size: 64))
//            Text("Level 4 Selesai!")
//                .font(.system(size: 26, weight: .heavy, design: .rounded))
//            Text("Kamu sudah paham posisi lampu dan bayangan (ground projection)!")
//                .font(.headline)
//                .foregroundStyle(.secondary)
//                .multilineTextAlignment(.center)
//            Button("Kembali ke Menu") { onFinish() }
//                .buttonStyle(.borderedProminent)
//        }
//        .padding(24)
//        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28))
//        .padding(.horizontal, 24)
//        .padding(.bottom, 60)
//    }
//}
