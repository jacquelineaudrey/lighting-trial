//
//  GameProgressStore.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import Foundation
import Observation

/// Menyimpan progres menu "Belajar" (level mana yang sudah selesai) dan menentukan
/// kapan menu "Sandbox" terbuka.
///
/// Nanti kalau konten level 2-6 sudah ada, cukup isi `Level2Content`, dst — angka
/// `totalBelajarLevels` di sini sudah disiapkan untuk 6 level dari awal.
@MainActor
@Observable
final class GameProgressStore {
    static let shared = GameProgressStore()

    /// Total level Belajar yang direncanakan (fixed di 6 sesuai desain).
    let totalBelajarLevels = 6

    private(set) var completedLevelIDs: Set<Int>

    private let defaultsKey = "belajar.completedLevelIDs"

    private init() {
        let saved = UserDefaults.standard.array(forKey: defaultsKey) as? [Int] ?? []
        completedLevelIDs = Set(saved)
    }

    /// Level 1 selalu terbuka. Level berikutnya baru terbuka kalau level
    /// sebelumnya sudah selesai (unlock berurutan/linear).
    func isLevelUnlocked(_ levelID: Int) -> Bool {
        if levelID <= 1 { return true }
        return completedLevelIDs.contains(levelID - 1)
    }

    func isLevelCompleted(_ levelID: Int) -> Bool {
        completedLevelIDs.contains(levelID)
    }

    func markLevelCompleted(_ levelID: Int) {
        guard belajarLevelIDs.contains(levelID) else { return }
        guard !completedLevelIDs.contains(levelID) else { return }
        completedLevelIDs.insert(levelID)
        UserDefaults.standard.set(Array(completedLevelIDs), forKey: defaultsKey)
    }

    /// Sandbox baru terbuka setelah SEMUA level Belajar selesai.
    var isSandboxUnlocked: Bool {
        belajarLevelIDs.isSubset(of: completedLevelIDs)
    }

    private var belajarLevelIDs: Set<Int> {
        Set(1...totalBelajarLevels)
    }

    #if DEBUG
    /// Bantuan buat testing manual di simulator.
    func resetProgress() {
        completedLevelIDs = []
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    #endif
}
