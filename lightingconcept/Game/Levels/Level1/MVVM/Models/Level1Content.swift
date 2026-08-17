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
    let audioFileName: String?

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
    let audioFileName: String?

    init(characterName: String, text: String, audioFileName: String? = nil) {
        self.characterName = characterName
        self.text = text
        self.audioFileName = audioFileName
    }
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

    // Material yang sudah ada di `MaterialTexture.library` dipakai ulang di
    // tiap bentuk, cuma label & deskripsinya yang diterjemahkan/disesuaikan
    // untuk anak-anak. Urutan ini juga urutan next/back di checkpoint.
    private static func textures() -> [TextureStop] {
        [
            TextureStop(
                material: .defaultGrid,
                name: "Kotak-kotak",
                description: "Polanya rapi seperti papan catur.",
                audioFileName: "level-1/marker/tekstur/[kotak kotak]Ini Tekstur Kotak-kotak! Polanya rapi dan bersilangan mirip seperti papan catur, lho!.mp3"
            ),
            TextureStop(
                material: MaterialTexture.library.first { $0.id == "marble" }!,
                name: "Marmer",
                description: "Halus dan punya corak yang cantik.",
                audioFileName: "level-1/marker/tekstur/[marmer] Ini Tekstur Marmer! Halus dan punya corak yang cantik!.mp3"
            ),
            TextureStop(
                material: MaterialTexture.library.first { $0.id == "wood" }!,
                name: "Kayu",
                description: "Permukaannya kasar, ada garis-garis seperti kayu.",
                audioFileName: "level-1/marker/tekstur/[kayu]Ini Tekstur Kayu! Punya garis-garis serat alami yang khas dan sangat unik, lho!.mp3"
            ),
            TextureStop(
                material: MaterialTexture.library.first { $0.id == "metal" }!,
                name: "Besi",
                description: "Permukaannya keras dan terlihat mengkilap.",
                audioFileName: "level-1/marker/tekstur/[besi] Ini Tekstur Besi! Permukaannya terasa keras, padat, dan terlihat mengkilap, lho!.mp3"
            ),
            TextureStop(
                material: MaterialTexture.library.first { $0.id == "cutout" }!,
                name: "Berlubang",
                description: "Permukaannya punya bolongan kecil.",
                audioFileName: "level-1/marker/tekstur/[berlubang] Ini Tekstur Berlubang! Permukaannya dipenuhi bolongan atau rongga-rongga kecil seperti spons, lho!.mp3"
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
    static let balok = GameShape(
        id: "balok", displayName: "Balok", objectType: .cuboid,
        quizSymbolName: "rectangle.fill", textures: textures()
    )
    static let piramida = GameShape(
        id: "piramida", displayName: "Piramida", objectType: .squarePyramid,
        quizSymbolName: "pyramid.fill", textures: textures()
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
        Checkpoint(id: "cp-1", order: 1, shape: balok),
        Checkpoint(id: "cp-2", order: 2, shape: bola),
        Checkpoint(id: "cp-3", order: 3, shape: piramida),
        Checkpoint(id: "cp-4", order: 4, shape: kerucut),
        Checkpoint(id: "cp-5", order: 5, shape: tabung)
    ]

    static let onboardingDialog: [DialogLine] = [
        DialogLine(characterName: "Lumi", text: "Hai, Penjelajah Kecil! Namaku Lumi.", audioFileName: "level-1/1 Hai Penjelajah Kecil namaku Lumy.mp3"),
        DialogLine(characterName: "Lumi", text: "Yuk, kenalan sama bentuk dan tekstur!", audioFileName: "level-1/2 Yuk kenalan sama bentuk dan tekstur.mp3"),
        DialogLine(characterName: "Lumi", text: "Coba cari objek berbentuk kotak di sekitarmu!", audioFileName: "level-1/3 coba cari objek berbentuk kotak di sekitarmu.mp3"),
        DialogLine(characterName: "Lumi", text: "Yeay ketemu! Sekarang Lumi hidupin lampu dulu sebagai sumber cahaya ya.", audioFileName: "level-1/4 yeay ketemu sekarang lumi hidupin lampu.mp3")
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
