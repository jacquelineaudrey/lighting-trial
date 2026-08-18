import Foundation

/// State navigation milik SwiftUI/MVVM; tidak memegang entity RealityKit.
enum Level2Phase: String, Equatable {
    case onboarding
    case placingScene
    case surfaceReady
    case spreadTutorial
    case spreadFreeIntro
    case spreadFreeInstructions
    case spreadFreeExploration
    case intensityTransition
    case intensityTutorial
    case mission
    case closing
    case review
    case completed
}

enum Level2Content {
    static let levelID = 2
    static let levelTitle = "Bayangan dan Cahaya"

    static let onboardingDialog: [Level2OverlayLine] = [
        Level2OverlayLine(text: "Hiii, hari ini kita main lagi\ndengan cahaya yuk!", mascot: .pointWink, bubble: .lowerTrailing, audioFileName: "level-2/1 Hiii, hari ini kita main lagi dengan cahaya yuk!.mp3"),
        Level2OverlayLine(text: "Hmmm, gimana ya\nkalau cahayanya bisa\nmenyebar?", mascot: .question, bubble: .upperTrailing, audioFileName: "level-2/2 Hmmm, gimana ya kalau cahayanya bisa menyebar_.mp3"),
        Level2OverlayLine(text: "Tekan sekali\nlampunya ya untuk\nmengatur cahaya", mascot: .pointWink, bubble: .upperTrailing, audioFileName: "level-2/3 Tekan sekali lampunya ya untuk mengatur cahaya.mp3")
    ]

    static let spreadTutorial: [Level2TutorialStep] = [
        Level2TutorialStep(text: "Tempelkan jempol dan telunjuk ke layar ya", gesture: .touchTwoFingers, audioFileName: "level-2/4 Tempelkan jempol dan telunjuk ke layar ya.mp3"),
        Level2TutorialStep(text: "Lebarkan jari untuk melebarkan cahaya", gesture: .spreadOut, audioFileName: "level-2/5 Lebarkan jari untuk melebarkan cahaya.mp3"),
        Level2TutorialStep(text: "Bagus! Rapatkan dua jari untuk mengecilkan cahaya", gesture: .pinchIn, audioFileName: "level-2/6 Bagus! Rapatkan dua jari untuk mengecilkan cahaya.mp3"),
        Level2TutorialStep(text: "Lebarkan jari lagi untuk melebarkan cahaya", gesture: .spreadOut, audioFileName: "level-2/7 Lebarkan jari lagi untuk melebarkan cahaya.mp3"),
        Level2TutorialStep(text: "Ternyata ketika cahaya\nmelebar, bayangan jadi lebih\nlembut dan pudar ya", mascot: .question, bubble: .lowerTrailing, highlightedWords: ["melebar", "lembut dan pudar"], audioFileName: "level-2/8 Ternyata ketika cahaya melebar, bayangan jadi lebih lembut dan pudar ya.mp3"),
        Level2TutorialStep(text: "Hmmm, gimana ya\nkalau cahayanya\nlebih rapat?", mascot: .question, bubble: .upperTrailing, audioFileName: "level-2/9 Hmmm, gimana ya kalau cahayanya lebih rapat_.mp3"),
        Level2TutorialStep(text: "Rapatkan dua jari untuk mengecilkan cahaya", gesture: .pinchIn, audioFileName: "level-2/10 Rapatkan dua jari untuk mengecilkan cahaya.mp3"),
        Level2TutorialStep(text: "Ternyata cahaya yang rapat\nmembuat bayangan jadi lebih\ntajam dan gelap ya", mascot: .question, bubble: .lowerTrailing, highlightedWords: ["rapat", "tajam dan gelap"], audioFileName: "level-2/11 Ternyata cahaya yang rapat membuat bayangan jadi lebih tajam dan gelap ya.mp3")
    ]

    static let spreadFreeIntro = Level2OverlayLine(
        text: "Sekarang, coba kamu yang\nmain sendiri penyebaran\ncahayanya ya!",
        mascot: .idle,
        bubble: .upperCenter,
        highlightedWords: [],
        audioFileName: "level-2/12 Sekarang, coba kamu yang main sendiri penyebaran cahayanya ya!.mp3"
    )

    static let spreadFreeExplorationAudioFileName = "level-2/13 Tekan sekali di tempat kosong untuk lihat-lihat!.mp3"
    static let placementAudioFileName = "level-2/Arahkan titik tengah layar ke meja atau lantai. lalu tekan tombol dibawah.mp3"
    static let genericGestureAudioFileName = "level-2/Ikuti gerakan jari di layar.mp3"
    static let spreadReminderAudioFileNames = [
        "level-2/Rapatkan dua jari untuk mengecilkan cahaya.mp3",
        "level-2/Lebarkan dua jari untuk melebarkan cahaya.mp3"
    ]
    static let verticalSlideAudioFileName = "level-2/Geser jarimu naik dan turun di sebelah kiri layar.mp3"
    static let completedAudioFileName = "level-2/Level 2 selesai. Kamu hebat! Sekarang kamu bisa ke level berikutnya!.mp3"

    static let intensityTransition = Level2OverlayLine(
        text: "Sekarang, ayuk kita\nbuat cahayanya\nmenjadi lebih terang!✨",
        mascot: .pointWink,
        bubble: .upperCenter,
        highlightedWords: [],
        audioFileName: "level-2/14 Sekarang, ayuk kita buat cahayanya menjadi lebih terang!.mp3"
    )

