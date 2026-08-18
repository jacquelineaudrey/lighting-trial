import Foundation

enum Level3Content {
    static let levelID = 3
    static let levelTitle = "Jenis dan Bentuk Bayangan"

    static let onboardingDialog = [
        DialogLine(characterName: "Bayo", text: "Hai Penjelajah Kecil! Namaku Bayo", audioFileName: "level-3/marker/1 Hai Penjelajah Kecil! Namaku Bayo.mp3"),
        DialogLine(characterName: "Bayo", text: "Wah ada banyak titik putih, ayuk kita tekan satu per satu!", audioFileName: "level-3/marker/2 Wah ada banyak titik putih, ayuk kita tekan satu per satu!.mp3")
    ]

    static let shadowTrivia = [
        DialogLine(characterName: "Bayo", text: "Keren! Kamu sudah belajar jenis bayangan!", audioFileName: "level-3/marker/3 Keren! Kamu sudah belajar jenis bayangan!.mp3"),
        DialogLine(characterName: "Bayo", text: "Sekarang coba kita lihat di bentuk lain ya!", audioFileName: "level-3/marker/4 Sekarang coba kita lihat di bentuk lain ya!.mp3")
    ]

    static let shadowTypesTrivia = [
        DialogLine(characterName: "Bayo", text: "Kerenn! Sekarang kamu sudah mengenal berbagai jenis bayangan!", audioFileName: "level-3/marker/5 Kerenn! Sekarang kamu sudah mengenal berbagai jenis bayangan!.mp3"),
        DialogLine(characterName: "Bayo", text: "Lalu, mengapa bayangan bisa membuat gambar lebih hidup ya?", audioFileName: "level-3/marker/6 Lalu, mengapa bayangan bisa membuat gambar lebih hidup ya_.mp3"),
        DialogLine(characterName: "Bayo", text: "Karena cahaya dan bayangan menciptakan bagian terang dan gelap untuk menunjukkan bentuk benda", audioFileName: "level-3/marker/7 Karena cahaya dan bayangan menciptakan bagian terang dan gelap untuk menunjukkan bentuk benda.mp3")
    ]

    static let closingDialog = [
        DialogLine(characterName: "Bayo", text: "Kerja bagus Penjelajah Kecil! Sekarang kamu sudah tau bedanya kan?", audioFileName: "level-3/marker/8 Kerja bagus Penjelajah Kecil! Sekarang kamu sudah tau bedanya kan_.mp3"),
        DialogLine(characterName: "Bayo", text: "Nahh, sekarang coba ingat-ingat lagi apa yang udah dipelajari. Kita coba lagi yuk!", audioFileName: "level-3/marker/9 Nahh, sekarang coba ingat-ingat lagi apa yang udah dipelajari. Kita coba lagi yuk!.mp3")
    ]

    static let reviewPoints = [
        "Bayangan muncul ketika benda menghalangi cahaya.",
        "Bentuk benda yang berbeda dapat menghasilkan bentuk bayangan yang berbeda.",
        "Bagian paling gelap bayangan disebut umbra, bagian yang lebih samar disebut penumbra."
    ]
}
