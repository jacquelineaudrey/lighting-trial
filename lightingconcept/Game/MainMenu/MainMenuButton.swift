//
//  MainMenuButton.swift
//  lightingconcept
//

import SwiftUI

struct MainMenuButton: View {
    let title: String
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(MainMenuButtonStyle(isLocked: isLocked))
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint)
    }

    private var accessibilityLabel: String {
        isLocked ? "\(title), terkunci" : title
    }

    private var accessibilityHint: String {
        if isLocked {
            "Selesaikan semua level belajar untuk membuka simulasi."
        } else if title == "Mulai Belajar" {
            "Membuka pilihan level belajar."
        } else {
            "Membuka halaman simulasi."
        }
    }
}

#Preview {
    MainMenuButton(title: "Mulai Belajar", isLocked: false) {}
        .frame(width: MainMenuLayout.buttonSize.width,
               height: MainMenuLayout.buttonSize.height)
        .background(.brown)
}
