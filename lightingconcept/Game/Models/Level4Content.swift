import Foundation

// MARK: - Konten Level 4: Posisi Lampu dan Bayangan (light + ground projection)
//
// `DialogLine` dipakai ulang dari Level1Content.swift — sama-sama cuma
// "siapa ngomong apa", tidak spesifik ke Level 1.

enum Level4Content {

    static let levelID = 4
    static let levelTitle = "Posisi Lampu dan Bayangan"

    static let onboardingDialog: [DialogLine] = [
        DialogLine(characterName: "Kiki", text: "Halo lagi! Sekarang kita main dengan cahaya lampu, yuk 💡"),
        DialogLine(characterName: "Kiki", text: "Coba lihat, ada lampu dan sebuah benda di depanmu. Benda itu punya bayangan di tanah."),
        DialogLine(characterName: "Kiki", text: "Tekan dan tahan tombol \"Jadi Lampu\", lalu jalan-jalan untuk memindahkan lampunya!"),
        DialogLine(characterName: "Kiki", text: "Kalau tombolnya kamu lepas, kamu balik lagi jadi penonton yang lihat scene-nya.")
    ]

    /// Dialog transisi setelah anak sempat memindah-mindah lampu/objek sekali,
    /// sebelum masuk ke sesi eksplorasi bebas.
    static let transitionDialog: [DialogLine] = [
        DialogLine(characterName: "Kiki", text: "Keren! Kamu baru saja memindahkan posisi lampu 🎉"),
        DialogLine(characterName: "Kiki", text: "Perhatikan ya — kalau lampu digeser, bayangan di tanah ikut berubah bentuk dan posisinya."),
        DialogLine(characterName: "Kiki", text: "Bayangan itu disebut ground projection — bayangan benda yang jatuh ke tanah karena cahaya lampu."),
        DialogLine(characterName: "Kiki", text: "Sekarang, coba jelajahi sendiri! Pindah-pindahkan lampu atau bendanya, lalu lihat apa yang terjadi pada bayangannya.")
    ]

    static let closingDialog: [DialogLine] = [
        DialogLine(characterName: "Kiki", text: "Wah, kamu sudah jago mengatur posisi lampu dan benda! 🌟"),
        DialogLine(characterName: "Kiki", text: "Sebelum lanjut, yuk kita ingat-ingat lagi apa yang sudah kamu pelajari hari ini.")
    ]

    /// Poin-poin ringkasan pembelajaran (ditampilkan di layar review, bukan
    /// sebagai dialog satu-satu supaya anak bisa baca ulang sesukanya).
    static let learningReviewPoints: [String] = [
        "Lampu yang didekatkan ke benda membuat bayangannya jadi lebih besar.",
        "Lampu yang dijauhkan dari benda membuat bayangannya jadi lebih kecil.",
        "Bayangan selalu jatuh di sisi yang berlawanan dari arah datangnya cahaya.",
        "Bayangan yang jatuh di tanah/lantai disebut ground projection."
    ]

    // Catatan: fase navigasi/waypoint (pilih arah + jalan ke titik hijau) sudah
    // dihapus dari Level 4 — anak langsung bisa menahan tombol "Jadi Lampu"/
    // "Jadi Objek" setelah onboarding, jadi teks prompt-nya juga sudah tidak dipakai.
}
