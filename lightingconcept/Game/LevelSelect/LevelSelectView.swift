//
//  LevelSelectView.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import SwiftUI

/// Peta 6 level Belajar dan rute menuju level yang sudah punya konten.
struct LevelSelectView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var progressStore = GameProgressStore.shared
    @State private var startLevel1 = false
    @State private var shouldAskLevel1ToSkipIntro = false
    @State private var startLevel2 = false
    @State private var level2SessionID = UUID()
    @State private var shouldAskLevel2ToSkipIntro = false
    @State private var startLevel3 = false
    @State private var level3SessionID = UUID()
    @State private var shouldAskLevel3ToSkipIntro = false
    @State private var startLevel4 = false
    @State private var shouldAskLevel4ToSkipIntro = false
    @State private var startLevel5 = false
    @State private var shouldAskLevel5ToSkipIntro = false
    @State private var startLevel6 = false
    @State private var shouldAskLevel6ToSkipIntro = false

    @StateObject private var cardViewModel = LevelCardViewModel()
    @State private var selectedLevel: Level?

    @StateObject private var lockAlertViewModel = LockAlertViewModel()
    @State private var showLevelLockAlert = false

    private let levelTitles: [Int: String] = [
        1: Level1Content.levelTitle,
        2: Level2Content.levelTitle,
        3: Level3Content.levelTitle,
        4: Level4Content.levelTitle,
        5: Level5Content.levelTitle,
        6: Level6Content.levelTitle,
    ]

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                let scale = LevelMapLayout.scale(toFill: proxy.size)

                ZStack(alignment: .topLeading) {
                    Image(.levelIsland)
                        .resizable()
                        .frame(width: LevelMapLayout.canvasSize.width,
                               height: LevelMapLayout.canvasSize.height)
                        .accessibilityHidden(true)

                    ForEach(1...progressStore.totalBelajarLevels, id: \.self) { levelID in
                        let isLevelOpen = isUnlocked(levelID) || progressStore.isLevelCompleted(levelID)

                        LevelMapButton(
                            levelID: levelID,
                            title: levelTitles[levelID] ?? "Segera Hadir",
                            isUnlocked: isUnlocked(levelID),
                            isCompleted: progressStore.isLevelCompleted(levelID),
                            action: { showCard(for: levelID) }
                        )
                        .position(LevelMapLayout.position(for: levelID, isOpen: isLevelOpen))
                    }
                }
                .frame(width: LevelMapLayout.canvasSize.width,
                       height: LevelMapLayout.canvasSize.height)
                .scaleEffect(scale)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }

            if let selectedLevel {
                LevelSelectDimmingBackdrop(action: dismissSelectedLevel)

                LevelCardView(level: selectedLevel, onBack: dismissSelectedLevel) {
                    let levelID = selectedLevel.id
                    dismissSelectedLevel()
                    openLevel(levelID)
                }
                .transition(.scale.combined(with: .opacity))
            }

            if showLevelLockAlert {
                LevelSelectDimmingBackdrop(action: dismissLockAlert)

                LockAlertView(data: lockAlertViewModel.alerts[1]) {
                    dismissLockAlert()
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) {
            LevelMapBackButton(action: closeLevelSelect)
                .padding(.leading, 16)
                .padding(.top, 12)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $startLevel1) {
            Level1FlowView(
                shouldAskToSkipIntro: shouldAskLevel1ToSkipIntro,
                onReturnToLevelMenu: { restoreLevelCard(for: 1) },
                onNextLevel: { openNextLevel(after: 1) }
            )
        }
        .navigationDestination(isPresented: $startLevel2) {
            Level2FlowView(
                shouldAskToSkipIntro: shouldAskLevel2ToSkipIntro,
                onReturnToLevelMenu: { restoreLevelCard(for: 2) },
                onNextLevel: { openNextLevel(after: 2) }
            )
                .id(level2SessionID)
        }
        .navigationDestination(isPresented: $startLevel3) {
            Level3FlowView(
                shouldAskToSkipIntro: shouldAskLevel3ToSkipIntro,
                onReturnToLevelMenu: { restoreLevelCard(for: 3) },
                onNextLevel: { openNextLevel(after: 3) }
            )
                .id(level3SessionID)
        }
        .navigationDestination(isPresented: $startLevel4) {
            Level4FlowView(
                shouldAskToSkipIntro: shouldAskLevel4ToSkipIntro,
                onReturnToLevelMenu: { restoreLevelCard(for: 4) },
                onNextLevel: { openNextLevel(after: 4) }
            )
        }
        .navigationDestination(isPresented: $startLevel5) {
            Level5FlowView(
                shouldAskToSkipIntro: shouldAskLevel5ToSkipIntro,
                onReturnToLevelMenu: { restoreLevelCard(for: 5) },
                onNextLevel: { openNextLevel(after: 5) }
            )
        }
        .navigationDestination(isPresented: $startLevel6) {
            Level6FlowView(
                shouldAskToSkipIntro: shouldAskLevel6ToSkipIntro,
                onReturnToLevelMenu: { restoreLevelCard(for: 6) },
                onFinish: { openNextLevel(after: 6) }
            )
        }
    }

    private func closeLevelSelect() {
        dismiss()
    }

    private func isUnlocked(_ levelID: Int) -> Bool {
        progressStore.isLevelUnlocked(levelID)
    }

    private func dismissSelectedLevel() {
        selectedLevel = nil
    }

    private func dismissLockAlert() {
        showLevelLockAlert = false
    }

    private func showCard(for levelID: Int) {
        guard isUnlocked(levelID) else {
            withAnimation(.easeInOut(duration: 0.2)) {
                showLevelLockAlert = true
            }
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedLevel = cardViewModel.levels.first { $0.id == levelID }
        }
    }

    private func restoreLevelCard(for levelID: Int) {
        selectedLevel = cardViewModel.levels.first { $0.id == levelID }
    }

    private func openLevel(_ levelID: Int) {
        guard isUnlocked(levelID) else { return }

        switch levelID {
        case 1:
            shouldAskLevel1ToSkipIntro = progressStore.isLevelCompleted(1)
            startLevel1 = true
        case 2:
            shouldAskLevel2ToSkipIntro = progressStore.isLevelCompleted(2)
            level2SessionID = UUID()
            startLevel2 = true
        case 3:
            shouldAskLevel3ToSkipIntro = progressStore.isLevelCompleted(3)
            level3SessionID = UUID()
            startLevel3 = true
        case 4:
            shouldAskLevel4ToSkipIntro = progressStore.isLevelCompleted(4)
            startLevel4 = true
        case 5:
            shouldAskLevel5ToSkipIntro = progressStore.isLevelCompleted(5)
            startLevel5 = true
        case 6:
            shouldAskLevel6ToSkipIntro = progressStore.isLevelCompleted(6)
            startLevel6 = true
        default:
            break
        }
    }

    private func openNextLevel(after completedLevelID: Int) {
        guard progressStore.isLevelCompleted(completedLevelID) else { return }

        switch completedLevelID {
        case 1:
            guard progressStore.isLevelUnlocked(2) else { return }
            startLevel1 = false
            level2SessionID = UUID()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                shouldAskLevel2ToSkipIntro = progressStore.isLevelCompleted(2)
                startLevel2 = true
            }
        case 2:
            guard progressStore.isLevelUnlocked(3) else { return }
            startLevel2 = false
            level3SessionID = UUID()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                shouldAskLevel3ToSkipIntro = progressStore.isLevelCompleted(3)
                startLevel3 = true
            }
        case 3:
            guard progressStore.isLevelUnlocked(4) else { return }
            startLevel3 = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                shouldAskLevel4ToSkipIntro = progressStore.isLevelCompleted(4)
                startLevel4 = true
            }
        case 4:
            guard progressStore.isLevelUnlocked(5) else { return }
            startLevel4 = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                shouldAskLevel5ToSkipIntro = progressStore.isLevelCompleted(5)
                startLevel5 = true
            }
        case 5:
            guard progressStore.isLevelUnlocked(6) else { return }
            startLevel5 = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                shouldAskLevel6ToSkipIntro = progressStore.isLevelCompleted(6)
                startLevel6 = true
            }
        case 6:
            startLevel6 = false
        default:
            break
        }
    }
}

private struct LevelSelectDimmingBackdrop: View {
    let action: () -> Void

    var body: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .transaction { transaction in
                transaction.animation = nil
            }
            .onTapGesture(perform: action)
    }
}

#Preview(traits: .landscapeLeft) {
    NavigationStack {
        LevelSelectView()
    }
}
