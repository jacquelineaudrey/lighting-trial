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
/// Enam level tetap ditampilkan pada peta, tetapi saat ini hanya Level 1-3 yang
/// sudah dapat dimainkan.
@MainActor
@Observable
final class GameProgressStore {
    static let shared = GameProgressStore()

    /// Total level Belajar yang direncanakan (fixed di 6 sesuai desain).
    let totalBelajarLevels = 6

    /// Level 4-6 masih dalam pengembangan dan tidak ikut skema unlock.
    let playableBelajarLevelIDs: Set<Int> = [1, 2, 3]

    private(set) var completedLevelIDs: Set<Int>

    private let defaultsKey = "belajar.completedLevelIDs"

    private init() {
        let saved = UserDefaults.standard.array(forKey: defaultsKey) as? [Int] ?? []
        completedLevelIDs = Self.normalizedCompletedLevelIDs(from: Set(saved))

        // Bersihkan progres lama dari bypass debug atau level yang belum rilis.
        if completedLevelIDs != Set(saved) {
            UserDefaults.standard.set(completedLevelIDs.sorted(), forKey: defaultsKey)
        }
    }

    /// Level 1 selalu terbuka. Level berikutnya hanya terbuka jika seluruh
    /// level sebelumnya sudah selesai. Level yang masih dikembangkan tetap
    /// terkunci meskipun Level 3 sudah selesai.
    func isLevelUnlocked(_ levelID: Int) -> Bool {
        guard playableBelajarLevelIDs.contains(levelID) else { return false }
        guard levelID > 1 else { return true }
        return Set(1..<levelID).isSubset(of: completedLevelIDs)
    }

    func isLevelCompleted(_ levelID: Int) -> Bool {
        playableBelajarLevelIDs.contains(levelID) && completedLevelIDs.contains(levelID)
    }

    func markLevelCompleted(_ levelID: Int) {
        guard playableBelajarLevelIDs.contains(levelID) else { return }
        guard isLevelUnlocked(levelID) else { return }
        guard !completedLevelIDs.contains(levelID) else { return }
        completedLevelIDs.insert(levelID)
        UserDefaults.standard.set(completedLevelIDs.sorted(), forKey: defaultsKey)
    }

    /// Sandbox baru terbuka setelah SEMUA level Belajar selesai.
    var isSandboxUnlocked: Bool {
        belajarLevelIDs.isSubset(of: completedLevelIDs)
    }

    private var belajarLevelIDs: Set<Int> {
        Set(1...totalBelajarLevels)
    }

    private static func normalizedCompletedLevelIDs(from saved: Set<Int>) -> Set<Int> {
        var normalized: Set<Int> = []
        for levelID in 1...3 {
            guard saved.contains(levelID) else { break }
            normalized.insert(levelID)
        }
        return normalized
    }

    #if DEBUG
    /// Bantuan buat testing manual di simulator.
    func resetProgress() {
        completedLevelIDs = []
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    #endif
}
