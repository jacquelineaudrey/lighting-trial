//
//  OutlinedText.swift
//  lightingconcept
//

import SwiftUI

/// Teks SF Pro dengan outline di luar glyph. Salinan teks yang digeser membentuk
/// outline, lalu teks utama menutup bagian dalam agar warna isi tetap bersih.
struct OutlinedText<Content: View>: View {
    private let content: Content
    private let foregroundStyle: Color
    private let outlineStyle: Color
    private let outlineWidth: CGFloat

    @ScaledMetric(relativeTo: .largeTitle) private var fontSize: CGFloat = 48

    init(
        _ content: Content,
        foregroundStyle: Color,
        outlineStyle: Color,
        outlineWidth: CGFloat,
        baseFontSize: CGFloat = 48
    ) {
        self.content = content
        self.foregroundStyle = foregroundStyle
        self.outlineStyle = outlineStyle
        self.outlineWidth = outlineWidth
        self._fontSize = ScaledMetric(
            wrappedValue: baseFontSize,
            relativeTo: .largeTitle
        )
    }

    var body: some View {
        ZStack {
            ForEach(Self.outlineAngles, id: \.self) { angle in
                styledText
                    .foregroundStyle(outlineStyle)
                    .offset(
                        x: cos(angle) * outlineWidth,
                        y: sin(angle) * outlineWidth
                    )
            }

            styledText
                .foregroundStyle(foregroundStyle)
        }
        .padding(outlineWidth + 1)
        .drawingGroup()
    }

    private var styledText: some View {
        content
            .font(.system(size: fontSize, weight: .bold, design: .default))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private static var outlineAngles: [CGFloat] {
        stride(from: 0, to: .pi * 2, by: .pi / 12).map { $0 }
    }
}
