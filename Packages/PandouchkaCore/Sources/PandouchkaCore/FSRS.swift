import Foundation

/// How well a card was remembered.
public enum Rating: Int, CaseIterable, Codable, Sendable {
    case again = 1, hard, good, easy
}

public enum CardPhase: String, Codable, Sendable {
    case new, learning, review, relearning
}

/// Scheduling state of one card in one direction.
public struct Schedule: Codable, Equatable, Sendable {
    public var phase: CardPhase
    public var due: Date
    public var stability: Double
    public var difficulty: Double
    public var reps: Int
    public var lapses: Int
    public var lastReview: Date?

    public init(phase: CardPhase = .new, due: Date = Date(), stability: Double = 0, difficulty: Double = 0,
                reps: Int = 0, lapses: Int = 0, lastReview: Date? = nil) {
        self.phase = phase
        self.due = due
        self.stability = stability
        self.difficulty = difficulty
        self.reps = reps
        self.lapses = lapses
        self.lastReview = lastReview
    }

    public static func fresh(now: Date = Date()) -> Schedule { Schedule(due: now) }
}

/// FSRS-5 spaced repetition (https://github.com/open-spaced-repetition), default weights,
/// with short learning steps for new and forgotten cards.
public struct FSRS: Sendable {
    public static let defaultWeights: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, 0.1192,
        1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621,
    ]
    static let decay = -0.5
    static let factor = 19.0 / 81.0

    public var w: [Double]
    /// Target probability of remembering a card when it comes due.
    public var retention: Double
    public var maximumInterval: Double

    public init(retention: Double = 0.9, maximumInterval: Double = 3650, weights: [Double] = FSRS.defaultWeights) {
        self.w = weights
        self.retention = min(max(retention, 0.7), 0.97)
        self.maximumInterval = maximumInterval
    }

    // MARK: Model

    /// Probability of recall after `days` with stability `s`.
    public static func retrievability(days: Double, stability s: Double) -> Double {
        guard s > 0 else { return 0 }
        return pow(1 + factor * max(days, 0) / s, decay)
    }

    /// Interval in days for which recall falls to the target retention.
    func interval(stability s: Double) -> Double {
        let i = s / FSRS.factor * (pow(retention, 1 / FSRS.decay) - 1)
        return min(max(i.rounded(), 1), maximumInterval)
    }

    func initialStability(_ g: Rating) -> Double { max(w[g.rawValue - 1], 0.1) }

    func initialDifficulty(_ g: Rating) -> Double {
        clampD(w[4] - exp(w[5] * Double(g.rawValue - 1)) + 1)
    }

    func clampD(_ d: Double) -> Double { min(max(d, 1), 10) }

    func nextDifficulty(_ d: Double, _ g: Rating) -> Double {
        let delta = -w[6] * Double(g.rawValue - 3)
        let damped = d + delta * (10 - d) / 9
        let reverted = w[7] * initialDifficulty(.easy) + (1 - w[7]) * damped
        return clampD(reverted)
    }

    func recallStability(d: Double, s: Double, r: Double, g: Rating) -> Double {
        let hard = g == .hard ? w[15] : 1
        let easy = g == .easy ? w[16] : 1
        return s * (exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp(w[10] * (1 - r)) - 1) * hard * easy + 1)
    }

    func forgetStability(d: Double, s: Double, r: Double) -> Double {
        let f = w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp(w[14] * (1 - r))
        return min(f, s)
    }

    func shortTermStability(s: Double, g: Rating) -> Double {
        s * exp(w[17] * (Double(g.rawValue) - 3 + w[18]))
    }

    // MARK: Scheduling

    /// The state after answering a card with rating `g` at `now`.
    public func review(_ c: Schedule, rating g: Rating, now: Date = Date()) -> Schedule {
        var n = c
        n.reps += 1
        n.lastReview = now
        let minute = 60.0
        let day = 86_400.0

        switch c.phase {
        case .new:
            n.stability = initialStability(g)
            n.difficulty = initialDifficulty(g)
            switch g {
            case .again: n.phase = .learning; n.due = now.addingTimeInterval(1 * minute)
            case .hard: n.phase = .learning; n.due = now.addingTimeInterval(6 * minute)
            case .good: n.phase = .learning; n.due = now.addingTimeInterval(10 * minute)
            case .easy:
                n.phase = .review
                n.due = now.addingTimeInterval(interval(stability: n.stability) * day)
            }

        case .learning, .relearning:
            n.stability = max(shortTermStability(s: c.stability, g: g), 0.1)
            n.difficulty = nextDifficulty(c.difficulty, g)
            switch g {
            case .again: n.due = now.addingTimeInterval(5 * minute)
            case .hard: n.due = now.addingTimeInterval(10 * minute)
            case .good, .easy:
                n.phase = .review
                var days = interval(stability: n.stability)
                if g == .easy { days = max(days, 2) }
                n.due = now.addingTimeInterval(days * day)
            }

        case .review:
            let elapsed = c.lastReview.map { now.timeIntervalSince($0) / day } ?? 0
            let r = FSRS.retrievability(days: elapsed, stability: c.stability)
            n.difficulty = nextDifficulty(c.difficulty, g)
            if g == .again {
                n.stability = max(forgetStability(d: c.difficulty, s: c.stability, r: r), 0.1)
                n.lapses += 1
                n.phase = .relearning
                n.due = now.addingTimeInterval(10 * minute)
            } else {
                n.stability = elapsed < 1
                    ? shortTermStability(s: c.stability, g: g)
                    : recallStability(d: c.difficulty, s: c.stability, r: r, g: g)
                n.due = now.addingTimeInterval(interval(stability: n.stability) * day)
            }
        }
        return n
    }

    /// Next due date for every rating, with Hard < Good < Easy enforced for review cards.
    public func preview(_ c: Schedule, now: Date = Date()) -> [Rating: Date] {
        var out: [Rating: Date] = [:]
        for g in Rating.allCases { out[g] = review(c, rating: g, now: now).due }
        if c.phase == .review, let hard = out[.hard], let good = out[.good], let easy = out[.easy] {
            let day = 86_400.0
            let g2 = max(good, hard.addingTimeInterval(day))
            out[.good] = g2
            out[.easy] = max(easy, g2.addingTimeInterval(day))
        }
        return out
    }

    /// Like `review`, but keeps the ordering used by `preview` so buttons match results.
    public func answer(_ c: Schedule, rating g: Rating, now: Date = Date()) -> Schedule {
        var n = review(c, rating: g, now: now)
        if c.phase == .review, g != .again, let due = preview(c, now: now)[g] {
            n.due = due
        }
        return n
    }
}

/// Human interval labels: "1 min", "10 min", "3 d", "2 mo", "1.5 y".
public enum IntervalFormat {
    public static func short(from now: Date, to due: Date) -> String {
        let s = max(due.timeIntervalSince(now), 0)
        let minutes = s / 60
        if minutes < 60 { return "\(max(Int(minutes.rounded()), 1)) min" }
        let hours = minutes / 60
        if hours < 24 { return "\(Int(hours.rounded())) h" }
        let days = hours / 24
        if days < 31 { return "\(Int(days.rounded())) d" }
        if days < 365 { return "\(Int((days / 30.4).rounded())) mo" }
        let years = days / 365
        return years < 10 ? String(format: "%.1f y", years) : "\(Int(years.rounded())) y"
    }
}
