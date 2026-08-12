import SwiftUI

/// Grid 6 level Belajar dan rute menuju level yang sudah punya konten.
struct LevelSelectView: View {
    @ObservedObject private var progressStore = GameProgressStore.shared
    @State private var startLevel1 = false
    @State private var startLevel2 = false
    @State private var startLevel4 = false

    private let levelTitles: [Int: String] = [
        1: Level1Content.levelTitle,
        2: Level2Content.levelTitle,
        4: Level4Content.levelTitle
    ]

    /// Level yang sudah punya konten sekarang. Tambahkan ID level lain di sini
    /// setelah flow dan kontennya siap dimainkan.
    private let levelsWithContent: Set<Int> = [1, 2, 4]

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
                        if levelID == 1 { startLevel1 = true }
                        if levelID == 2 { startLevel2 = true }
                        if levelID == 4 { startLevel4 = true }
                    }
                }
            }
            .padding()

            #if DEBUG
            VStack(spacing: 8) {
                Button("🔧 Buka Level 2 langsung (debug)") { startLevel2 = true }
                Button("🔧 Buka Level 4 langsung (debug)") { startLevel4 = true }
            }
            .font(.footnote)
            .padding(.top, 8)
            #endif
        }
        .navigationTitle("Pilih Level")
        .navigationDestination(isPresented: $startLevel1) {
            Level1FlowView()
        }
        .navigationDestination(isPresented: $startLevel2) {
            Level2FlowView()
        }
        .navigationDestination(isPresented: $startLevel4) {
            Level4FlowView()
        }
    }
}

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
