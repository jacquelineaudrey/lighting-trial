import Foundation

/// State navigation milik SwiftUI/MVVM; presentasi marker dan shadow tetap
/// berada di ECS/RealityKit.
enum Level3Phase: String, Codable, Equatable {
    case onboarding
    case placingScene
    case surfaceReady
    case shadowExploration
    case shadowTrivia
    case shadowTypesInteraction
    case shapeComparison
    case closing
    case review
    case completed
}

enum Level3Content {
    static let levelID = 3
    static let levelTitle = "Jenis dan Bentuk Bayangan"

    static let onboardingDialog = [
        DialogLine(characterName: "Kiki", text: "Sekarang kita jadi Detektif Bayangan! 🔎🌑"),
        DialogLine(characterName: "Kiki", text: "Kita akan melihat bagaimana bentuk benda memengaruhi bentuk bayangannya."),
        DialogLine(characterName: "Kiki", text: "Jalan pelan di sekitar benda dan amati bayangannya dari beberapa arah."),
        DialogLine(characterName: "Kiki", text: "Siap? Yuk mulai!")
    ]

    static let shadowTrivia = [
        DialogLine(characterName: "Kiki", text: "Bayangan terbentuk ketika cahaya terhalang oleh benda."),
        DialogLine(characterName: "Kiki", text: "Bayangan berada di sisi benda yang berlawanan dengan sumber cahaya."),
        DialogLine(characterName: "Kiki", text: "Saat posisi atau bentuk benda berubah, bentuk dan posisi bayangannya juga bisa berubah.")
    ]

    static let shadowTypesTrivia = [
        DialogLine(characterName: "Kiki", text: "Bayangan bisa punya bagian yang sangat gelap dan bagian yang lebih samar."),
        DialogLine(characterName: "Kiki", text: "Bagian paling gelap disebut umbra, sedangkan bagian yang lebih samar disebut penumbra.")
    ]

    static let closingDialog = [
        DialogLine(characterName: "Kiki", text: "Hebat! Kamu sudah mengamati bayangan dari banyak sisi."),
        DialogLine(characterName: "Kiki", text: "Kamu juga sudah melihat bagaimana bentuk benda dan bagian gelap-terang bayangan (umbra & penumbra) saling berhubungan.")
    ]

    static let reviewPoints = [
        "Bayangan muncul ketika benda menghalangi cahaya.",
        "Bentuk benda yang berbeda dapat menghasilkan bentuk bayangan yang berbeda.",
        "Bagian paling gelap bayangan disebut umbra, bagian yang lebih samar disebut penumbra."
    ]
}
