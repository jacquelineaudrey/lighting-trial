import Foundation

enum Level4Phase: Equatable {
    case placingScene
    case introduction(Int)
    case selectingObject
    case objectMovementTutorial
    case movingObject
    case objectExplanation(Int)
    case lightIntroduction(Int)
    case selectingLight
    case lightMovementTutorial
    case movingLight
    case lightExplanation(Int)
    case exploring
    case closing(Int)
    case review
    case completed
}

struct Level4Dialog: Equatable {
    let text: String
    let assetName: String
}

enum Level4Content {
    static let levelID = 4
    static let levelTitle = "Posisi Objek dan Cahaya"

    static let introduction = [
        Level4Dialog(
            text: "Hai! Hari ini kita bermain dengan cahaya dan bayangan, yuk!",
            assetName: "lumiPointwink"
        ),
        Level4Dialog(
            text: "Garis cokelat menunjukkan jalan cahaya.",
            assetName: "lumiPoint"
        ),
        Level4Dialog(
            text: "Garis putih menunjukkan arah bayangan.",
            assetName: "bayoPoint"
        ),
        Level4Dialog(
            text: "Keduanya bertemu dan membentuk bayangan.",
            assetName: "lumiPoint"
        ),
        Level4Dialog(
            text: "Coba lihat dari sisi kiri dan kanan.",
            assetName: "lumiIdle"
        ),
        Level4Dialog(
            text: "Kalau bendanya digeser, bayangannya bagaimana ya?",
            assetName: "lumiQuestion"
        )
    ]

    static let objectExplanation = [
        Level4Dialog(
            text: "Lihat! Letak benda berubah, bayangannya ikut berubah.",
            assetName: "bayoPoint"
        ),
        Level4Dialog(
            text: "Sekarang lepaskan jarimu dan lihat sekeliling lagi.",
            assetName: "lumiIdle"
        )
    ]

    static let lightIntroduction = [
        Level4Dialog(
            text: "Bagaimana kalau cahayanya kita geser?",
            assetName: "lumiQuestion"
        ),
        Level4Dialog(
            text: "Ayo pilih lampunya dan coba bersama!",
            assetName: "lumiPointwink"
        )
    ]

    static let lightExplanation = [
        Level4Dialog(
            text: "Hore! Saat cahaya berpindah, bayangannya ikut berubah.",
            assetName: "bayoPoint"
        ),
        Level4Dialog(
            text: "Posisi cahaya menentukan arah dan letak bayangan.",
            assetName: "lumiPoint"
        )
    ]

    static let closing = [
        Level4Dialog(
            text: "Keren! Kamu sudah memindahkan benda dan cahaya.",
            assetName: "lumiPointwink"
        ),
        Level4Dialog(
            text: "Sekarang, yuk ingat kembali yang kita temukan!",
            assetName: "lumiIdle"
        )
    ]

    static let reviewPoints = [
        "Benda berpindah, bayangannya ikut berpindah.",
        "Cahaya berpindah, arah bayangan ikut berubah.",
        "Bayangan muncul berlawanan dari arah cahaya."
    ]
}
