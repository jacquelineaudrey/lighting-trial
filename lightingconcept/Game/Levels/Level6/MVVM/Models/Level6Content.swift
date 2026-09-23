import SwiftUI

// MARK: - Position Guidance

enum Level6PositionGuidanceStep: Equatable {
    case overview
    case planarMovement
    case height
    case complete
}

// MARK: - Level Phase

enum Level6Phase: Equatable {
    case placingScene
    case introduction(Int)
    case selectingFirstLight
    case changingFirstColor
    case firstColorResult
    case selectingSecondLight
    case changingSecondColor
    case colorShadowPrompt
    case colorShadowExplanation
    case colorExplorationIntro
    case colorExploration
    case positionExplorationIntro
    case positionExploration
    case drawingIntro
    case drawingChoice
    case drawingOnPaper
    case photoPrompt
    case photoComparison
    case completed
}

// MARK: - Content

enum Level6Content {
    static let levelID = 6
    static let levelTitle = "Warna Cahaya"

    static let introduction = [
        Level6Dialog(
            text: "Halooo! Eh... Lumi punya rahasia menarik loh, penasarann?",
            assetName: "lumiPointwink"
        ),

        Level6Dialog(
            text: "Ternyata cahaya ga cuman terang, cahaya juga bisa punya banyak warna!",
            assetName: "lumiPoint"
        ),

        Level6Dialog(
            text: "Ga percaya nih? Yuk, kita coba ubah warna cahayanya sekarang!",
            assetName: "lumiIdle"
        ),

        Level6Dialog(
            text: "Yuk, kita pilih cahayanya dulu!",
            assetName: "lumiPointwink"
        )
    ]
}

// MARK: - Dialog

struct Level6Dialog: Equatable {
    let text: String
    let assetName: String
}

// MARK: - Light Colors

enum Level6LightColor: String, CaseIterable, Identifiable, Hashable {
    case black
    case blue
    case green
    case yellow
    case red
    case lightBlue
    case purple
    case orange
    case pink
    case white

    var id: Self {
        self
    }

    var displayName: String {
        switch self {
        case .black:
            "Hitam"

        case .blue:
            "Biru"

        case .green:
            "Hijau"

        case .yellow:
            "Kuning"

        case .red:
            "Merah"

        case .lightBlue:
            "Biru Muda"

        case .purple:
            "Ungu"

        case .orange:
            "Oranye"

        case .pink:
            "Merah Muda"

        case .white:
            "Putih"
        }
    }

    var color: Color {
        Color(
            red: rgb.x,
            green: rgb.y,
            blue: rgb.z
        )
    }

    fileprivate var rgb: SIMD3<Double> {
        switch self {
        case .black:
            SIMD3(0.03, 0.03, 0.03)

        case .blue:
            SIMD3(0.05, 0.38, 0.95)

        case .green:
            SIMD3(0.12, 0.75, 0.32)

        case .yellow:
            SIMD3(1.0, 0.78, 0.0)

        case .red:
            SIMD3(1.0, 0.12, 0.08)

        case .lightBlue:
            SIMD3(0.34, 0.72, 0.95)

        case .purple:
            SIMD3(0.48, 0.16, 0.92)

        case .orange:
            SIMD3(1.0, 0.48, 0.12)

        case .pink:
            SIMD3(0.96, 0.34, 0.66)

        case .white:
            SIMD3(1.0, 1.0, 1.0)
        }
    }
}

// MARK: - Color Mixing

enum Level6ColorMixing {

    static func result(
        for first: Level6LightColor,
        and second: Level6LightColor
    ) -> Level6LightColor {

        // Warna yang sama
        if first == second {
            return first
        }

        if first == .black || second == .black {
            return .black
        }

        // Putih berfungsi sebagai tint,
        // bukan langsung menghasilkan putih.
        if first == .white {
            return tintWithWhite(second)
        }

        if second == .white {
            return tintWithWhite(first)
        }

        let pair = Set([first, second])

        // Kombinasi utama additive RGB
        let knownResults: [Set<Level6LightColor>: Level6LightColor] = [

            // Primary colors
            [.red, .green]: .yellow,
            [.red, .blue]: .purple,
            [.green, .blue]: .lightBlue,

            // Secondary colors
            [.red, .yellow]: .orange,
            [.red, .orange]: .orange,
            [.red, .pink]: .pink,

            [.blue, .purple]: .purple,
            [.blue, .lightBlue]: .lightBlue,

            [.green, .yellow]: .yellow,
            [.green, .lightBlue]: .lightBlue,

            [.purple, .pink]: .pink,
            [.yellow, .orange]: .orange
        ]

        if let knownResult = knownResults[pair] {
            return knownResult
        }

        // Fallback berdasarkan pencampuran RGB
        let mixedRGB = additiveMix(
            first.rgb,
            second.rgb
        )

        return classify(mixedRGB)
    }

