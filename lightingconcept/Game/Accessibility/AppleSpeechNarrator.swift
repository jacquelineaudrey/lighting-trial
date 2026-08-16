import AVFoundation
import UIKit

/// Narasi memakai voice bawaan Apple. Ketika VoiceOver aktif, teks dikirim
/// sebagai announcement supaya dua suara sistem tidak berbicara bersamaan.
@MainActor
final class AppleSpeechNarrator {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        stop()
        configureAudioSession()

        let spokenText = sanitizedSpeechText(from: text)
        guard !spokenText.isEmpty else { return }

        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: spokenText)
            return
        }

        let utterance = AVSpeechUtterance(string: spokenText)
        utterance.voice = AVSpeechSynthesisVoice(language: "id-ID")
        utterance.rate = 0.38
        utterance.pitchMultiplier = 1.24
        utterance.volume = 1
        utterance.prefersAssistiveTechnologySettings = true
        synthesizer.speak(utterance)
    }

    private func sanitizedSpeechText(from text: String) -> String {
        let scalars = text.unicodeScalars.filter { scalar in
            !scalar.properties.isEmojiPresentation
                && scalar.properties.generalCategory != .otherSymbol
                && scalar.value != 0xFE0F
        }
        return String(String.UnicodeScalarView(scalars))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // Speech still attempts to play with the current app audio session.
        }
    }

    func stop() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
    }
}
