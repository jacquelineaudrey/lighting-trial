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

    static let singleLightDialogs = [
        "Haloo, kali ini Lumi dan Bayo mau ajak kamu mencoba hal baru yang seruu!!",
        "Kalau kamu lihat, di sana ada 1 lampu. Gimana ya kalau ada 2 lampu? Bayangannya bakal nambah?",
        "Nah, sekarang tekan tombol ini untuk menambah lampu."
    ]

    static let twoLightDialogs = [
        "Wahh, ternyata muncul bayangan baru!",
        "Semakin banyak lampunya, bayangannya juga ikut bertambah! Ajaib kannn 😆"
    ]

    static let explorationDialogs = [
        "Sekarang, ayuk kita ubah-ubah posisi kedua cahayanya ya. Apakah bayangannya berubah?",
        "Pilih cahaya yang mau kamu ubah yuk!",
        "Ingat, ditekan sekali dulu ya untuk pilih lampu.",
        "Tahan lampunya, lalu gerakkan perangkatmu untuk mengubah posisinya.",
        "Tekan sekali di tempat kosong untuk lihat-lihat!",
        "Yuk, coba jalan ke kiri dan kanan! Lihat bayangannya dari arah lain.",
        "Wah, kamu sudah mencoba banyak cahaya dan bayangan! Sekarang, pilih yang mau kamu gambar!",
        "Atur sampai kamu suka. Kalau sudah, tekan tombol ini ya!"
    ]

    static let drawingDialogs = [
        "Sekarang, mari kita menggambar!",
        "Lihat baik-baik cahaya dan bayangannya!",
        "Sekarang coba gambar di kertasmu!",
        "Kalau sudah, tekan tombol ini ya!"
    ]

    static let placementText =
        "Arahkan titik tengah layar ke meja atau lantai, lalu tekan tombol Taruh Benda di Tengah."

    static let singleLightIntroText = singleLightDialogs[0]

    static let twoLightIntroText = twoLightDialogs[0]

    static let explorationText = explorationDialogs[0]

    static let drawingText = drawingDialogs[0]

    static let photoPromptText =
        "Yeay, gambarmu sudah jadi! Sekarang, yuk foto gambarmu!"

    static let comparisonText =
        "Keren! Gambarmu sudah tersimpan!"

    static let completionText =
        "Kamu hebat! Kamu sudah melihat bagaimana dua cahaya bisa membentuk banyak bayangan."
}
