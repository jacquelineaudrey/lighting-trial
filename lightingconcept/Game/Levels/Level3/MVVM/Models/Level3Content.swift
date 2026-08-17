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
        DialogLine(characterName: "Bayo", text: "Sekarang kita jadi Detektif Bayangan! 🔎🌑", audioFileName: "level-3/1 Hai Penjelajah Kecil! Namaku Bayo.mp3"),
        DialogLine(characterName: "Bayo", text: "Kita akan melihat bagaimana bentuk benda memengaruhi bentuk bayangannya.", audioFileName: "level-3/2 Wah ada banyak titik putih, ayuk kita tekan satu per satu!.mp3"),
        DialogLine(characterName: "Bayo", text: "Jalan pelan di sekitar benda dan amati bayangannya dari beberapa arah.", audioFileName: "level-3/4 Sekarang coba kita lihat di bentuk lain ya!.mp3"),
        DialogLine(characterName: "Bayo", text: "Siap? Yuk mulai!", audioFileName: "level-3/5 Kerenn! Sekarang kamu sudah mengenal berbagai jenis bayangan!.mp3")
    ]

    static let shadowTrivia = [
        DialogLine(characterName: "Bayo", text: "Bayangan terbentuk ketika cahaya terhalang oleh benda.", audioFileName: "level-3/6 Lalu, mengapa bayangan bisa membuat gambar lebih hidup ya_.mp3"),
        DialogLine(characterName: "Bayo", text: "Bayangan berada di sisi benda yang berlawanan dengan sumber cahaya.", audioFileName: "level-3/7 Karena cahaya dan bayangan menciptakan bagian terang dan gelap untuk menunjukkan bentuk benda.mp3"),
        DialogLine(characterName: "Bayo", text: "Saat posisi atau bentuk benda berubah, bentuk dan posisi bayangannya juga bisa berubah.", audioFileName: "level-3/8 Kerja bagus Penjelajah Kecil! Sekarang kamu sudah tau bedanya kan_.mp3")
    ]

    static let shadowTypesTrivia = [
        DialogLine(characterName: "Bayo", text: "Bayangan bisa punya bagian yang sangat gelap dan bagian yang lebih samar.", audioFileName: "level-3/10 Kalau kamu mau lihat jenis bayangan, tekan tombol ini yaa!.mp3"),
        DialogLine(characterName: "Bayo", text: "Bagian paling gelap disebut umbra, sedangkan bagian yang lebih samar disebut penumbra.", audioFileName: "level-3/11 Lalu tekan yang paling atas!.mp3")
    ]

    static let closingDialog = [
        DialogLine(characterName: "Bayo", text: "Hebat! Kamu sudah mengamati bayangan dari banyak sisi.", audioFileName: "level-3/12 Wah, kamu sudah mencoba banyak hal ya! Kerennnnn!.mp3"),
        DialogLine(characterName: "Bayo", text: "Kamu juga sudah melihat bagaimana bentuk benda dan bagian gelap-terang bayangan (umbra & penumbra) saling berhubungan.", audioFileName: "level-3/20 Keren! Gambarmu sudah tersimpan!.mp3")
    ]

    static let reviewPoints = [
        "Bayangan muncul ketika benda menghalangi cahaya.",
        "Bentuk benda yang berbeda dapat menghasilkan bentuk bayangan yang berbeda.",
        "Bagian paling gelap bayangan disebut umbra, bagian yang lebih samar disebut penumbra."
    ]
}
