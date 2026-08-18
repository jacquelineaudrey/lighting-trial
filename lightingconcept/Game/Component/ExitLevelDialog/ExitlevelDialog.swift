//
//  ExitlevelDialog.swift
//  lightingconcept
//
//  Created by Rayhan Nanda on 18/08/26.
//

import SwiftUI

struct ExitLevelDialog: View {
    var onStayTapped: () -> Void = {}
    var onExitTapped: () -> Void = {}

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 35)
                .fill(Color(hex: "EFEBCF"))
                .overlay(
                    RoundedRectangle(cornerRadius: 35)
                        .stroke(Color(hex: "D6CF91"), lineWidth: 2)
                )
                .frame(width: 300, height: 240)

            VStack(alignment: .leading, spacing: 8) {
                Text("Keluar dari level?")
                    .font(.system(size: 17))
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "313131"))

                Text("Progress kamu di level ini akan hilang lho!")
                    .font(.system(size: 17))
                    .fontWeight(.regular)
                    .foregroundColor(Color(hex: "313131"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 256, height: 76, alignment: .topLeading)
            .padding(.top, 24)

            VStack(spacing: 12) {
                Button(action: onStayTapped) {
                    Text("Tetap Main")
                        .font(.system(size: 17))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 272, height: 48)
                        .background(
                            Capsule()
                                .fill(Color(hex: "9FA60C"))
                        )
                }

                Button(action: onExitTapped) {
                    Text("Keluar")
                        .font(.system(size: 17))
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "C0392B"))
                        .frame(width: 272, height: 48)
                        .overlay(
                            Capsule()
                                .stroke(Color(hex: "C0392B"), lineWidth: 1)
                        )
                }
            }
            .padding(.top, 115) // distance from dialog top to button group — adjust as needed
        }
    }
}

#Preview(traits: .landscapeLeft) {
    ExitLevelDialog()
}
