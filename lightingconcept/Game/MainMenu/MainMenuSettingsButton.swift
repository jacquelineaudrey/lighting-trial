import SwiftUI

struct MainMenuSettingsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Pengaturan", systemImage: "gearshape.fill")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .shadow(color: MainMenuLayout.outlineColor, radius: 0, x: 2, y: 2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Membuka pengaturan volume menu dan volume dalam permainan.")
    }
}

#Preview {
    MainMenuSettingsButton {}
        .frame(width: MainMenuLayout.settingsButtonSize.width,
               height: MainMenuLayout.settingsButtonSize.height)
        .background(.brown)
}
