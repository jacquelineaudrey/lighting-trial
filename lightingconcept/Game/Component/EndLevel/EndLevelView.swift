//
//  EndLevelView.swift
//  lightingconcept
//
//  Created by Rayhan Nanda on 17/08/26.
//

import SwiftUI

struct EndLevelView: View {
    let data: EndLevelModel
    let onBack: () -> Void
    let onNext: (() -> Void)?
    let backTitle: String

    init(
        data: EndLevelModel,
        onBack: @escaping () -> Void,
        onNext: (() -> Void)? = nil,
        backTitle: String = "Pilih Level"
    ) {
        self.data = data
        self.onBack = onBack
        self.onNext = onNext
        self.backTitle = backTitle
    }

    var body: some View {

        ZStack(alignment: .top) {
            Image("containerWood")

            ZStack {
                Image("ribbonBlue")
                Text("LEVEL \(data.levelNumber)")
                    .font(.system(size: 36))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .offset(x: 0, y: -7)
            }
            .padding(.top, 80)

            VStack(spacing: 70) {
                Text(data.message)
                    .font(.title)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .frame(width: 625, height: 130)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color(hex: "C98928"))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color(hex: "7E520E"), lineWidth: 2)
                    )

                HStack {
                    LevelActionButton(
                        title: backTitle,
                        systemImage: backSystemImage,
                        role: backButtonRole,
                        action: onBack
                    )

                    Spacer()

                    LevelActionButton(
                        title: onNext == nil ? "Selesai" : "Selanjutnya",
                        systemImage: onNext == nil ? "checkmark" : "arrow.right",
                        action: finishLevel
                    )
                }
                .frame(maxWidth: 540)
                .padding(.horizontal, 24)
            }
            .padding(.top, 280)

            Image(data.mascotImageName)
                .offset(x: 415, y: 270)
        }
    }

    private func finishLevel() {
        if let onNext {
            onNext()
        } else {
            onBack()
        }
    }

    private var backSystemImage: String {
        backTitle == "Kembali ke Menu" ? "house.fill" : "square.grid.2x2"
    }

    private var backButtonRole: LevelActionButton.Role {
        backTitle == "Kembali ke Menu" ? .menu : .secondary
    }
}

#Preview(traits: .landscapeLeft) {
    EndLevelView(data: EndLevelModel(
        id: 1,
        levelNumber: 1,
        message: "Kamu hebat!\nSekarang kamu bisa ke level berikutnya!",
        mascotImageName: "lumiIdle"
    ), onBack: { }, onNext: { })
}
