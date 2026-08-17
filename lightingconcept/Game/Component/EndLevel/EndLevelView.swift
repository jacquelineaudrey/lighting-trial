//
//  EndLevelView.swift
//  lightingconcept
//
//  Created by Rayhan Nanda on 17/08/26.
//

import SwiftUI

struct EndLevelView: View {
    let data: EndLevelModel

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
                    Button(action: {
                        // TODO: back action
                    }) {
                        Text("Kembali")
                            .font(.system(size: 17))
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "313131"))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 15)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "E6E3BF"))
                            )
                    }

                    Spacer()

                    Button(action: {
                        // TODO: next action
                    }) {
                        Text("Selanjutnya")
                            .font(.system(size: 17))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 15)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "9FA60C"))
                            )
                    }
                }
                .frame(maxWidth: 540)
                .padding(.horizontal, 24)
            }
            .padding(.top, 280)

            Image(data.mascotImageName)
                .offset(x: 415, y: 270)
        }
    }
}

#Preview(traits: .landscapeLeft) {
    EndLevelView(data: EndLevelModel(
        id: 1,
        levelNumber: 1,
        message: "Kamu hebat!\nSekarang kamu bisa ke level berikutnya!",
        mascotImageName: "lumiIdle"
    ))
}
