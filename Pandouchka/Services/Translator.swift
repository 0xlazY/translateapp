import Foundation
import SwiftUI
import Translation

enum Lang: String {
    case russian = "ru"
    case french = "fr"
    var language: Locale.Language { Locale.Language(identifier: rawValue) }
}

/// Bridges Apple's on-device Translation framework, whose sessions only exist inside a
/// `.translationTask` modifier, to plain async calls. Language packs are downloaded by the
/// system on first use (it asks for confirmation); afterwards translation works offline.
@MainActor
final class Translator: ObservableObject {
    static let shared = Translator()

    @Published var configuration: TranslationSession.Configuration?
    @Published var lastError: String?

    private struct Job {
        let text: String
        let source: Lang
        let target: Lang
        let continuation: CheckedContinuation<String, Error>
    }

    private var jobs: [Job] = []
    private var cache: [String: String] = [:]

    func translate(_ text: String, from source: Lang, to target: Lang) async throws -> String {
        let cacheKey = "\(source.rawValue)>\(target.rawValue):\(text)"
        if let hit = cache[cacheKey] { return hit }
        let result = try await withCheckedThrowingContinuation { (c: CheckedContinuation<String, Error>) in
            jobs.append(Job(text: text, source: source, target: target, continuation: c))
            trigger(source: source, target: target)
        }
        cache[cacheKey] = result
        return result
    }

    private func trigger(source: Lang, target: Lang) {
        if var current = configuration, current.source == source.language, current.target == target.language {
            current.invalidate()
            configuration = current
        } else {
            configuration = TranslationSession.Configuration(source: source.language, target: target.language)
        }
    }

    /// Called from `.translationTask` with a live session.
    func run(_ session: TranslationSession) async {
        guard let config = configuration else { return }
        let batch = jobs.filter { $0.source.language == config.source && $0.target.language == config.target }
        jobs.removeAll { $0.source.language == config.source && $0.target.language == config.target }
        for job in batch {
            do {
                let response = try await session.translate(job.text)
                job.continuation.resume(returning: response.targetText)
            } catch {
                lastError = error.localizedDescription
                job.continuation.resume(throwing: error)
            }
        }
        if let next = jobs.first {
            trigger(source: next.source, target: next.target)
        }
    }
}

/// Attach once near the root so translations work from any screen.
struct TranslationHost: ViewModifier {
    @ObservedObject var translator: Translator
    func body(content: Content) -> some View {
        content.translationTask(translator.configuration) { session in
            await translator.run(session)
        }
    }
}
