//
//  EndLevelViewModel.swift
//  lightingconcept
//
//  Created by Rayhan Nanda on 17/08/26.
//

import Foundation
import Combine

class EndLevelViewModel: ObservableObject {
    @Published var endLevels: [EndLevelModel] = [
        EndLevelModel(
            id: 1,
            levelNumber: 1,
            message: "Kamu hebat!\nSekarang kamu bisa ke level berikutnya!",
            mascotImageName: "lumiIdle"
        ),
        EndLevelModel(
            id: 2,
            levelNumber: 2,
            message: "Kamu hebat!\nSekarang kamu bisa ke level berikutnya!",
            mascotImageName: "lumiIdle"
        ),
        EndLevelModel(
            id: 3,
            levelNumber: 3,
            message: "Kamu hebat!\nSekarang kamu bisa ke level berikutnya!",
            mascotImageName: "bayoIdle"
        )
    ]
}
