//
//  LockAlertViewModel.swift
//  lightingconcept
//
//  Created by Rayhan Nanda on 18/08/26.
//

import Foundation
import Combine

class LockAlertViewModel: ObservableObject {
    @Published var alerts: [LockAlertData] = [
        LockAlertData(
            id: 1,
            title: "Simulasi belum terbuka!",
            subtitle: "Ayo kita mulai belajar dulu untuk membuka bagian ini!"
        ),
        LockAlertData(
            id: 2,
            title: "Level belum terbuka!",
            subtitle: "Selesaikan level sebelumnya dulu yaa!"
        )
    ]
}
