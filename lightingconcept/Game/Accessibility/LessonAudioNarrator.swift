import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class LessonAudioNarrator {
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var speechNarrator = AppleSpeechNarrator()
    @ObservationIgnored private var playbackTask: Task<Void, Never>?

    func speak(_ text: String, audioFileName: String? = nil, onCompletion: (() -> Void)? = nil) {
        speak(text, audioFileNames: audioFileName.map { [$0] } ?? [], onCompletion: onCompletion)
    }

    func speak(_ text: String, audioFileNames: [String], onCompletion: (() -> Void)? = nil) {
        stop()
        configureAudioSession()

        guard !audioFileNames.isEmpty else {
            speechNarrator.speak(text)
            playbackTask = Task { @MainActor in
                let estimatedDuration = max(Double(text.split(separator: " ").count) * 0.38, 0.8)
                try? await Task.sleep(nanoseconds: UInt64(estimatedDuration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                onCompletion?()
            }
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
            nextPlayer.play()
            didPlayAudio = true

            let duration = max(nextPlayer.duration, 0.1)
            try? await Task.sleep(nanoseconds: UInt64((duration + 0.12) * 1_000_000_000))
        }

        guard !Task.isCancelled else { return }

        if !didPlayAudio {
            speechNarrator.speak(fallbackText)
            let estimatedDuration = max(Double(fallbackText.split(separator: " ").count) * 0.38, 0.8)
            try? await Task.sleep(nanoseconds: UInt64(estimatedDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
        }

        onCompletion?()
    }

    func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        player?.stop()
        player = nil
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
