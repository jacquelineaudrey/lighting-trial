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
    @State private var startLevel2 = false
    @State private var level2SessionID = UUID()
    @State private var startLevel3 = false
    @State private var level3SessionID = UUID()

    @StateObject private var cardViewModel = LevelCardViewModel()
    @State private var selectedLevel: Level?

    @StateObject private var lockAlertViewModel = LockAlertViewModel()
    @State private var showLevelLockAlert = false

    private let levelTitles: [Int: String] = [
        1: Level1Content.levelTitle,
        2: Level2Content.levelTitle,
        3: Level3Content.levelTitle,
    ]

    /// Hanya level dengan flow lengkap yang dapat dibuka dari peta.
    private let levelsWithContent: Set<Int> = [1, 2, 3]

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

                    LevelMapBackButton(action: closeLevelSelect)
                        .position(LevelMapLayout.backButtonCenter)
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
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $startLevel1) {
            Level1FlowView(
                onReturnToLevelMenu: { restoreLevelCard(for: 1) },
                onNextLevel: { openNextLevel(after: 1) }
            )
        }
        .navigationDestination(isPresented: $startLevel2) {
            Level2FlowView(
                onReturnToLevelMenu: { restoreLevelCard(for: 2) },
                onNextLevel: { openNextLevel(after: 2) }
            )
                .id(level2SessionID)
        }
        .navigationDestination(isPresented: $startLevel3) {
            Level3FlowView(onReturnToLevelMenu: { restoreLevelCard(for: 3) })
                .id(level3SessionID)
        }
    }

    private func closeLevelSelect() {
        dismiss()
    }

    private func isUnlocked(_ levelID: Int) -> Bool {
        #if DEBUG
        if levelID == 3 {
            return levelsWithContent.contains(levelID)
        }
        #endif

        return levelsWithContent.contains(levelID) && progressStore.isLevelUnlocked(levelID)
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
        switch levelID {
        case 1:
            startLevel1 = true
        case 2:
            level2SessionID = UUID()
            startLevel2 = true
        case 3:
            level3SessionID = UUID()
            startLevel3 = true
        default:
            break
        }
    }

    private func openNextLevel(after completedLevelID: Int) {
        switch completedLevelID {
        case 1:
            startLevel1 = false
            level2SessionID = UUID()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                startLevel2 = true
            }
        case 2:
            startLevel2 = false
            level3SessionID = UUID()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                startLevel3 = true
            }
        case 3:
            startLevel3 = false
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

#Preview {
    NavigationStack {
        LevelSelectView()
    }
}
