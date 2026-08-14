//
//  Level1FlowView.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import SwiftUI

struct Level1FlowView: View {
    @StateObject private var viewModel = Level1ViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showsExitConfirmation = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Level1ARView(viewModel: viewModel)
                .ignoresSafeArea()

            switch viewModel.phase {
            case .onboarding:
                TriviaDialogOverlay(viewModel: viewModel)
            case .scanningSurface:
                ScanningSurfaceOverlay(viewModel: viewModel)
            case .exploring:
                CheckpointExploreOverlay(viewModel: viewModel)
            case .quiz:
                QuizOverlay(viewModel: viewModel)
            case .returningToStart:
                ReturnToStartOverlay(viewModel: viewModel)
            case .completed:
                LevelCompletedOverlay { dismiss() }
            }
        }
        .overlay(alignment: .bottomLeading) {
            if showsTextureThumbControls {
                ThumbNavButton(systemImage: "chevron.left", isEnabled: viewModel.canGoToPreviousTexture) {
                    viewModel.previousTexture()
                }
                .padding(.leading, 20)
                .padding(.bottom, 170)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showsTextureThumbControls {
                ThumbNavButton(systemImage: "chevron.right", isEnabled: viewModel.canGoToNextTexture) {
                    viewModel.nextTexture()
                }
                .padding(.trailing, 20)
                .padding(.bottom, 170)
            }
        }
        .overlay(alignment: .topLeading) {
            if viewModel.phase != .completed {
                Button(action: { showsExitConfirmation = true }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(.black.opacity(0.4), in: Circle())
                }
                .padding(.leading, 16)
                .padding(.top, 12)
            }
        }
        .confirmationDialog("Keluar dari Level?", isPresented: $showsExitConfirmation, titleVisibility: .visible) {
            Button("Keluar", role: .destructive) { dismiss() }
            Button("Batal", role: .cancel) { }
        } message: {
            Text("Progres kamu di level ini tidak akan disimpan.")
        }
        .animation(.easeInOut, value: viewModel.phase)
        .navigationBarBackButtonHidden(true)
    }

    private var showsTextureThumbControls: Bool {
        viewModel.phase == .exploring && viewModel.hasArrivedAtCurrentCheckpoint
    }
}

// MARK: - UI Components & Overlays

private struct ThumbNavButton: View {
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .bold))
                .frame(width: 96, height: 96)
                .background(isEnabled ? .blue : Color.gray.opacity(0.4), in: Circle())
                .foregroundStyle(.white)
                .shadow(radius: 4, y: 2)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

private struct TriviaDialogOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("🦉")
                .font(.system(size: 64))
            Text(viewModel.currentDialogLine.characterName)
                .font(.headline)
                .foregroundStyle(.blue)
            Text(viewModel.currentDialogLine.text)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Button {
                viewModel.advanceDialog()
            } label: {
                Text(viewModel.isLastDialogLine ? "Ayo Mulai!" : "Lanjut")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue, in: RoundedRectangle(cornerRadius: 18))
                    .foregroundStyle(.white)
            }
        }
        .padding(24)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
}

private struct ScanningSurfaceOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        VStack {
            Text("📱👇 Arahkan iPad pelan-pelan ke lantai beberapa detik ya!")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .padding(.top, 24)

            // Make sure LiDARScanProgressCard is globally accessible in your project
            if viewModel.arSceneViewModel.isLiDARAvailable {
                LiDARScanProgressCard(viewModel: viewModel.arSceneViewModel)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CheckpointExploreOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        VStack(spacing: 14) {
            if viewModel.hasArrivedAtCurrentCheckpoint {
                Text("Checkpoint \(viewModel.currentCheckpointIndex + 1) dari \(viewModel.checkpoints.count) — \(viewModel.currentCheckpoint.shape.displayName)")
                    .font(.subheadline.bold())

                VStack(spacing: 2) {
                    Text("Tekstur: \(viewModel.currentTexture.name)")
                        .font(.title3.bold())
                    Text(viewModel.currentTexture.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if viewModel.hasExploredAllCheckpoints {
                    Button {
                        viewModel.startQuiz()
                    } label: {
                        Text("Mulai Kuis Yuk! 🎉")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green, in: RoundedRectangle(cornerRadius: 18))
                            .foregroundStyle(.white)
                    }
                } else {
                    Text("🔵 Jalan ke lingkaran biru berikutnya untuk checkpoint baru")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text("🔵 Cari lingkaran biru yang berdenyut, lalu jalan masuk ke dalamnya!")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.bottom, 30)
    }
}

private struct QuizOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Kuis \(viewModel.quizIndex + 1) dari \(viewModel.quizQuestions.count)")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            Text(viewModel.currentQuestion.prompt)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(viewModel.currentQuestion.choices) { choice in
                    Button {
                        viewModel.answer(with: choice)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: choice.quizSymbolName)
                                .font(.system(size: 32))
                            Text(choice.displayName)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, minHeight: 84)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.lastAnswerWasCorrect != nil)
                }
            }

            if let isCorrect = viewModel.lastAnswerWasCorrect {
                VStack(spacing: 10) {
                    Text(isCorrect ? "Benar sekali! 🎉" : "Belum tepat, coba ingat-ingat lagi ya 😊")
                        .font(.title3.bold())
                        .foregroundStyle(isCorrect ? .green : .orange)
                    Button("Lanjut") { viewModel.nextQuestion() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.bottom, 30)
    }
}

private struct ReturnToStartOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Skor kamu: \(viewModel.quizScore)/\(viewModel.quizQuestions.count) 🌟")
                .font(.title3.bold())
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.blue)
            Text("Yuk, jalan balik ke \"\(viewModel.checkpoints[0].shape.displayName)\" — checkpoint pertama tadi!")
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.bottom, 40)
    }
}

private struct LevelCompletedOverlay: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("🏆").font(.system(size: 64))
            Text("Level 1 Selesai!")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
            Text("Kamu sudah belajar banyak bentuk dan tekstur baru!")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Kembali ke Menu") { onFinish() }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 24)
        .padding(.bottom, 60)
    }
}
