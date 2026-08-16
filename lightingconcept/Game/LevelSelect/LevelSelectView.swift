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

    private let levelTitles: [Int: String] = [
        1: Level1Content.levelTitle,
        2: Level2Content.levelTitle,
        3: Level3Content.levelTitle,
    ]

    /// Hanya level dengan flow lengkap yang dapat dibuka dari peta.
    private let levelsWithContent: Set<Int> = [1, 2, 3]

    var body: some View {
        GeometryReader { proxy in
            let scale = LevelMapLayout.scale(toFill: proxy.size)

            ZStack(alignment: .topLeading) {
                Image(.levelIsland)
                    .resizable()
                    .frame(width: LevelMapLayout.canvasSize.width,
                           height: LevelMapLayout.canvasSize.height)
                    .accessibilityHidden(true)

                ForEach(1...progressStore.totalBelajarLevels, id: \.self) { levelID in
                    LevelMapButton(
                        levelID: levelID,
                        title: levelTitles[levelID] ?? "Segera Hadir",
                        isUnlocked: levelsWithContent.contains(levelID)
                            && progressStore.isLevelUnlocked(levelID),
                        isCompleted: progressStore.isLevelCompleted(levelID),
                        action: { openLevel(levelID) }
                    )
                    .position(LevelMapLayout.position(for: levelID))
                }

                LevelMapBackButton(action: closeLevelSelect)
                    .position(LevelMapLayout.backButtonCenter)
            }
            .frame(width: LevelMapLayout.canvasSize.width,
                   height: LevelMapLayout.canvasSize.height)
            .scaleEffect(scale)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $startLevel1) {
            Level1FlowView()
        }
        .navigationDestination(isPresented: $startLevel2) {
            Level2FlowView()
                .id(level2SessionID)
        }
        .navigationDestination(isPresented: $startLevel3) {
            Level3FlowView()
                .id(level3SessionID)
        }
    }

    private func closeLevelSelect() {
        dismiss()
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
}

#Preview {
    NavigationStack {
        LevelSelectView()
    }
}
