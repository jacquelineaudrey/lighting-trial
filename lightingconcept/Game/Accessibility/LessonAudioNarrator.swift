import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class LessonAudioNarrator: NSObject, AVAudioPlayerDelegate {
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var speechNarrator = AppleSpeechNarrator()
    @ObservationIgnored private var playbackTask: Task<Void, Never>?
    @ObservationIgnored private var audioCompletion: CheckedContinuation<Bool, Never>?

    override init() {
        super.init()
    }

    func speak(_ text: String, audioFileName: String? = nil, onCompletion: (() -> Void)? = nil) {
        speak(text, audioFileNames: audioFileName.map { [$0] } ?? [], onCompletion: onCompletion)
    }

    func speak(_ text: String, audioFileNames: [String], onCompletion: (() -> Void)? = nil) {
        stop()
        configureAudioSession()

        guard !audioFileNames.isEmpty else {
            speechNarrator.speak(text, onCompletion: onCompletion)
            return
        }

        playbackTask = Task { [weak self] in
            await self?.playAudioSequence(audioFileNames, fallbackText: text, onCompletion: onCompletion)
        }
    }

    private func playAudioSequence(_ audioFileNames: [String], fallbackText: String, onCompletion: (() -> Void)?) async {
        var didPlayAudio = false

        for audioFileName in audioFileNames {
            guard !Task.isCancelled,
                  let url = Bundle.main.lessonAudioURL(for: audioFileName),
                  let nextPlayer = try? AVAudioPlayer(contentsOf: url) else {
                continue
            }

            player = nextPlayer
            nextPlayer.prepareToPlay()
            let didFinish = await playToCompletion(nextPlayer)
            guard !Task.isCancelled else { return }
            if didFinish {
                didPlayAudio = true
            }
        }

        guard !Task.isCancelled else { return }

        if !didPlayAudio {
            speechNarrator.speak(fallbackText, onCompletion: onCompletion)
            return
        }

        player = nil
        onCompletion?()
    }

    private func playToCompletion(_ audioPlayer: AVAudioPlayer) async -> Bool {
        await withCheckedContinuation { continuation in
            audioCompletion = continuation
            audioPlayer.delegate = self
            guard audioPlayer.play() else {
                finishAudioPlayback(successfully: false)
                return
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.finishAudioPlayback(successfully: flag)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            self?.finishAudioPlayback(successfully: false)
        }
    }

    private func finishAudioPlayback(successfully: Bool) {
        player?.delegate = nil
        let continuation = audioCompletion
        audioCompletion = nil
        continuation?.resume(returning: successfully)
    }

    func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        player?.delegate = nil
        player?.stop()
        player = nil
        let continuation = audioCompletion
        audioCompletion = nil
        continuation?.resume(returning: false)
        speechNarrator.stop()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)
    }
}

private extension Bundle {
    func lessonAudioURL(for audioFileName: String) -> URL? {
        let normalizedName = audioFileName.hasPrefix("Audio/")
            ? String(audioFileName.dropFirst("Audio/".count))
            : audioFileName
        let resourceURL = URL(fileURLWithPath: normalizedName)
        let resourceName = resourceURL.deletingPathExtension().lastPathComponent
        let resourceExtension = resourceURL.pathExtension
        let resourceDirectory = (normalizedName as NSString).deletingLastPathComponent
        let subdirectory = resourceDirectory.isEmpty ? "Audio" : "Audio/" + resourceDirectory

        if let url = url(forResource: resourceName, withExtension: resourceExtension, subdirectory: subdirectory) {
            return url
        }

        if let url = url(forResource: resourceName, withExtension: resourceExtension) {
            return url
        }

        guard let enumerator = FileManager.default.enumerator(at: bundleURL, includingPropertiesForKeys: nil) else {
            return nil
        }

        for case let url as URL in enumerator where url.lastPathComponent == resourceURL.lastPathComponent {
            return url
        }

        return nil
    }
}
