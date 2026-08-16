//
//  LevelMapBackButton.swift
//  lightingconcept
//

import SwiftUI

struct LevelMapBackButton: View {
    let action: () -> Void

    var body: some View {
        Button("Kembali", systemImage: "chevron.left", action: action)
            .labelStyle(.iconOnly)
            .font(.title2.bold())
            .foregroundStyle(.black)
            .frame(width: 48, height: 48)
            .background(Color(red: 222 / 255, green: 247 / 255, blue: 250 / 255), in: .circle)
            .contentShape(.circle)
            .buttonStyle(.plain)
            .accessibilityHint("Kembali ke halaman utama.")
    }
}
