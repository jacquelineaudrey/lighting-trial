import AVFoundation
import Foundation

/// Memutar BGM menu atau gameplay sesuai layar yang sedang aktif.
@MainActor
final class BackgroundMusicPlayer {
    static let shared = BackgroundMusicPlayer()

    private enum Track: String {
        case menu = "bg-music-main menu"
        case gameplay = "bg-music"
    }

    private static let defaultMenuVolume = 1.0
    private static let defaultGameplayVolume = 0.4
    private static let volumeTransitionDuration: TimeInterval = 0.25
    private static let menuVolumeDefaultsKey = "audio.menuVolume"
    private static let gameplayVolumeDefaultsKey = "audio.gameplayVolume"

    private let defaults: UserDefaults
    private var player: AVAudioPlayer?
    private var currentTrack = Track.menu
    private var loadedTrack: Track?
    private var pendingLoadTracks: Set<Track> = []
    private var targetVolume: Float
    private var trackTransitionTask: Task<Void, Never>?
    private var isPlaybackRequested = false

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
        isPlaybackRequested = true
        configureAudioSession()

        guard trackTransitionTask == nil else { return }

        startCurrentTrack(fadesIn: false)
    }

    func pause() {
        isPlaybackRequested = false
        player?.pause()
    }

    func playMenuMusic() {
        play(track: .menu, volume: menuVolume)
    }

    func playGameplayMusic() {
        play(track: .gameplay, volume: gameplayVolume)
    }

    func updateMenuVolume(_ volume: Double) {
        menuVolume = Self.clamped(volume)
        defaults.set(menuVolume, forKey: Self.menuVolumeDefaultsKey)

        if currentTrack == .menu {
            setPlayerVolume(menuVolume)
        }
    }

    func updateGameplayVolume(_ volume: Double) {
        gameplayVolume = Self.clamped(volume)
        defaults.set(gameplayVolume, forKey: Self.gameplayVolumeDefaultsKey)

        if currentTrack == .gameplay {
            setPlayerVolume(gameplayVolume)
        }
    }

    private func play(track: Track, volume: Double) {
        let didChangeTrack = currentTrack != track
        currentTrack = track
        targetVolume = Float(Self.clamped(volume))
        isPlaybackRequested = true
        configureAudioSession()

        guard didChangeTrack else {
            if trackTransitionTask == nil {
                startCurrentTrack(fadesIn: false)
            }
            return
        }

        trackTransitionTask?.cancel()

        guard let previousPlayer = player, previousPlayer.isPlaying else {
            resetLoadedPlayer()
            startCurrentTrack(fadesIn: false)
            return
        }

        previousPlayer.setVolume(0, fadeDuration: Self.volumeTransitionDuration)
        trackTransitionTask = Task { [weak self, weak previousPlayer] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let self else { return }

            previousPlayer?.stop()
            if self.player === previousPlayer {
                self.player = nil
                self.loadedTrack = nil
            }
            self.trackTransitionTask = nil
            self.startCurrentTrack(fadesIn: true)
        }
    }

    private func startCurrentTrack(fadesIn: Bool) {
        let track = currentTrack

        if let player, loadedTrack == track {
            apply(player, fadesIn: fadesIn)
            return
        }

        guard !pendingLoadTracks.contains(track) else { return }
        loadPlayer(for: track) { [weak self] loadedPlayer in
            guard let self, self.currentTrack == track else { return }
            guard let loadedPlayer else { return }
            self.player = loadedPlayer
            self.loadedTrack = track
            self.apply(loadedPlayer, fadesIn: fadesIn)
        }
    }

    private func apply(_ player: AVAudioPlayer, fadesIn: Bool) {
        player.volume = fadesIn ? 0 : targetVolume
        if isPlaybackRequested, !player.isPlaying {
            player.play()
        }
        if fadesIn, isPlaybackRequested {
            player.setVolume(targetVolume, fadeDuration: Self.volumeTransitionDuration)
        }
    }

    private func resetLoadedPlayer() {
        player?.stop()
        player = nil
        loadedTrack = nil
        trackTransitionTask = nil
    }

    /// Membaca dan menyiapkan berkas BGM di background thread supaya tidak
    /// memblokir main thread (mis. saat launch) dengan I/O membaca berkas mp3.
    private func loadPlayer(for track: Track, completion: @escaping (AVAudioPlayer?) -> Void) {
        guard let musicURL = Bundle.main.url(
            forResource: track.rawValue,
            withExtension: "mp3"
        ) else {
            assertionFailure("BGM resource not found: \(track.rawValue).mp3")
            completion(nil)
            return
        }

        pendingLoadTracks.insert(track)
        Task.detached(priority: .utility) {
            let preparedPlayer: AVAudioPlayer?
            do {
                let musicPlayer = try AVAudioPlayer(contentsOf: musicURL)
                musicPlayer.numberOfLoops = -1
                musicPlayer.prepareToPlay()
                preparedPlayer = musicPlayer
            } catch {
                assertionFailure("Failed to prepare BGM \(track.rawValue): \(error)")
                preparedPlayer = nil
            }

            await MainActor.run { [weak self] in
                self?.pendingLoadTracks.remove(track)
                completion(preparedPlayer)
            }
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
