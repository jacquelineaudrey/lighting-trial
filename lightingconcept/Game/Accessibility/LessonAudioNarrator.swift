import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class LessonAudioNarrator {
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var speechNarrator = AppleSpeechNarrator()

    func speak(_ text: String, audioFileName: String? = nil) {
        stop()

        if let audioFileName,
           let url = Bundle.main.lessonAudioURL(for: audioFileName),
           let nextPlayer = try? AVAudioPlayer(contentsOf: url) {
            player = nextPlayer
            nextPlayer.prepareToPlay()
            nextPlayer.play()
            return
        }

        speechNarrator.speak(text)
    }

    func stop() {
        player?.stop()
        player = nil
        speechNarrator.stop()
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
