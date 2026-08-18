import AVFoundation
import Foundation

/// Memutar satu BGM yang terus digunakan selama aplikasi berjalan.
@MainActor
final class BackgroundMusicPlayer {
    static let shared = BackgroundMusicPlayer()

    private static let defaultMenuVolume = 1.0
    private static let defaultGameplayVolume = 0.4
    private static let volumeTransitionDuration: TimeInterval = 0.25
    private static let menuVolumeDefaultsKey = "audio.menuVolume"
    private static let gameplayVolumeDefaultsKey = "audio.gameplayVolume"

    private let defaults: UserDefaults
    private var player: AVAudioPlayer?
    private var targetVolume: Float
    private var isUsingGameplayVolume = false

    private(set) var menuVolume: Double
    private(set) var gameplayVolume: Double

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let savedMenuVolume = defaults.object(forKey: Self.menuVolumeDefaultsKey) == nil
            ? Self.defaultMenuVolume
            : defaults.double(forKey: Self.menuVolumeDefaultsKey)
        let savedGameplayVolume = defaults.object(forKey: Self.gameplayVolumeDefaultsKey) == nil
            ? Self.defaultGameplayVolume
            : defaults.double(forKey: Self.gameplayVolumeDefaultsKey)

        menuVolume = Self.clamped(savedMenuVolume)
        gameplayVolume = Self.clamped(savedGameplayVolume)
        targetVolume = Float(menuVolume)
    }

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
        isUsingGameplayVolume = false
        setPlayerVolume(menuVolume)
    }

    func useGameplayVolume() {
        isUsingGameplayVolume = true
        setPlayerVolume(gameplayVolume)
    }

    func updateMenuVolume(_ volume: Double) {
        menuVolume = Self.clamped(volume)
        defaults.set(menuVolume, forKey: Self.menuVolumeDefaultsKey)

        if !isUsingGameplayVolume {
            setPlayerVolume(menuVolume)
        }
    }

    func updateGameplayVolume(_ volume: Double) {
        gameplayVolume = Self.clamped(volume)
        defaults.set(gameplayVolume, forKey: Self.gameplayVolumeDefaultsKey)

        if isUsingGameplayVolume {
            setPlayerVolume(gameplayVolume)
        }
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

    private func setPlayerVolume(_ volume: Double) {
        let playerVolume = Float(Self.clamped(volume))
        targetVolume = playerVolume
        player?.setVolume(playerVolume, fadeDuration: Self.volumeTransitionDuration)
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    private static func clamped(_ volume: Double) -> Double {
        min(max(volume, 0), 1)
    }
}
