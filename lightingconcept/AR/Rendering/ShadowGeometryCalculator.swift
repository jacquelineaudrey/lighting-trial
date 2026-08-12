import Foundation
import simd

enum ShadowGeometryCalculator {
    static let groundY: Float = 0
    static let maximumProjectionDistance: Float = 5.0

    /// Kumpulan fungsi geometri cahaya/bayangan.
    ///
    /// Semua fungsi di sini hanya menghitung titik/arah secara matematis.
    /// Rendering garis/panah tetap dilakukan oleh `ProjectionLineRenderer`.

    /// Menghitung titik potong ray dengan bidang horizontal.
    ///
    /// Rumus garis 3D:
    /// P(t) = rayOrigin + rayDirection * t
    ///
    /// Karena bidang ground punya nilai y tetap (`planeY`), maka:
    /// planeY = rayOrigin.y + rayDirection.y * t
    /// t = (planeY - rayOrigin.y) / rayDirection.y
    ///
    /// Makna `t`:
    /// - t > 0 berarti titik potong ada di depan arah ray.
    /// - t < 0 berarti bidang ada di belakang ray, jadi diabaikan.
    ///
    /// Jika `rayDirection.y` hampir 0, ray sejajar bidang dan tidak punya titik potong stabil.
    static func rayPlaneIntersection(
        rayOrigin: SIMD3<Float>,
        rayDirection: SIMD3<Float>,
        planeY: Float = groundY
    ) -> SIMD3<Float>? {
        let normalizedDirection = simd_normalize(rayDirection)
        let denominator = normalizedDirection.y
        guard abs(denominator) > 0.0001 else { return nil }

        // t adalah jarak sepanjang ray sampai y-nya sama dengan tinggi bidang ground.
        let t = (planeY - rayOrigin.y) / denominator
        guard t > 0, t.isFinite, t <= maximumProjectionDistance else { return nil }
        return rayOrigin + normalizedDirection * t
    }

    /// Memproyeksikan titik object mengikuti arah datang cahaya sampai memotong ground.
    ///
    /// Rumusnya sama:
    /// projectedPoint = vertexPosition + lightDirection * t
    ///
    /// Perbedaan penting: ray dimulai dari vertex object, bukan dari posisi lampu.
    /// Ini sesuai konsep bayangan: setelah cahaya mengenai/terhalang object,
    /// batas bayangan diteruskan searah datangnya cahaya menuju permukaan.
    static func projectPointAlongLightDirection(
        vertexPosition: SIMD3<Float>,
        lightDirection: SIMD3<Float>,
        planeY: Float = groundY
    ) -> SIMD3<Float>? {
        rayPlaneIntersection(rayOrigin: vertexPosition, rayDirection: lightDirection, planeY: planeY)
    }

    /// Helper lama untuk model proyeksi dari posisi lampu ke titik object.
    /// Saat ini projection line utama memakai `projectPointAlongLightDirection`
    /// karena arah cahaya sudah dipisahkan dari posisi object.
    static func projectPointFromLight(
        lightPosition: SIMD3<Float>,
        objectPoint: SIMD3<Float>,
        planeY: Float = groundY
    ) -> SIMD3<Float>? {
        let direction = objectPoint - lightPosition
        guard simd_length(direction) > 0.0001 else { return nil }
        return rayPlaneIntersection(rayOrigin: lightPosition, rayDirection: simd_normalize(direction), planeY: planeY)
    }

    /// Arah bayangan di ground untuk point light sederhana.
    /// Bayangan bergerak menjauhi posisi light secara horizontal.
    static func groundShadowDirection(lightPosition: SIMD3<Float>, objectPosition: SIMD3<Float>) -> SIMD3<Float>? {
        let away = SIMD3<Float>(objectPosition.x - lightPosition.x, 0, objectPosition.z - lightPosition.z)
        let length = simd_length(away)
        guard length > 0.0001 else { return nil }
        return away / length
    }

    static func groundShadowDirection(lightDirection: SIMD3<Float>) -> SIMD3<Float>? {
        // Bayangan di ground hanya butuh arah X/Z. Komponen Y dihapus karena
        // panah ground projection digambar datar di permukaan.
        let projected = SIMD3<Float>(lightDirection.x, 0, lightDirection.z)
        let length = simd_length(projected)
        guard length > 0.0001 else { return nil }
        return projected / length
    }

    static func shadowDirectionDegrees(lightDirection: SIMD3<Float>) -> Float? {
        guard let direction = groundShadowDirection(lightDirection: lightDirection) else { return nil }
        return atan2(direction.x, direction.z).radiansToDegrees
    }

    /// Estimasi panjang shadow dengan model segitiga sebangun dari arah cahaya.
    ///
    /// Asumsi:
    /// - ground datar,
    /// - cahaya bergerak mengikuti `lightDirection`,
    /// - object dianggap punya tinggi `objectHeight`
    ///
    /// Jika direction sudah dinormalisasi:
    /// - verticalDrop = -direction.y
    /// - horizontalRun = panjang vector horizontal direction.x/z
    ///
    /// Untuk tiap 1 meter cahaya turun, ray bergerak horizontal sebesar:
    /// horizontalRun / verticalDrop
    ///
    /// Maka estimasi panjang bayangan object setinggi h:
    /// shadowLength = h * horizontalRun / verticalDrop
    ///
    /// Fungsi ini hanya untuk panel informasi, bukan untuk merender shadow.
    static func approximateShadowLength(
        lightDirection: SIMD3<Float>,
        objectHeight: Float
    ) -> Float? {
        let direction = simd_normalize(lightDirection)
        let verticalDrop = -direction.y
        guard verticalDrop > 0.0001 else { return nil }

        // Segitiga sebangun dari arah cahaya: horizontal run per vertical drop.
        let horizontalRun = SIMD3<Float>(direction.x, 0, direction.z).horizontalLength
        let length = objectHeight * horizontalRun / verticalDrop
        guard length.isFinite else { return nil }
        return min(length, maximumProjectionDistance)
    }

    /// Mengambil titik proyeksi dari vertex atas cube.
    /// Ini menjelaskan kenapa shadow cube punya sudut/edge, terutama saat cube dirotasi.
    static func cubeProjectionPoints(
        lightPosition: SIMD3<Float>,
        cubeCenter: SIMD3<Float>
    ) -> [SIMD3<Float>] {
        cubeTopVertices(center: cubeCenter).compactMap {
            projectPointFromLight(
                lightPosition: lightPosition,
                objectPoint: $0
            )
        }
    }

    private static func cubeTopVertices(
        center: SIMD3<Float>
    ) -> [SIMD3<Float>] {
        let halfSize: Float = 0.12 / 2
        let topY = center.y + halfSize

        return [
            SIMD3<Float>(
                center.x - halfSize,
                topY,
                center.z - halfSize
            ),
            SIMD3<Float>(
                center.x + halfSize,
                topY,
                center.z - halfSize
            ),
            SIMD3<Float>(
                center.x + halfSize,
                topY,
                center.z + halfSize
            ),
            SIMD3<Float>(
                center.x - halfSize,
                topY,
                center.z + halfSize
            )
        ]
    }}
