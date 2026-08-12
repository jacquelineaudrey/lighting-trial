import SwiftUI

/// Layar pembuka: pilih "Belajar" atau "Sandbox".
/// Sandbox terkunci sampai semua level Belajar selesai (lihat `GameProgressStore`).
struct MainMenuView: View {
    @ObservedObject private var progressStore = GameProgressStore.shared
    @State private var showLevelSelect = false
    @State private var showSandbox = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Text("🔺🔵🟩")
                    .font(.system(size: 56))
                Text("Ayo Main!")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))

                VStack(spacing: 16) {
                    MenuButton(
                        title: "Belajar",
                        subtitle: "Jelajahi bentuk & tekstur",
                        systemImage: "book.fill",
                        tint: .blue,
                        isLocked: false
                    ) {
                        showLevelSelect = true
                    }

                    MenuButton(
                        title: "Sandbox",
                        subtitle: progressStore.isSandboxUnlocked
                            ? "Main bebas dengan semua bentuk"
                            : "Selesaikan semua level Belajar dulu, yuk!",
                        systemImage: "shippingbox.fill",
                        tint: .orange,
                        isLocked: !progressStore.isSandboxUnlocked
                    ) {
                        showSandbox = true
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
            .navigationDestination(isPresented: $showLevelSelect) {
                LevelSelectView()
            }
            .navigationDestination(isPresented: $showSandbox) {
                // Placeholder — sandbox belum dibangun, cukup pastikan gate-nya benar dulu.
                Text("Sandbox — segera hadir")
                    .font(.title2.bold())
            }
        }
    }
}

private struct MenuButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button {
            if !isLocked { action() }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: isLocked ? "lock.fill" : systemImage)
                    .font(.system(size: 28))
                    .frame(width: 52, height: 52)
                    .background(isLocked ? Color.gray.opacity(0.3) : tint.opacity(0.15))
                    .foregroundStyle(isLocked ? .gray : tint)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(isLocked ? .gray : .primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .opacity(isLocked ? 0.7 : 1)
    }
}

#Preview {
    MainMenuView()
}
