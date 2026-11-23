import AVFoundation
import Foundation
import PandouchkaCore

/// Text to speech (system voices, offline) and Wiktionary recordings (online).
@MainActor
final class Speech: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = Speech()

    /// UTF-16 range being spoken in the current utterance, for highlighting.
    @Published var spokenRange: NSRange?
    @Published var speakingID: String?

    private let synth = AVSpeechSynthesizer()
    private var player: AVPlayer?
    private var queue: [(id: String, text: String, lang: Lang)] = []
    private var currentID: String?

    var rate: Float {
        let v = UserDefaults.standard.double(forKey: Prefs.speechRate)
        return Float(v == 0 ? 0.42 : v)
    }

    override init() {
        super.init()
        synth.delegate = self
    }

    private func activateAudio() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    static func voice(for lang: Lang) -> AVSpeechSynthesisVoice? {
        let code = lang == .russian ? "ru-RU" : "fr-FR"
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == code }
        return voices.max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: code)
    }

    /// Speaks one piece of text, interrupting anything playing.
    func say(_ text: String, lang: Lang = .russian, id: String? = nil, slow: Bool = false) {
        stop()
        enqueue(text, lang: lang, id: id ?? UUID().uuidString, slow: slow)
    }

    /// Speaks several pieces one after the other (e.g. the lines of a story).
    func sayAll(_ items: [(id: String, text: String)], lang: Lang = .russian) {
        stop()
        for item in items { enqueue(item.text, lang: lang, id: item.id) }
    }

    private func enqueue(_ text: String, lang: Lang, id: String, slow: Bool = false) {
        activateAudio()
        let u = AVSpeechUtterance(string: RussianText.stripStress(text))
        u.voice = Speech.voice(for: lang)
        u.rate = slow ? max(rate - 0.15, 0.2) : rate
        queue.append((id, text, lang))
        synth.speak(u)
    }

    func stop() {
        queue.removeAll()
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        player?.pause()
        spokenRange = nil
        speakingID = nil
    }

    var isSpeaking: Bool { synth.isSpeaking }

    func play(url: URL) {
        stop()
        activateAudio()
        player = AVPlayer(url: url)
        player?.play()
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) {
        Task { @MainActor in
            if !self.queue.isEmpty { self.speakingID = self.queue[0].id }
        }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, willSpeakRangeOfSpeechString r: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor in self.spokenRange = r }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in
            if !self.queue.isEmpty { self.queue.removeFirst() }
            self.spokenRange = nil
            self.speakingID = self.queue.first?.id
        }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        Task { @MainActor in
            self.spokenRange = nil
        }
    }
}
