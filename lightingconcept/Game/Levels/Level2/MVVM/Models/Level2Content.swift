import Foundation

/// State navigation milik SwiftUI/MVVM; tidak memegang entity RealityKit.
enum Level2Phase: String, Equatable {
    case onboarding
    case placingScene
    case surfaceReady
    case shadowExploration
    case shadowTrivia
    case spreadTransition
    case spreadExploration
    case spreadTrivia
    case intensityExploration
    case intensityTrivia
    case closing
    case review
    case completed
}

enum Level2Content {
    static let levelID = 2
    static let levelTitle = "Bayangan dan Cahaya"

    static let onboardingDialog: [DialogLine] = [
        DialogLine(characterName: "Kiki", text: "Halo! Hari ini kita jadi detektif cahaya 🔎💡"),
        DialogLine(characterName: "Kiki", text: "Kita akan mencari bayangan, melebarkan cahaya, lalu membuatnya terang dan redup."),
        DialogLine(characterName: "Kiki", text: "Pegang iPad erat dan jalan pelan. Kalau bisa, minta orang dewasa menemani, ya!"),
        DialogLine(characterName: "Kiki", text: "Ayo cari meja atau lantai yang kosong untuk menaruh benda cahaya kita.")
    ]

    static let shadowTrivia: [DialogLine] = [
        DialogLine(characterName: "Kiki", text: "Cahaya bergerak menuju benda."),
        DialogLine(characterName: "Kiki", text: "Saat benda menghalangi cahaya, bagian di belakang benda menjadi gelap."),
        DialogLine(characterName: "Kiki", text: "Bagian gelap itu disebut bayangan. Bayangan muncul di sisi yang menjauhi lampu.")
    ]

    static let spreadTransition: [DialogLine] = [
        DialogLine(characterName: "Kiki", text: "Sekarang kita coba mengubah lebar cahaya."),
        DialogLine(characterName: "Kiki", text: "Siapkan dua ibu jari. Rapatkan untuk membuat cahaya menyempit, lalu jauhkan untuk membuatnya melebar!")
    ]

    static let spreadTrivia: [DialogLine] = [
        DialogLine(characterName: "Kiki", text: "Cahaya yang sempit fokus di area kecil."),
        DialogLine(characterName: "Kiki", text: "Cahaya yang lebar menyinari area yang lebih besar."),
        DialogLine(characterName: "Kiki", text: "Lebar cahaya juga disebut sebaran cahaya. Ini berbeda dari terang atau redup, lho!")
    ]

    static let intensityTrivia: [DialogLine] = [
        DialogLine(characterName: "Kiki", text: "Intensitas adalah kuatnya cahaya."),
        DialogLine(characterName: "Kiki", text: "Cahaya yang kuat terlihat lebih terang."),
        DialogLine(characterName: "Kiki", text: "Cahaya yang lemah terlihat lebih redup. Lebar cahayanya tidak harus berubah.")
    ]

    static let closingDialog: [DialogLine] = [
        DialogLine(characterName: "Kiki", text: "Hebat! Kamu sudah bisa mengamati bayangan dan mengatur cahaya 🌟"),
        DialogLine(characterName: "Kiki", text: "Sebelum selesai, yuk kita ingat tiga penemuan penting hari ini!")
    ]

    static let reviewPoints = [
        "Benda yang menghalangi cahaya menghasilkan bayangan.",
        "Sebaran cahaya menentukan area cahaya yang sempit atau lebar.",
        "Intensitas menentukan cahaya yang terang atau redup."
    ]
}
