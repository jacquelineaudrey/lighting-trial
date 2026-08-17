//
//  LevelCardViewModel.swift
//  lightingconcept
//
//  Created by Rayhan Nanda on 17/08/26.
//

import Foundation
import Combine

class LevelCardViewModel: ObservableObject {
    @Published var levels: [Level] = [
        Level(id: 1, levelNumber: 1, title: "Bentuk dan\nTekstur", subtitle: "Yuk, lihat perbedaan\nbayangannya!"),
        Level(id: 2, levelNumber: 2, title: "Penyebaran\nCahaya", subtitle: "Yuk, lihat bagaimana\ncahaya bergerak!"),
        Level(id: 3, levelNumber: 3, title: "Jenis\nBayangan", subtitle: "Yuk, kenali bagian-bagian\nbayangan ini!")
    ]
}
