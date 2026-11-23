import SwiftData
import SwiftUI
import PandouchkaCore

struct StoriesView: View {
    @Query private var progress: [StoryProgress]
    @Query private var cards: [Card]
    @Query private var known: [KnownWord]
    @State private var level: Level? = nil

    private var stories: [Story] {
        StoryLibrary.all.filter { level == nil || $0.level == level }
    }

    private var familiarKeys: Set<String> {
        Set(cards.map(\.key)).union(known.map(\.key))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    levelPicker
                    ForEach(Level.allCases.filter { l in stories.contains { $0.level == l } }, id: \.self) { l in
                        Text(levelTitle(l))
                            .font(Fonts.display(22))
                            .foregroundStyle(Palette.ink)
                            .padding(.top, 6)
                        ForEach(stories.filter { $0.level == l }) { story in
                            NavigationLink(value: story) {
                                StoryRow(story: story, progress: progress.first { $0.storyID == story.id },
                                         familiar: familiarKeys)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
            .background(Palette.paper.ignoresSafeArea())
            .navigationTitle("Stories")
            .navigationDestination(for: Story.self) { ReaderView(story: $0) }
        }
    }

    private func levelTitle(_ l: Level) -> String {
        switch l {
        case .a1: return "A1 · First steps"
        case .a2: return "A2 · Everyday life"
        case .b1: return "B1 · Independent"
        }
    }

    private var levelPicker: some View {
        HStack(spacing: 8) {
            levelButton(nil, "All")
            ForEach(Level.allCases.filter { l in StoryLibrary.all.contains { $0.level == l } }, id: \.self) { l in
                levelButton(l, l.rawValue)
            }
            Spacer()
        }
    }

    private func levelButton(_ l: Level?, _ title: String) -> some View {
        Button { withAnimation(.snappy) { level = l } } label: {
            Chip(text: title, color: Palette.ink, filled: level == l)
        }
        .buttonStyle(.plain)
    }
}

struct StoryCover: View {
    let story: Story
    var size: CGFloat = 76
    var body: some View {
        let c = Palette.theme(story.theme)
        ZStack {
            LinearGradient(colors: [c.opacity(0.85), c], startPoint: .topLeading, endPoint: .bottomTrailing)
            // Diagonal stripes, a quiet echo of the flags.
            GeometryReader { g in
                Path { p in
                    let step: CGFloat = size / 5
                    var x: CGFloat = -g.size.height
                    while x < g.size.width {
                        p.move(to: CGPoint(x: x, y: g.size.height))
                        p.addLine(to: CGPoint(x: x + g.size.height, y: 0))
                        x += step
                    }
                }
                .stroke(Color.white.opacity(0.10), lineWidth: size / 14)
            }
            Text(story.emoji).font(.system(size: size * 0.46))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
    }
}

struct StoryRow: View {
    let story: Story
    let progress: StoryProgress?
    let familiar: Set<String>

    private var coverage: Double {
        let keys = story.wordKeys
        guard !keys.isEmpty else { return 0 }
        // Count a word as familiar if its own spelling or its dictionary form is known.
        let hits = keys.filter { k in
            familiar.contains(k) || (RussianDictionary.shared.lookup(k).first.map { familiar.contains($0.entry.key) } ?? false)
        }
        return Double(hits.count) / Double(keys.count)
    }

    var body: some View {
        HStack(spacing: 14) {
            StoryCover(story: story)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(story.title).font(Fonts.display(19)).foregroundStyle(Palette.ink)
                    if progress?.completedAt != nil {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.green)
                    }
                }
                Text(story.titleFr).font(Fonts.ui(.subheadline)).foregroundStyle(Palette.muted)
                HStack(spacing: 8) {
                    Text("\(story.wordCount) words").font(Fonts.ui(.caption)).foregroundStyle(Palette.muted)
                    CoverageBar(value: coverage).frame(width: 60, height: 5)
                    Text("\(Int(coverage * 100))% familiar").font(Fonts.ui(.caption)).foregroundStyle(Palette.muted)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .card()
    }
}

struct CoverageBar: View {
    var value: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.sunken)
                Capsule().fill(Palette.green).frame(width: g.size.width * min(max(value, 0), 1))
            }
        }
    }
}
