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
        DialogLine(characterName: "Lumi", text: "Halo! Hari ini kita jadi detektif cahaya 🔎💡", audioFileName: "level-2/1 Hiii, hari ini kita main lagi dengan cahaya yuk!.mp3"),
        DialogLine(characterName: "Lumi", text: "Kita akan mencari bayangan, melebarkan cahaya, lalu membuatnya terang dan redup.", audioFileName: "level-2/2 Hmmm, gimana ya kalau cahayanya bisa menyebar_.mp3"),
        DialogLine(characterName: "Lumi", text: "Pegang iPad erat dan jalan pelan. Kalau bisa, minta orang dewasa menemani, ya!", audioFileName: "level-2/13 Tekan sekali di tempat kosong untuk lihat-lihat!.mp3"),
        DialogLine(characterName: "Lumi", text: "Ayo cari meja atau lantai yang kosong untuk menaruh benda cahaya kita.", audioFileName: "level-2/3 Tekan sekali lampunya ya untuk mengatur cahaya.mp3")
    ]

    static let shadowTrivia: [DialogLine] = [
        DialogLine(characterName: "Lumi", text: "Cahaya bergerak menuju benda.", audioFileName: "level-2/8 Ternyata ketika cahaya melebar, bayangan jadi lebih lembut dan pudar ya.mp3"),
        DialogLine(characterName: "Lumi", text: "Saat benda menghalangi cahaya, bagian di belakang benda menjadi gelap.", audioFileName: "level-2/11 Ternyata cahaya yang rapat membuat bayangan jadi lebih tajam dan gelap ya.mp3"),
        DialogLine(characterName: "Lumi", text: "Bagian gelap itu disebut bayangan. Bayangan muncul di sisi yang menjauhi lampu.", audioFileName: "level-2/17 Wah! Cahayanya makin terang, bayangannya makin kelihatan! Tapi, pas cahayanya redup, bayangannya ikut samar! .mp3")
    ]

    static let spreadTransition: [DialogLine] = [
        DialogLine(characterName: "Lumi", text: "Sekarang kita coba mengubah lebar cahaya.", audioFileName: "level-2/4 Tempelkan jempol dan telunjuk ke layar ya.mp3"),
        DialogLine(characterName: "Lumi", text: "Siapkan dua ibu jari. Rapatkan untuk membuat cahaya menyempit, lalu jauhkan untuk membuatnya melebar!", audioFileName: "level-2/5 Lebarkan jari untuk melebarkan cahaya.mp3")
    ]

    static let spreadTrivia: [DialogLine] = [
        DialogLine(characterName: "Lumi", text: "Cahaya yang sempit fokus di area kecil.", audioFileName: "level-2/9 Hmmm, gimana ya kalau cahayanya lebih rapat_.mp3"),
        DialogLine(characterName: "Lumi", text: "Cahaya yang lebar menyinari area yang lebih besar.", audioFileName: "level-2/12 Sekarang, coba kamu yang main sendiri penyebaran cahayanya ya!.mp3"),
        DialogLine(characterName: "Lumi", text: "Lebar cahaya juga disebut sebaran cahaya. Ini berbeda dari terang atau redup, lho!", audioFileName: "level-2/24 Good job! Sekarang kamu tahu, lebar dan terang cahaya bisa mengubah bayangan!.mp3")
    ]

    static let intensityTrivia: [DialogLine] = [
        DialogLine(characterName: "Lumi", text: "Intensitas adalah kuatnya cahaya.", audioFileName: "level-2/14 Sekarang, ayuk kita buat cahayanya menjadi lebih terang!.mp3"),
        DialogLine(characterName: "Lumi", text: "Cahaya yang kuat terlihat lebih terang.", audioFileName: "level-2/16 Naik untuk lebih terang, turun untuk lebih redup.mp3"),
        DialogLine(characterName: "Lumi", text: "Cahaya yang lemah terlihat lebih redup. Lebar cahayanya tidak harus berubah.", audioFileName: "level-2/18 Hebat! Sekarang kamu sudah bisa mengatur cahaya sendiri!.mp3")
    ]

    static let closingDialog: [DialogLine] = [
        DialogLine(characterName: "Lumi", text: "Hebat! Kamu sudah bisa mengamati bayangan dan mengatur cahaya 🌟", audioFileName: "level-2/21 Woah terima kasih udah bantu aku ya!.mp3"),
        DialogLine(characterName: "Lumi", text: "Sebelum selesai, yuk kita ingat tiga penemuan penting hari ini!", audioFileName: "level-2/23 Yeayy, terima kasih udah bantu aku ya! .mp3")
    ]

    static let reviewPoints = [
        "Benda yang menghalangi cahaya menghasilkan bayangan.",
        "Sebaran cahaya menentukan area cahaya yang sempit atau lebar.",
        "Intensitas menentukan cahaya yang terang atau redup."
    ]
}
