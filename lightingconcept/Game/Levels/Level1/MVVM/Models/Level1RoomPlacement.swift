import Foundation

/// Susunan checkpoint yang sudah lolos pemeriksaan batas bidang dan ruang kosong.
struct Level1RoomPlacement {
    let centerXZ: SIMD2<Float>
    let floorY: Float
    let checkpointXZ: [SIMD2<Float>]
}
