import Foundation
import simd

enum ShadowGeometryCalculator {
    static let groundY: Float = 0
    static let maximumProjectionDistance: Float = 5.0

    /// Menghitung titik potong ray dengan bidang horizontal.
    ///
    /// Rumus garis 3D:
    /// P(t) = rayOrigin + rayDirection * t
    ///
    /// Karena bidang ground punya nilai y tetap (`planeY`), maka:
    /// planeY = rayOrigin.y + rayDirection.y * t
    /// t = (planeY - rayOrigin.y) / rayDirection.y
    ///
    /// Jika `rayDirection.y` hampir 0, ray sejajar bidang dan tidak punya titik potong stabil.
    static func rayPlaneIntersection(
        rayOrigin: SIMD3<Float>,
        rayDirection: SIMD3<Float>,
        planeY: Float = groundY
    ) -> SIMD3<Float>? {
        let denominator = rayDirection.y
        guard abs(denominator) > 0.0001 else { return nil }

        let t = (planeY - rayOrigin.y) / denominator
        guard t > 0, t.isFinite, t <= maximumProjectionDistance else { return nil }
        return rayOrigin + rayDirection * t
    }

    /// Memproyeksikan satu titik object ke ground dari posisi light.
    /// Ini dipakai untuk overlay edukasi, bukan untuk membuat shadow render utama.
    static func projectPointFromLight(
        lightPosition: SIMD3<Float>,
        objectPoint: SIMD3<Float>,
        planeY: Float = groundY
    ) -> SIMD3<Float>? {
        let direction = objectPoint - lightPosition
        guard simd_length(direction) > 0.0001 else { return nil }
        return rayPlaneIntersection(rayOrigin: lightPosition, rayDirection: simd_normalize(direction), planeY: planeY)
    }

    /// Arah bayangan di ground untuk point/spot light sederhana.
    /// Bayangan bergerak menjauhi posisi light secara horizontal.
    static func groundShadowDirection(lightPosition: SIMD3<Float>, objectPosition: SIMD3<Float>) -> SIMD3<Float>? {
        let away = SIMD3<Float>(objectPosition.x - lightPosition.x, 0, objectPosition.z - lightPosition.z)
        let length = simd_length(away)
        guard length > 0.0001 else { return nil }
        return away / length
    }

    static func shadowDirectionDegrees(lightPosition: SIMD3<Float>, objectPosition: SIMD3<Float>) -> Float? {
        guard let direction = groundShadowDirection(lightPosition: lightPosition, objectPosition: objectPosition) else { return nil }
        return atan2(direction.x, direction.z).radiansToDegrees
    }

    /// Estimasi panjang shadow dengan model segitiga sebangun.
    ///
    /// Asumsi:
    /// - ground datar di y = 0
    /// - light berada di atas object
    /// - object dianggap punya tinggi `objectHeight`
    ///
    /// Jika jarak horizontal light ke object = d dan tinggi light = H,
    /// maka panjang shadow dari sisi object kira-kira:
    /// shadowLength = objectHeight * d / (H - objectHeight)
    ///
    /// Fungsi ini hanya untuk panel informasi, bukan untuk merender shadow.
    static func approximateShadowLength(
        lightPosition: SIMD3<Float>,
        objectGroundPosition: SIMD3<Float>,
        objectHeight: Float
    ) -> Float? {
        let lightHeight = lightPosition.y
        guard lightHeight > objectHeight + 0.01 else { return nil }
        let horizontalDistance = SIMD3<Float>(
            lightPosition.x - objectGroundPosition.x,
            0,
            lightPosition.z - objectGroundPosition.z
        ).horizontalLength
        let length = (objectHeight * horizontalDistance) / (lightHeight - objectHeight)
        guard length.isFinite else { return nil }
        return min(length, maximumProjectionDistance)
    }

    /// Mengambil titik proyeksi dari vertex atas cube.
    /// Ini menjelaskan kenapa shadow cube punya sudut/edge, terutama saat cube dirotasi.
    static func cubeProjectionPoints(lightPosition: SIMD3<Float>, cubeCenter: SIMD3<Float>) -> [SIMD3<Float>] {
        ObjectFactory.cubeTopVertices(center: cubeCenter).compactMap {
            projectPointFromLight(lightPosition: lightPosition, objectPoint: $0)
        }
    }
}
