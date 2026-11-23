import SwiftData
import SwiftUI
import PandouchkaCore

/// The story list, laid out like the contents page of a reader.
struct StoriesView: View {
    @Query private var progress: [StoryProgress]
    @Query private var cards: [Card]
    @Query private var known: [KnownWord]

    private var familiarKeys: Set<String> {
        Set(cards.map(\.key)).union(known.map(\.key))
    }

    private var levels: [Level] {
        Level.allCases.filter { l in StoryLibrary.all.contains { $0.level == l } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Contents")
                        .font(Fonts.display(38))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 8)
                    Text("Оглавление")
                        .font(Fonts.italic(16))
                        .foregroundStyle(Palette.pen)
                        .padding(.bottom, 8)
                    let familiar = familiarKeys
                    ForEach(levels, id: \.self) { level in
                        HStack(alignment: .firstTextBaseline) {
                            Eyebrow(level.rawValue, color: Palette.margin)
                            Eyebrow(levelTitle(level))
                        }
                        .padding(.top, 26)
                        .padding(.bottom, 6)
                        ForEach(numbered(level)) { item in
                            let story = item.story
                            NavigationLink(value: story) {
                                ContentsRow(number: item.number, story: story,
                                            done: progress.first { $0.storyID == story.id }?.completedAt != nil,
                                            familiar: familiar)
                            }
                            .buttonStyle(.plain)
                            Rule()
                        }
                    }
                }
                .padding(.leading, 44)
                .padding(.trailing, 20)
                .padding(.bottom, 40)
            }
            .background(NotebookPaper())
            .navigationDestination(for: Story.self) { ReaderView(story: $0) }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    struct NumberedStory: Identifiable {
        let number: Int
        let story: Story
        var id: String { story.id }
    }

    private func numbered(_ level: Level) -> [NumberedStory] {
        StoryLibrary.all.enumerated().filter { $0.element.level == level }
            .map { NumberedStory(number: $0.offset + 1, story: $0.element) }
    }

    private func levelTitle(_ l: Level) -> String {
        switch l {
        case .a1: return "First steps"
        case .a2: return "Everyday life"
        case .b1: return "On your own"
        }
    }
}

struct ContentsRow: View {
    let number: Int
    let story: Story
    let done: Bool
    let familiar: Set<String>

    private var coverage: Int {
        let keys = story.wordKeys
        guard !keys.isEmpty else { return 0 }
        let hits = keys.filter { k in
            familiar.contains(k) || (RussianDictionary.shared.lookup(k).first.map { familiar.contains($0.entry.key) } ?? false)
        }
        return Int((Double(hits.count) / Double(keys.count) * 100).rounded())
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(String(format: "%02d", number))
                .font(Fonts.display(22, weight: .light))
                .foregroundStyle(done ? Palette.muted : Palette.margin)
                .frame(width: 32, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(story.title)
                    .font(Fonts.display(20))
                    .foregroundStyle(Palette.ink)
                Text(story.titleFr)
                    .font(Fonts.italic(15))
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                if done {
                    Text("read ✓").font(Fonts.italic(15)).foregroundStyle(Palette.pen)
                } else {
                    Text("\(story.wordCount) words").font(Fonts.italic(13)).foregroundStyle(Palette.muted)
                }
                if coverage > 0 {
                    Text("\(coverage)% known").font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
