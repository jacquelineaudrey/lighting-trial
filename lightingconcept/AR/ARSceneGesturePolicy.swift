/// Menentukan gesture bawaan yang dipasang oleh scene AR.
/// Level belajar yang memiliki gesture sendiri tetap membutuhkan tap pertama
/// untuk menaruh scene, tetapi tidak boleh memindahkan objek secara tidak sengaja.
enum ARSceneGesturePolicy: Equatable {
    case full
    case placementOnly
}
