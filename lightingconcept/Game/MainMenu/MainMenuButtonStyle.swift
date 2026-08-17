//
//  MainMenuButtonStyle.swift
//  lightingconcept
//

import SwiftUI

struct MainMenuButtonStyle: ButtonStyle {
    let isLocked: Bool

    func makeBody(configuration: Configuration) -> some View {
        OutlinedText(
            configuration.label,
            foregroundStyle: isLocked ? MainMenuLayout.lockedTextColor : .white,
            outlineStyle: isLocked ? MainMenuLayout.lockedOutlineColor : MainMenuLayout.outlineColor,
            outlineWidth: MainMenuLayout.outlineWidth
        )
        .opacity(configuration.isPressed ? 0.82 : 1)
        .scaleEffect(configuration.isPressed ? 0.97 : 1)
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
    }
}
