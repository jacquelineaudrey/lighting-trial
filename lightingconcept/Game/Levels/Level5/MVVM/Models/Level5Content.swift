//
//  Level5Content.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 28/09/26.
//

import Foundation

enum Level5Phase: String, Equatable {
    case placingScene
    case singleLightIntro
    case twoLightIntro
    case exploration
    case drawingActive
    case photoPrompt
    case photoComparison
    case completed
}

#if DEBUG
enum Level5DevFlow: String, CaseIterable {
    case placingScene = "Scan & Place"
    case singleLightIntro = "One Light Intro"
    case twoLightIntro = "Two Lights Intro"
    case exploration = "Explore Two Lights"
    case drawingActive = "Drawing"
    case photoPrompt = "Photo"
    case photoComparison = "Comparison"
    case completed = "Completed"
}
#endif

enum Level5Content {
    static let levelID = 5

    static let levelTitle =
        "Dua Cahaya, Banyak Bayangan"

    static let placementText =
        "Arahkan titik tengah layar ke meja atau lantai, lalu tekan tombol Taruh Benda di Tengah."

    static let singleLightIntroText =
        "Lihat! Ada satu lampu dan satu bayangan. Tekan tombol untuk menambahkan satu cahaya lagi."

    static let twoLightIntroText =
        "Sekarang ada dua cahaya! Coba lihat, satu benda bisa punya lebih dari satu bayangan."

    static let explorationText =
        "Pilih Lampu 1 atau Lampu 2, lalu geser lampunya untuk melihat perubahan bayangan."

    static let drawingText =
        "Sekarang pilih susunan cahaya yang kamu suka. Perhatikan baik-baik, lalu gambar susunannya di kertasmu."

    static let photoPromptText =
        "Kalau gambar di kertasmu sudah selesai, foto gambarmu ya."

    static let comparisonText =
        "Bandingkan contoh susunan cahaya dengan gambar yang kamu buat."

    static let completionText =
        "Kamu hebat! Kamu sudah melihat bagaimana dua cahaya bisa membentuk banyak bayangan."
}
