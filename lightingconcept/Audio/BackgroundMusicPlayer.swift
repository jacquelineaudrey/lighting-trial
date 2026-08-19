import AVFoundation
import Foundation

/// Memutar satu BGM yang terus digunakan selama aplikasi berjalan.
@MainActor
final class BackgroundMusicPlayer {
    static let shared = BackgroundMusicPlayer()

    private static let menuVolume: Float = 1
    private static let gameplayVolume: Float = 0.4
    private static let volumeTransitionDuration: TimeInterval = 0.25

    private var player: AVAudioPlayer?
    private var targetVolume = menuVolume

    private init() {}

    func play() {
        configureAudioSession()

        if player == nil {
            preparePlayer()
        }

        guard let player, !player.isPlaying else { return }
        player.volume = targetVolume
        player.play()
    }

    func pause() {
        player?.pause()
    }

    func useMenuVolume() {
        setVolume(Self.menuVolume)
    }

    func useGameplayVolume() {
        setVolume(Self.gameplayVolume)
    }

    private func preparePlayer() {
        guard let musicURL = Bundle.main.url(
            forResource: "bg-music",
            withExtension: "mp3"
        ) else { return }

        do {
            let musicPlayer = try AVAudioPlayer(contentsOf: musicURL)
            musicPlayer.numberOfLoops = -1
            musicPlayer.volume = targetVolume
            musicPlayer.prepareToPlay()
            player = musicPlayer
        } catch {
        }
    }

    private func setVolume(_ volume: Float) {
        targetVolume = volume
        player?.setVolume(volume, fadeDuration: Self.volumeTransitionDuration)
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }
}
