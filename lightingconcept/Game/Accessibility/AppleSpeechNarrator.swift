import AVFoundation
import UIKit

/// Narasi memakai voice bawaan Apple. Ketika VoiceOver aktif, teks dikirim
/// sebagai announcement supaya dua suara sistem tidak berbicara bersamaan.
@MainActor
final class AppleSpeechNarrator: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var completion: (() -> Void)?
    private var activeAnnouncement: String?

    override init() {
        super.init()
        synthesizer.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(announcementDidFinish(_:)),
            name: UIAccessibility.announcementDidFinishNotification,
            object: nil
        )
    }

    func speak(_ text: String, onCompletion: (() -> Void)? = nil) {
        stop()
        configureAudioSession()

        let spokenText = sanitizedSpeechText(from: text)
        guard !spokenText.isEmpty else {
            onCompletion?()
            return
        }

        completion = onCompletion

        if UIAccessibility.isVoiceOverRunning {
            activeAnnouncement = spokenText
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

    @objc private func announcementDidFinish(_ notification: Notification) {
        guard let activeAnnouncement else { return }
        if let announcedText = notification.userInfo?[UIAccessibility.announcementStringValueUserInfoKey] as? String,
           announcedText != activeAnnouncement {
            return
        }
        finishSpeaking()
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.finishSpeaking()
        }
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
        completion = nil
        activeAnnouncement = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func finishSpeaking() {
        activeAnnouncement = nil
        let currentCompletion = completion
        completion = nil
        currentCompletion?()
    }
}
