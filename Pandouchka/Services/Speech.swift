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

    /// Speaks one piece of text, interrupting anything playing. A single Russian word
    /// uses the recorded word pack when it has it.
    func say(_ text: String, lang: Lang = .russian, id: String? = nil, slow: Bool = false) {
        stop()
        if lang == .russian, let url = WordAudio.url(for: text) {
            playLocal(url)
            return
        }
        enqueue(text, lang: lang, id: id ?? UUID().uuidString, slow: slow)
    }

    private var local: AVAudioPlayer?

    func playLocal(_ url: URL) {
        activateAudio()
        local = try? AVAudioPlayer(contentsOf: url)
        local?.play()
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
        local?.stop()
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

/// Offline word recordings (Silero), made by tools/make_word_audio.py.
enum WordAudio {
    static let folder = Bundle.main.url(forResource: "WordAudio", withExtension: nil)

    /// File for a single word, looked up by its dictionary key.
    static func url(for text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard let folder, !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        let name = RussianText.key(trimmed).utf8.map { String(format: "%02x", $0) }.joined()
        let url = folder.appendingPathComponent(name + ".m4a")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
