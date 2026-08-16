//
//  LevelCard.swift
//  lightingconcept
//
//  Created by Rayhan Nanda on 16/08/26.
//

import SwiftUI

struct LevelCardView: View {
    let level: Level

    var body: some View {
        ZStack {
            Image("container")

            VStack(spacing: 50) {

                ZStack {
                    Image("ribbonRed")
                    Text("LEVEL \(level.levelNumber)")
                        .font(.system(size: 36))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .offset(x: 0, y: -7)
                }

                Text(level.title)
                    .font(.system(size: 40))
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "313131"))
                    .multilineTextAlignment(.center)

                Text(level.subtitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(hex: "313131"))
                    .frame(width: 350, height: 130)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color(hex: "D6CF91").opacity(0.25))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color(hex: "D6CF91"), lineWidth: 2)
                    )

                ZStack {
                    Image("button")
                    Text("MULAI")
                        .font(.system(size: 36))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .offset(x: 0, y: -3)
                }
            }
        }
    }
}

#Preview(traits: .landscapeLeft) {
    LevelCardView(level: Level(id: 1, levelNumber: 1, title: "Bentuk dan\nTekstur", subtitle: "Yuk, lihat perbedaan\nbayangannya!"))
}
