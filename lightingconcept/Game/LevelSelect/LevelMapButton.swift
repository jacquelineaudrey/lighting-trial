//
//  LevelMapButton.swift
//  lightingconcept
//

import SwiftUI

struct LevelMapButton: View {
    let levelID: Int
    let title: String
    let isUnlocked: Bool
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        ZStack {
            Image(LevelMapLayout.artwork(for: levelID, isOpen: usesOpenArtwork))
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: artworkSize.width, height: artworkSize.height)
                .accessibilityHidden(true)

            Button(action: action) {
                Color.clear
                    .frame(width: LevelMapLayout.buttonTouchSize.width,
                           height: LevelMapLayout.buttonTouchSize.height)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(!isUnlocked)
            .accessibilityLabel("Level \(levelID), \(title)")
            .accessibilityValue(accessibilityValue)
            .accessibilityHint(accessibilityHint)
        }
        .frame(width: LevelMapLayout.openArtworkSize.width,
               height: LevelMapLayout.openArtworkSize.height)
    }

    private var usesOpenArtwork: Bool {
        isUnlocked || isCompleted
    }

    private var artworkSize: CGSize {
        usesOpenArtwork ? LevelMapLayout.openArtworkSize : LevelMapLayout.lockedArtworkSize
    }

    private var accessibilityValue: String {
        if isCompleted {
            "Selesai"
        } else if isUnlocked {
            "Terbuka"
        } else {
            "Terkunci"
        }
    }

    private var accessibilityHint: String {
        isUnlocked
            ? "Membuka level \(levelID)."
            : "Selesaikan level sebelumnya untuk membuka level ini."
    }
}