    static let intensityTutorial: [Level2TutorialStep] = [
        Level2TutorialStep(text: "Ingat tekan sekali\nlampunya untuk\nmengatur cahaya!", mascot: .pointWink, bubble: .upperTrailing, audioFileName: "level-2/15 Ingat tekan sekali lampunya untuk mengatur cahaya!.mp3"),
        Level2TutorialStep(text: nil, gesture: .verticalSlide),
        Level2TutorialStep(text: "Geser jarimu di sebelah kiri layar!\nNaik untuk lebih terang, turun untuk lebih redup.", gesture: .brightnessSlider, audioFileName: "level-2/16 Naik untuk lebih terang, turun untuk lebih redup.mp3"),
        Level2TutorialStep(text: "Wah! Cahayanya makin terang, bayangannya makin kelihatan!\nTapi, pas cahayanya redup, bayangannya ikut samar!", mascot: .question, bubble: .wideLower, highlightedWords: ["terang", "kelihatan", "redup", "samar"], audioFileName: "level-2/17 Wah! Cahayanya makin terang, bayangannya makin kelihatan! Tapi, pas cahayanya redup, bayangannya ikut samar! .mp3"),
        Level2TutorialStep(text: "Hebat! Sekarang kamu\nsudah bisa mengatur\ncahaya sendiri! 🌟", mascot: .idle, bubble: .upperCenter, audioFileName: "level-2/18 Hebat! Sekarang kamu sudah bisa mengatur cahaya sendiri!.mp3")
    ]

    static let mission: [Level2OverlayLine] = [
        Level2OverlayLine(text: "Sebelum selesai, yuk main\nsebentar sama Lumi!", mascot: .idle, bubble: .upperCenter, audioFileName: "level-2/19 Sebelum selesai, yuk main sebentar sama Lumi!.mp3"),
        Level2OverlayLine(text: "Cahaya yang lebar dan\nterang itu gimana ya?\nBantuin Lumi dong!", mascot: .question, bubble: .upperTrailing, highlightedWords: ["lebar dan", "terang"], audioFileName: "level-2/20 Cahaya yang lebar dan terang itu gimana ya_ Bantuin Lumi dong!.mp3"),
        Level2OverlayLine(text: "Woah terima kasih udah\nbantu aku ya!", mascot: .pointWink, bubble: .lowerTrailing, audioFileName: "level-2/21 Woah terima kasih udah bantu aku ya!.mp3"),
        Level2OverlayLine(text: "Sekarang aku penasaran\ncahaya yang sempit dan\nredup itu gimana ya?", mascot: .question, bubble: .upperTrailing, highlightedWords: ["sempit dan", "redup"], audioFileName: "level-2/22 Sekarang aku penasaran cahaya yang sempit dan redup itu gimana ya_.mp3"),
        Level2OverlayLine(text: "Yeayy, terima kasih udah\nbantu aku ya!", mascot: .pointWink, bubble: .lowerTrailing, audioFileName: "level-2/23 Yeayy, terima kasih udah bantu aku ya! .mp3"),
        Level2OverlayLine(text: "Good job! Sekarang kamu tahu,\nlebar dan terang cahaya bisa\nmengubah bayangan!", mascot: .idle, bubble: .lowerLeading, highlightedWords: ["lebar dan terang", "bayangan"], audioFileName: "level-2/24 Good job! Sekarang kamu tahu, lebar dan terang cahaya bisa mengubah bayangan!.mp3")
    ]

    static let closingDialog: [DialogLine] = [
        DialogLine(characterName: "Lumi", text: "Hebat! Kamu sudah bisa mengatur cahaya dan melihat perubahan bayangan 🌟"),
        DialogLine(characterName: "Lumi", text: "Sebelum lanjut, yuk kita ingat tiga penemuan penting hari ini!")
    ]

    static let reviewPoints = [
        "Cahaya yang melebar membuat bayangan lebih lembut dan pudar.",
        "Cahaya yang rapat membuat bayangan lebih tajam dan gelap.",
        "Intensitas menentukan cahaya yang terang atau redup."
    ]
}

struct Level2OverlayLine: Equatable {
    let text: String
    var mascot: Level2MascotPose = .idle
    var bubble: Level2BubblePlacement = .lowerTrailing
    var highlightedWords: [String] = []
    var audioFileName: String?
}

struct Level2TutorialStep: Equatable {
    let text: String?
    var gesture: Level2GesturePrompt?
    var mascot: Level2MascotPose?
    var bubble: Level2BubblePlacement = .lowerTrailing
    var highlightedWords: [String] = []
    var audioFileName: String?
}

enum Level2MascotPose: Equatable {
    case idle
    case point
    case pointWink
    case question

    var assetName: String {
        switch self {
        case .idle: "lumiIdle"
        case .point: "lumiPoint"
        case .pointWink: "lumiPointwink"
        case .question: "lumiQuestion"
        }
    }
}

enum Level2BubblePlacement: Equatable {
    case lowerTrailing
    case upperTrailing
    case upperCenter
    case lowerLeading
    case wideLower
}

enum Level2GesturePrompt: Equatable {
    case touchTwoFingers
    case spreadOut
    case pinchIn
    case verticalSlide
    case brightnessSlider
}