    // MARK: White Tint

    private static func tintWithWhite(
        _ color: Level6LightColor
    ) -> Level6LightColor {
        switch color {
        case .black:
            return .white

        case .red:
            return .pink

        case .blue:
            return .lightBlue

        case .green:
            return .lightBlue

        case .purple:
            return .pink

        case .orange:
            return .yellow

        case .pink:
            return .pink

        case .yellow:
            return .yellow

        case .lightBlue:
            return .lightBlue

        case .white:
            return .white
        }
    }

    // MARK: RGB Additive Mixing

    private static func additiveMix(
        _ first: SIMD3<Double>,
        _ second: SIMD3<Double>
    ) -> SIMD3<Double> {
        let mixed = first + second

        let clamped = SIMD3<Double>(
            min(mixed.x, 1.0),
            min(mixed.y, 1.0),
            min(mixed.z, 1.0)
        )

        return normalize(clamped)
    }

    // MARK: Normalize RGB

    private static func normalize(
        _ rgb: SIMD3<Double>
    ) -> SIMD3<Double> {
        let maximum = max(
            rgb.x,
            max(rgb.y, rgb.z)
        )

        guard maximum > 0 else {
            return SIMD3(0, 0, 0)
        }

        return SIMD3(
            rgb.x / maximum,
            rgb.y / maximum,
            rgb.z / maximum
        )
    }

    // MARK: Convert RGB to App Color

    private static func classify(
        _ rgb: SIMD3<Double>
    ) -> Level6LightColor {
        let red = rgb.x
        let green = rgb.y
        let blue = rgb.z

        let threshold = 0.15

        let hasRed = red > threshold
        let hasGreen = green > threshold
        let hasBlue = blue > threshold

        // Semua channel hampir sama aktif = putih
        if hasRed && hasGreen && hasBlue {
            let maximum = max(
                red,
                max(green, blue)
            )

            let minimum = min(
                red,
                min(green, blue)
            )

            if maximum - minimum < 0.20 {
                return .white
            }

            // Red + Blue = Purple
            if red > green * 1.20 &&
                blue > green * 1.20 {
                return .purple
            }

            // Green + Blue = Light Blue
            if green > red * 1.20 &&
                blue > red * 1.20 {
                return .lightBlue
            }

            // Red + Green = Yellow
            if red > blue * 1.20 &&
                green > blue * 1.20 {
                return .yellow
            }
        }

        // Satu warna primer
        if hasRed && !hasGreen && !hasBlue {
            return .red
        }

        if !hasRed && hasGreen && !hasBlue {
            return .green
        }

        if !hasRed && !hasGreen && hasBlue {
            return .blue
        }

        // Red + Green
        if hasRed && hasGreen && !hasBlue {
            if red > green * 1.35 {
                return .orange
            }

            return .yellow
        }

        // Red + Blue
        if hasRed && !hasGreen && hasBlue {
            if red > blue * 1.35 {
                return .pink
            }

            return .purple
        }

        // Green + Blue
        if !hasRed && hasGreen && hasBlue {
            return .lightBlue
        }

        return closestColor(to: rgb)
    }

    // MARK: Closest Available Color

    private static func closestColor(
        to target: SIMD3<Double>
    ) -> Level6LightColor {
        Level6LightColor.allCases
            .filter {
                $0 != .black && $0 != .white
            }
            .min { first, second in
                distance(first.rgb, target)
                    < distance(second.rgb, target)
            } ?? .white
    }

    private static func distance(
        _ first: SIMD3<Double>,
        _ second: SIMD3<Double>
    ) -> Double {
        let delta = first - second

        return
            delta.x * delta.x +
            delta.y * delta.y +
            delta.z * delta.z
    }
}
