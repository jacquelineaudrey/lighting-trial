import ARKit
import CoreVideo
import Foundation

/// Mengambil sampel kecil dari bidang luminance kamera secara berkala. Region
/// tengah-bawah dipilih karena pada permainan landscape area itu paling sering
/// berisi lantai, tanpa menjalankan Core Image atau alokasi gambar tambahan.
nonisolated final class EducationalMarkerSurfaceToneEstimator: @unchecked Sendable {
    private let lock = NSLock()
    private let samplingInterval: TimeInterval = 0.7
    private var lastSampleTimestamp: TimeInterval = -.infinity
    private var smoothedLuminance: Double?
    private var currentTone: EducationalMarkerStyle.SurfaceTone = .medium

    func updatedTone(for frame: ARFrame) -> EducationalMarkerStyle.SurfaceTone? {
        lock.lock()
        defer { lock.unlock() }

        guard frame.timestamp - lastSampleTimestamp >= samplingInterval else { return nil }
        lastSampleTimestamp = frame.timestamp
        guard let luminance = averageFloorLuminance(in: frame.capturedImage) else { return nil }

        let smoothed = smoothedLuminance.map { $0 * 0.68 + luminance * 0.32 } ?? luminance
        smoothedLuminance = smoothed
        let nextTone = classifiedTone(for: smoothed, previous: currentTone)
        guard nextTone != currentTone else { return nil }
        currentTone = nextTone
        return nextTone
    }

    private func averageFloorLuminance(in pixelBuffer: CVPixelBuffer) -> Double? {
        guard CVPixelBufferGetPlaneCount(pixelBuffer) > 0 else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return nil }
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        guard width > 0, height > 0 else { return nil }

        let pixels = baseAddress.assumingMemoryBound(to: UInt8.self)
        let startX = width * 15 / 100
        let endX = width * 85 / 100
        let startY = height * 38 / 100
        let endY = height * 94 / 100
        let stepX = max(width / 40, 8)
        let stepY = max(height / 30, 8)
        var total = 0
        var count = 0

        for y in stride(from: startY, to: endY, by: stepY) {
            let row = pixels.advanced(by: y * bytesPerRow)
            for x in stride(from: startX, to: endX, by: stepX) {
                total += Int(row[x])
                count += 1
            }
        }

        guard count > 0 else { return nil }
        return Double(total) / Double(count) / 255.0
    }

    private func classifiedTone(
        for luminance: Double,
        previous: EducationalMarkerStyle.SurfaceTone
    ) -> EducationalMarkerStyle.SurfaceTone {
        // Hysteresis mencegah warna berkedip ketika kamera berada tepat di
        // ambang dua kategori atau terkena perubahan exposure sesaat.
        switch previous {
        case .bright where luminance >= 0.58:
            .bright
        case .dark where luminance <= 0.42:
            .dark
        default:
            if luminance >= 0.66 {
                .bright
            } else if luminance <= 0.34 {
                .dark
            } else {
                .medium
            }
        }
    }
}
