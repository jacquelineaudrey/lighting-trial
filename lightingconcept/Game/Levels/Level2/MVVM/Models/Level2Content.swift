import Foundation

enum Level2Content {
    static let levelID = 2
    static let levelTitle = "Bayangan dan Cahaya"

    static let onboardingDialog: [DialogLine] = [
        DialogLine(characterName: "Lumi", text: "Hiii, hari ini kita main lagi dengan cahaya yuk!", audioFileName: "level-2/1 Hiii, hari ini kita main lagi dengan cahaya yuk!.mp3"),
        DialogLine(characterName: "Lumi", text: "Hmmm, gimana ya kalau cahayanya bisa menyebar?", audioFileName: "level-2/2 Hmmm, gimana ya kalau cahayanya bisa menyebar_.mp3")
    ]

    static let shadowTrivia: [DialogLine] = [
        DialogLine(characterName: "Lumi", text: "Tekan sekali lampunya ya untuk mengatur cahaya", audioFileName: "level-2/3 Tekan sekali lampunya ya untuk mengatur cahaya.mp3")
    ]

    static let spreadTransition: [DialogLine] = [
        DialogLine(characterName: "Lumi", text: "Tempelkan jempol dan telunjuk ke layar ya", audioFileName: "level-2/4 Tempelkan jempol dan telunjuk ke layar ya.mp3"),
        DialogLine(characterName: "Lumi", text: "Lebarkan jari untuk melebarkan cahaya", audioFileName: "level-2/5 Lebarkan jari untuk melebarkan cahaya.mp3")
    ]

    static let spreadTrivia: [DialogLine] = [
        DialogLine(characterName: "Lumi", text: "Ternyata ketika cahaya melebar, bayangan jadi lebih lembut dan pudar ya", audioFileName: "level-2/8 Ternyata ketika cahaya melebar, bayangan jadi lebih lembut dan pudar ya.mp3"),
        DialogLine(characterName: "Lumi", text: "Ternyata cahaya yang rapat membuat bayangan jadi lebih tajam dan gelap ya", audioFileName: "level-2/11 Ternyata cahaya yang rapat membuat bayangan jadi lebih tajam dan gelap ya.mp3")
    ]
    
    // Dialog ini dimainkan saat awal masuk ke intensitas exploration
    static let intensityExplorationDialog = DialogLine(characterName: "Lumi", text: "Naik untuk lebih terang, turun untuk lebih redup", audioFileName: "level-2/16 Naik untuk lebih terang, turun untuk lebih redup.mp3")

    static let intensityTrivia: [DialogLine] = [
        DialogLine(characterName: "Lumi", text: "Wah! Cahayanya makin terang, bayangannya makin kelihatan! Tapi, pas cahayanya redup, bayangannya ikut samar!", audioFileName: "level-2/17 Wah! Cahayanya makin terang, bayangannya makin kelihatan! Tapi, pas cahayanya redup, bayangannya ikut samar!.mp3"),
        DialogLine(characterName: "Lumi", text: "Hebat! Sekarang kamu sudah bisa mengatur cahaya sendiri!", audioFileName: "level-2/18 Hebat! Sekarang kamu sudah bisa mengatur cahaya sendiri!.mp3")
    ]

    static let closingDialog: [DialogLine] = [
        DialogLine(characterName: "Lumi", text: "Good job! Sekarang kamu tahu, lebar dan terang cahaya bisa mengubah bayangan!", audioFileName: "level-2/24 Good job! Sekarang kamu tahu, lebar dan terang cahaya bisa mengubah bayangan!.mp3")
    ]

    static let reviewPoints = [
        "Cahaya yang rapat membuat bayangan lebih tajam.",
        "Cahaya yang menyebar membuat bayangan lebih pudar.",
        "Cahaya terang memperjelas bayangan, sedangkan cahaya redup menyamarkannya."
    ]
}
