import SwiftUI

struct AudioSettingsView: View {
    let dismiss: () -> Void

    @State private var menuVolume: Double
    @State private var gameplayVolume: Double

    init(dismiss: @escaping () -> Void) {
        self.dismiss = dismiss

        let musicPlayer = BackgroundMusicPlayer.shared
        _menuVolume = State(initialValue: musicPlayer.menuVolume)
        _gameplayVolume = State(initialValue: musicPlayer.gameplayVolume)
    }

    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 16) {
                Label("Pengaturan", systemImage: "gearshape.fill")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color(red: 92 / 255, green: 61 / 255, blue: 36 / 255))

                Spacer()

                Button("Tutup", systemImage: "xmark", action: dismiss)
                    .labelStyle(.iconOnly)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color(red: 151 / 255, green: 91 / 255, blue: 45 / 255), in: .circle)
                    .contentShape(.circle)
                    .buttonStyle(.plain)
            }

            AudioVolumeControl(
                title: "Volume Menu",
                subtitle: "Musik pada halaman utama dan pemilihan level.",
                systemImage: "music.note",
                volume: $menuVolume
            )

            AudioVolumeControl(
                title: "Volume Dalam Permainan",
                subtitle: "Musik saat bermain agar narasi dan efek suara tetap jelas.",
                systemImage: "gamecontroller.fill",
                volume: $gameplayVolume
            )

            Button("Selesai", action: dismiss)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 42)
                .padding(.vertical, 14)
                .background(Color(red: 151 / 255, green: 91 / 255, blue: 45 / 255), in: .capsule)
                .buttonStyle(.plain)
        }
        .padding(30)
        .frame(maxWidth: 640)
        .background(
            Color(red: 222 / 255, green: 184 / 255, blue: 125 / 255),
            in: .rect(cornerRadius: 32)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 32)
                .stroke(Color(red: 92 / 255, green: 61 / 255, blue: 36 / 255), lineWidth: 5)
        }
        .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
        .padding(32)
        .onChange(of: menuVolume) { _, newVolume in
            BackgroundMusicPlayer.shared.updateMenuVolume(newVolume)
        }
        .onChange(of: gameplayVolume) { _, newVolume in
            BackgroundMusicPlayer.shared.updateGameplayVolume(newVolume)
        }
    }
}

#Preview {
    AudioSettingsView {}
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.45))
}
