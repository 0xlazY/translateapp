import AVFoundation
import Foundation
import MediaPlayer
import PandouchkaCore

/// Plays a story's recorded narration (`<id>.m4a` + `<id>.timings.json` in the bundle),
/// with seeking, ±10 s skips, speed, sentence tracking and lock-screen controls.
@MainActor
final class StoryPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = StoryPlayer()

    @Published private(set) var storyID: String?
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: TimeInterval = 0
    @Published var currentTime: TimeInterval = 0
    @Published private(set) var currentLine: Int?
    @Published var rate: Float = 1
    /// True while the user drags the slider, so ticks don't fight the thumb.
    var isScrubbing = false

    private var player: AVAudioPlayer?
    private var timing: StoryTiming?
    private var timer: Timer?
    private var title = ""

    static func hasAudio(_ storyID: String) -> Bool {
        Bundle.main.url(forResource: storyID, withExtension: "m4a") != nil
    }

    var isLoaded: Bool { player != nil }

    func load(_ story: Story) {
        guard storyID != story.id else { return }
        stop()
        storyID = story.id
        title = story.title
        guard let url = Bundle.main.url(forResource: story.id, withExtension: "m4a"),
              let p = try? AVAudioPlayer(contentsOf: url) else {
            player = nil
            timing = nil
            duration = 0
            return
        }
        if let t = Bundle.main.url(forResource: story.id + ".timings", withExtension: "json"),
           let data = try? Data(contentsOf: t) {
            timing = try? JSONDecoder().decode(StoryTiming.self, from: data)
        }
        p.enableRate = true
        p.delegate = self
        p.prepareToPlay()
        player = p
        duration = p.duration
        currentTime = 0
        currentLine = nil
        setUpRemoteCommands()
    }

    func play() {
        guard let p = player else { return }
        Speech.shared.stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        p.rate = rate
        p.play()
        isPlaying = true
        startTimer()
        updateNowPlaying()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
        tick()
        updateNowPlaying()
    }

    func toggle() { isPlaying ? pause() : play() }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        timer?.invalidate()
        currentLine = nil
        storyID = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func seek(to time: TimeInterval) {
        guard let p = player else { return }
        p.currentTime = min(max(time, 0), p.duration)
        tick()
        updateNowPlaying()
    }

    func skip(_ seconds: TimeInterval) { seek(to: (player?.currentTime ?? 0) + seconds) }

    /// Jumps to the start of a line and plays from there.
    func play(line: Int) {
        guard let span = timing?.lines[safe: line] else { return }
        seek(to: max(span.start - 0.05, 0))
        if !isPlaying { play() }
    }

    func cycleRate() {
        let steps: [Float] = [1, 0.8, 0.65]
        rate = steps[((steps.firstIndex(of: rate) ?? 0) + 1) % steps.count]
        if isPlaying { player?.rate = rate }
        updateNowPlaying()
    }

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard let p = player else { return }
        if !isScrubbing { currentTime = p.currentTime }
        let line = timing?.line(at: p.currentTime)
        if line != currentLine { currentLine = line }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.timer?.invalidate()
            self.currentTime = self.duration
            self.currentLine = nil
            self.updateNowPlaying()
        }
    }

    // MARK: Lock screen

    private var commandsReady = false

    private func setUpRemoteCommands() {
        guard !commandsReady else { return }
        commandsReady = true
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        c.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggle() }
            return .success
        }
        c.skipBackwardCommand.preferredIntervals = [10]
        c.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(-10) }
            return .success
        }
        c.skipForwardCommand.preferredIntervals = [10]
        c.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(10) }
            return .success
        }
        c.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: e.positionTime) }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let p = player else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "Pandouchka",
            MPMediaItemPropertyPlaybackDuration: p.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: p.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(rate) : 0,
        ]
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

enum TimeFormat {
    static func clock(_ t: TimeInterval) -> String {
        let s = max(Int(t.rounded(.down)), 0)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
