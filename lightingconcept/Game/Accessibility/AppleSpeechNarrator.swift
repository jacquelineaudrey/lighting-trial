import AVFoundation
import UIKit

/// Narasi memakai voice bawaan Apple. Ketika VoiceOver aktif, teks dikirim
/// sebagai announcement supaya dua suara sistem tidak berbicara bersamaan.
@MainActor
final class AppleSpeechNarrator {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        stop()

        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: text)
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "id-ID")
        utterance.rate = 0.44
        utterance.pitchMultiplier = 1.05
        utterance.volume = 1
        utterance.prefersAssistiveTechnologySettings = true
        synthesizer.speak(utterance)
    }

    func stop() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
    }
}
