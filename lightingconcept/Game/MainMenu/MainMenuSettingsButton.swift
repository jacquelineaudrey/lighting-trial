import SwiftUI

struct MainMenuSettingsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            OutlinedText(
                Label("Pengaturan", systemImage: "gearshape.fill"),
                foregroundStyle: .white,
                outlineStyle: MainMenuLayout.outlineColor,
                outlineWidth: MainMenuLayout.settingsOutlineWidth,
                baseFontSize: MainMenuLayout.settingsFontSize
            )
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
