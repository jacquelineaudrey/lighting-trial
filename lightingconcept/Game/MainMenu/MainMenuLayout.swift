//
//  MainMenuLayout.swift
//  lightingconcept
//

import SwiftUI

enum MainMenuLayout {
    /// Ukuran dasar aset halaman utama. Seluruh scene diskalakan bersama agar
    /// posisi tombol selalu mengikuti papan pada gambar di setiap ukuran layar.
    static let canvasSize = CGSize(width: 1_210, height: 834)
    static let buttonSize = CGSize(width: 484, height: 150)
    static let learnButtonCenter = CGPoint(x: 605, y: 369)
    static let sandboxButtonCenter = CGPoint(x: 605, y: 529)

    static let outlineWidth: CGFloat = 5
    static let outlineColor = Color(red: 186 / 255, green: 146 / 255, blue: 93 / 255)
    static let lockedTextColor = Color(red: 126 / 255, green: 122 / 255, blue: 114 / 255)
    static let lockedOutlineColor = Color(red: 86 / 255, green: 82 / 255, blue: 75 / 255)

    static func scale(toFill containerSize: CGSize) -> CGFloat {
        max(containerSize.width / canvasSize.width,
            containerSize.height / canvasSize.height)
    }
}
