//
//  Level1Content.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import Foundation

// MARK: - Model dasar
//
// Bentuknya dipetakan ke `LearningObjectType` dan teksturnya ke `MaterialTexture`
// (dua-duanya sudah ada di project ini) supaya checkpoint AR bisa langsung
// dirender oleh `SceneObjectSystem` tanpa
// perlu mesh/material baru.

/// Satu varian tekstur untuk sebuah bentuk, dengan label & deskripsi Bahasa
/// Indonesia untuk anak-anak di atas `MaterialTexture` asli.
struct TextureStop: Identifiable, Hashable {
    let material: MaterialTexture
    let name: String          // ditampilkan ke anak, contoh: "Kasar"
    let description: String   // kalimat pendek untuk dialog/trivia

    var id: String { material.id }
}

/// Satu bentuk (shape family) yang ditemui di sebuah checkpoint.
struct GameShape: Identifiable, Hashable {
    let id: String
    let displayName: String        // "Kubus", "Bola", dst.
    let objectType: LearningObjectType
    let quizSymbolName: String     // ikon SF Symbol untuk kartu pilihan di quiz overlay
    let textures: [TextureStop]
}

/// Satu titik pemberhentian di sepanjang jalur eksplorasi AR.
struct Checkpoint: Identifiable, Hashable {
    let id: String
    let order: Int           // urutan 0-based di sepanjang jalur jalan kaki
    let shape: GameShape
}

/// Satu baris dialog karakter pemandu (dipakai di trivia onboarding).
struct DialogLine: Identifiable, Hashable {
    let id = UUID()
    let characterName: String
    let text: String
}

/// Satu soal trivia bergambar (multiple choice, pilihan berupa bentuk).
struct TriviaQuestion: Identifiable, Hashable {
    let id: String
    let prompt: String
    let choices: [GameShape]     // biasanya 4 pilihan bentuk
    let correctShapeID: String
}

// MARK: - Konten Level 1: Bentuk dan Tekstur

enum Level1Content {

    static let levelID = 1
    static let levelTitle = "Bentuk dan Tekstur"

    // 4 material yang sudah ada di `MaterialTexture.library` dipakai ulang di
    // tiap bentuk, cuma label & deskripsinya yang diterjemahkan/disesuaikan
    // untuk anak-anak. Urutan ini juga urutan next/back di checkpoint.
    private static func textures() -> [TextureStop] {
        [
            TextureStop(
                material: .defaultGrid,
                name: "Halus",
                description: "Coba raba, permukaannya rata dan licin ya!"
            ),
            TextureStop(
                material: MaterialTexture.library.first { $0.id == "marble" }!,
                name: "Licin & Mengkilap",
                description: "Permukaannya mengkilap seperti lantai marmer."
            ),
            TextureStop(
                material: MaterialTexture.library.first { $0.id == "wood" }!,
                name: "Kasar",
                description: "Permukaannya kasar, ada garis-garis seperti kayu."
            ),
            TextureStop(
                material: MaterialTexture.library.first { $0.id == "cutout" }!,
                name: "Berbintik",
                description: "Ada bintik-bintik kecil di seluruh permukaannya."
            )
        ]
    }

    static let kubus = GameShape(
        id: "kubus", displayName: "Kubus", objectType: .cube,
        quizSymbolName: "cube.fill", textures: textures()
    )
    static let bola = GameShape(
        id: "bola", displayName: "Bola", objectType: .sphere,
        quizSymbolName: "circle.fill", textures: textures()
    )
    static let tabung = GameShape(
        id: "tabung", displayName: "Tabung", objectType: .cylinder,
        quizSymbolName: "cylinder.fill", textures: textures()
    )
    static let kerucut = GameShape(
        id: "kerucut", displayName: "Kerucut", objectType: .cone,
        quizSymbolName: "triangle.fill", textures: textures()
    )

    /// Urutan jalur jalan kaki. `Level1ARCoordinator` menempatkan checkpoint
    /// di dunia nyata mengikuti urutan array ini.
    static let checkpoints: [Checkpoint] = [
        Checkpoint(id: "cp-0", order: 0, shape: kubus),
        Checkpoint(id: "cp-1", order: 1, shape: bola),
        Checkpoint(id: "cp-2", order: 2, shape: tabung),
        Checkpoint(id: "cp-3", order: 3, shape: kerucut)
    ]

    static let onboardingDialog: [DialogLine] = [
        DialogLine(characterName: "Kiki", text: "Halo, teman-teman! Aku Kiki 🦉"),
        DialogLine(characterName: "Kiki", text: "Hari ini kita akan jalan-jalan mencari bentuk-bentuk seru di sekitar kita!"),
        DialogLine(characterName: "Kiki", text: "Setiap bentuk itu punya tekstur yang berbeda lho. Ada yang halus, ada juga yang kasar."),
        DialogLine(characterName: "Kiki", text: "Nanti akan muncul bentuk 3D di layar kameramu — dekati untuk mulai menjelajah checkpoint pertama!")
    ]

    static let quiz: [TriviaQuestion] = [
        TriviaQuestion(
            id: "q-kubus",
            prompt: "Bentuk mana yang disebut Kubus?",
            choices: [kubus, bola, tabung, kerucut],
            correctShapeID: kubus.id
        ),
        TriviaQuestion(
            id: "q-bola",
            prompt: "Bentuk mana yang disebut Bola?",
            choices: [bola, kubus, tabung, kerucut],
            correctShapeID: bola.id
        ),
        TriviaQuestion(
            id: "q-tabung",
            prompt: "Bentuk mana yang disebut Tabung?",
            choices: [tabung, kerucut, kubus, bola],
            correctShapeID: tabung.id
        ),
        TriviaQuestion(
            id: "q-kerucut",
            prompt: "Bentuk mana yang disebut Kerucut?",
            choices: [kerucut, tabung, bola, kubus],
            correctShapeID: kerucut.id
        )
    ]
}
