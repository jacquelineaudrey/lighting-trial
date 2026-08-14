//
//  LevelSelectView.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import SwiftUI

/// Grid 6 level Belajar dan rute menuju level yang sudah punya konten.
/// Level 1-4 sudah punya konten & foldering ECS/MVVM sendiri di `Game/Levels/`.
struct LevelSelectView: View {
    @StateObject private var progressStore = GameProgressStore.shared
    @State private var startLevel1 = false
    @State private var startLevel2 = false
    @State private var level2SessionID = UUID()
    @State private var startLevel3 = false
    @State private var level3SessionID = UUID()
//    @State private var startLevel4 = false
    
    private let levelTitles: [Int: String] = [
        1: Level1Content.levelTitle,
        2: Level2Content.levelTitle,
        3: Level3Content.levelTitle,
    //    4: Level4Content.levelTitle
    ]

    /// Level yang boleh diakses dari flow normal. Level 2 dan 3 masih dikunci
    /// dari output normal; aksesnya hanya lewat tombol DEBUG di bawah untuk testing.
    private let levelsWithContent: Set<Int> = [1]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 16) {
                            ForEach(1...progressStore.totalBelajarLevels, id: \.self) { levelID in
                                LevelTile(
                                    levelID: levelID,
                                    title: levelTitles[levelID] ?? "Segera Hadir",
                                    isUnlocked: levelsWithContent.contains(levelID) && progressStore.isLevelUnlocked(levelID),
                                    isCompleted: progressStore.isLevelCompleted(levelID)
                                ) {
                                    switch levelID {
                                    case 1: startLevel1 = true
                                    case 2:
                                        level2SessionID = UUID()
                                        startLevel2 = true
                                    case 3:
                                        level3SessionID = UUID()
                                        startLevel3 = true
            //                      case 4: startLevel4 = true
                                    default: break
                                    }
                                    if levelID == 1 { startLevel1 = true }
            //                      if levelID == 4 { startLevel4 = true }
                                }
                            }
                        }
                        .padding()

                        #if DEBUG
                        VStack(spacing: 8) {
                            Button("🔧 Buka Level 2 langsung (debug)") {
                                level2SessionID = UUID()
                                startLevel2 = true
                            }
                            Button("🔧 Buka Level 3 langsung (debug)") {
                                level3SessionID = UUID()
                                startLevel3 = true
                            }
            //              Button("🔧 Buka Level 4 langsung (debug)") { startLevel4 = true }
                        }
                        .font(.footnote)
                        .padding(.top, 8)
                        // Level 4 baru terbuka lewat urutan normal setelah level 2 & 3 ada.
                        // Sementara itu, tombol ini biar bisa langsung dites tanpa nunggu.
            //          Button("🔧 Buka Level 4 langsung (debug)") { startLevel4 = true }
            //              .font(.footnote)
            //              .padding(.top, 8)
                        #endif // <-- FIXED: Removed the plain text "DEBUG"
                    }
                    .navigationTitle("Pilih Level")
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
            //      .navigationDestination(isPresented: $startLevel4) {
            //          Level4FlowView()
            //      } <-- FIXED: Commented out the closing brace to match the opening brace
                }
            } // Make sure your LevelSelectView struct closes properly before LevelTile begins

        


private struct LevelTile: View {
    let levelID: Int
    let title: String
    let isUnlocked: Bool
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: isCompleted ? "checkmark.seal.fill" : (isUnlocked ? "play.circle.fill" : "lock.fill"))
                    .font(.system(size: 32))
                    .foregroundStyle(isCompleted ? .green : (isUnlocked ? .blue : .gray))
                Text("Level \(levelID)")
                    .font(.headline)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
        .opacity(isUnlocked ? 1 : 0.6)
    }
}

#Preview {
    NavigationStack { LevelSelectView() }
}
