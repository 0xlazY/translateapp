import SwiftData
import SwiftUI
import PandouchkaCore

/// A word tapped in a text, with the sentence around it.
struct WordSelection: Identifiable, Hashable {
    let word: String
    let sentence: String
    let translation: String
    let source: String
    /// Index of the sentence in the story, for "play this sentence".
    var line: Int? = nil
    var id: String { "\(source)|\(line ?? -1)|\(sentence)|\(word)" }
}

/// One wrapped unit in the reader: a word with the punctuation stuck to it.
struct Chunk: Hashable {
    var prefix: String = ""
    var word: Token?
    var suffix: String = ""
    var standalone: String?

    /// Splits a sentence so punctuation never starts a line.
    static func chunks(_ text: String) -> [Chunk] {
        var out: [Chunk] = []
        var pending = ""
        for t in Tokenizer.tokenize(text) {
            if t.isWord {
                out.append(Chunk(prefix: pending, word: t))
                pending = ""
                continue
            }
            let pieces = t.text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
            if pieces.count == 1 {
                if out.isEmpty { pending += pieces[0] } else { out[out.count - 1].suffix += pieces[0] }
                continue
            }
            if !pieces[0].isEmpty {
                if out.isEmpty { pending += pieces[0] } else { out[out.count - 1].suffix += pieces[0] }
            }
            for middle in pieces.dropFirst().dropLast() where !middle.isEmpty {
                out.append(Chunk(standalone: middle))
            }
            pending += pieces.last ?? ""
        }
        if !pending.isEmpty {
            if out.isEmpty { out.append(Chunk(standalone: pending)) } else { out[out.count - 1].suffix += pending }
        }
        return out
    }
}

struct ReaderView: View {
    let story: Story

    @Environment(\.modelContext) private var context
    @Query private var cards: [Card]
    @Query private var known: [KnownWord]
    @Query private var progressRows: [StoryProgress]
    @ObservedObject private var player = StoryPlayer.shared
    @AppStorage(Prefs.showStress) private var showStress = true
    @AppStorage(Prefs.readerSize) private var fontSize = 22.0
    @AppStorage(Prefs.showLineTranslation) private var showTranslations = false

    @State private var selection: WordSelection?
    @State private var lemma: [String: String] = [:]
    @State private var showQuiz = false
    @State private var showVocabulary = false

    private var progress: StoryProgress? { progressRows.first { $0.storyID == story.id } }
    private var number: Int { (StoryLibrary.all.firstIndex { $0.id == story.id } ?? 0) + 1 }

    private var cardsByKey: [String: Card] {
        var d: [String: Card] = [:]
        for c in cards where d[c.key] == nil { d[c.key] = c }
        return d
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if !story.keywords.isEmpty { vocabulary }
                    let cardMap = cardsByKey
                    let knownSet = Set(known.map(\.key))
                    ForEach(Array(story.lines.enumerated()), id: \.offset) { i, line in
                        lineView(i, line, cardMap: cardMap, knownSet: knownSet)
                            .id(i)
                            .padding(.top, line.paragraph == true ? 20 : 4)
                    }
                    ending
                }
                .padding(.leading, 44)
                .padding(.trailing, 20)
                .padding(.bottom, 60)
            }
            .onChange(of: player.currentLine) { _, line in
                guard player.isPlaying, player.storyID == story.id, let line else { return }
                withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(line, anchor: .center) }
            }
        }
        .background(NotebookPaper())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .safeAreaInset(edge: .bottom) { PlayerBar(story: story) }
        .sheet(item: $selection) { sel in
            WordSheet(selection: sel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQuiz) {
            QuizView(story: story) { finish(score: $0) }
        }
        .task { prepare() }
        .onDisappear { player.pause() }
    }

    private func prepare() {
        player.load(story)
        if progress == nil {
            context.insert(StoryProgress(storyID: story.id))
            try? context.save()
        }
        var map: [String: String] = [:]
        for key in story.wordKeys {
            map[key] = RussianDictionary.shared.lookup(key).first?.entry.key ?? key
        }
        lemma = map
    }

    private func stressed(_ s: String) -> String {
        guard showStress else { return s }
        return Tokenizer.tokenize(s).map { $0.isWord ? RussianDictionary.shared.stressed($0.text) : $0.text }.joined()
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("№ \(number)")
                .font(Fonts.italic(16))
                .foregroundStyle(Palette.margin)
            Text(stressed(story.title))
                .font(Fonts.display(34))
                .foregroundStyle(Palette.ink)
            Text(story.titleFr)
                .font(Fonts.italic(18))
                .foregroundStyle(Palette.pen)
            HStack(spacing: 8) {
                Eyebrow(story.level.rawValue, color: Palette.margin)
                Eyebrow("\(story.wordCount) words")
                if player.duration > 0, player.storyID == story.id {
                    Eyebrow(TimeFormat.clock(player.duration))
                }
            }
            .padding(.top, 6)
        }
        .padding(.top, 4)
        .padding(.bottom, 18)
    }

    private var vocabulary: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy) { showVocabulary.toggle() }
            } label: {
                HStack {
                    Eyebrow("Vocabulary", color: Palette.pen)
                    Spacer()
                    Image(systemName: showVocabulary ? "minus" : "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.pen)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showVocabulary {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(story.keywords, id: \.ru) { k in
                        Button {
                            selection = WordSelection(word: k.ru, sentence: "", translation: "", source: story.id)
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                Text(stressed(k.ru)).font(Fonts.reading(18)).foregroundStyle(Palette.ink)
                                Spacer()
                                Text(k.fr).font(Fonts.italic(15)).foregroundStyle(Palette.pen)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.pen.opacity(0.35), lineWidth: 1))
        .padding(.bottom, 18)
    }

    // MARK: Text

    private func lineView(_ i: Int, _ line: Story.Line, cardMap: [String: Card], knownSet: Set<String>) -> some View {
        let reading = player.storyID == story.id && player.currentLine == i && (player.isPlaying || player.currentTime > 0)
        return VStack(alignment: .leading, spacing: 4) {
            FlowLayout(spacing: 0, lineSpacing: fontSize * 0.4) {
                ForEach(Array(Chunk.chunks(line.ru).enumerated()), id: \.offset) { _, chunk in
                    chunkView(chunk, line: line, index: i, cardMap: cardMap, knownSet: knownSet)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Palette.highlighter.opacity(reading ? 0.85 : 0))
                    .padding(.horizontal, -5)
                    .padding(.vertical, -2)
            )
            .animation(.easeInOut(duration: 0.25), value: reading)
            if showTranslations {
                Text(line.fr)
                    .font(Fonts.italic(15))
                    .foregroundStyle(Palette.pen)
                    .padding(.bottom, 4)
            }
        }
    }

    private func chunkView(_ chunk: Chunk, line: Story.Line, index: Int, cardMap: [String: Card], knownSet: Set<String>) -> some View {
        HStack(spacing: 0) {
            if !chunk.prefix.isEmpty { plain(chunk.prefix) }
            if let w = chunk.word {
                wordView(w, line: line, index: index, cardMap: cardMap, knownSet: knownSet)
            }
            if let s = chunk.standalone { plain(s) }
            if !chunk.suffix.isEmpty { plain(chunk.suffix) }
            Text(" ").font(Fonts.reading(fontSize))
        }
    }

    private func plain(_ s: String) -> some View {
        Text(s).font(Fonts.reading(fontSize)).foregroundStyle(Palette.ink)
    }

    private func wordView(_ t: Token, line: Story.Line, index: Int, cardMap: [String: Card], knownSet: Set<String>) -> some View {
        let k = RussianText.key(t.text)
        let lk = lemma[k] ?? k
        let card = cardMap[lk] ?? cardMap[k]
        let isKnown = knownSet.contains(lk) || knownSet.contains(k)
        let selected = selection?.word == t.text && selection?.line == index
        let shown = showStress ? RussianDictionary.shared.stressed(t.text) : t.text
        let underline: Color? = card.map { $0.retrievability.map(Palette.memory) ?? Palette.margin }

        return Text(shown)
            .font(Fonts.reading(fontSize))
            .foregroundStyle(selected ? Palette.pen : (isKnown ? Palette.ink.opacity(0.7) : Palette.ink))
            .underline(underline != nil || selected, color: selected ? Palette.pen : underline)
            .contentShape(Rectangle())
            .onTapGesture {
                selection = WordSelection(word: t.text, sentence: line.ru, translation: line.fr, source: story.id, line: index)
            }
            .accessibilityAddTraits(.isButton)
    }

    // MARK: End of story

    private var ending: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                Text("❧").font(.system(size: 22)).foregroundStyle(Palette.margin)
                Spacer()
            }
            .padding(.vertical, 26)
            if let done = progress?.completedAt {
                Text("Read on \(done.formatted(date: .long, time: .omitted))" + (progress?.quizScore.map { " · quiz \($0)/\(story.questions.count)" } ?? ""))
                    .font(Fonts.italic(15))
                    .foregroundStyle(Palette.pen)
            }
            if !story.questions.isEmpty {
                Button(progress?.completedAt == nil ? "Check your understanding" : "Take the quiz again") { showQuiz = true }
                    .buttonStyle(InkButtonStyle())
            }
            if progress?.completedAt == nil {
                Button("Mark as read") { finish(score: nil) }
                    .buttonStyle(OutlineButtonStyle())
            }
        }
    }

    private func finish(score: Int?) {
        let p = progress ?? {
            let p = StoryProgress(storyID: story.id)
            context.insert(p)
            return p
        }()
        p.completedAt = p.completedAt ?? Date()
        if let score { p.quizScore = score }
        p.furthestLine = story.lines.count
        try? context.save()
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Toggle("French translation", isOn: $showTranslations)
                Toggle("Stress marks", isOn: $showStress)
                Section("Text size") {
                    Button("Smaller") { fontSize = max(fontSize - 2, 16) }
                    Button("Larger") { fontSize = min(fontSize + 2, 34) }
                }
            } label: {
                Image(systemName: "textformat")
            }
            .tint(Palette.ink)
        }
    }
}

/// Narration controls: a scrubbable timeline, play/pause, ±10 s and speed.
struct PlayerBar: View {
    let story: Story
    @ObservedObject private var player = StoryPlayer.shared
    @State private var dragValue: Double?

    private var active: Bool { player.storyID == story.id && player.isLoaded }

    var body: some View {
        VStack(spacing: 6) {
            Rule()
            if active {
                Slider(value: Binding(
                    get: { dragValue ?? player.currentTime },
                    set: { dragValue = $0 }
                ), in: 0...max(player.duration, 0.1)) { editing in
                    player.isScrubbing = editing
                    if !editing, let v = dragValue {
                        player.seek(to: v)
                        dragValue = nil
                    }
                }
                .tint(Palette.pen)
                .padding(.horizontal, 20)
                HStack {
                    Text(TimeFormat.clock(dragValue ?? player.currentTime))
                    Spacer()
                    Text("-" + TimeFormat.clock(player.duration - (dragValue ?? player.currentTime)))
                }
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Palette.muted)
                .padding(.horizontal, 22)
                HStack(spacing: 0) {
                    Button { player.cycleRate() } label: {
                        Text(player.rate == 1 ? "1×" : String(format: "%.2g×", player.rate))
                            .font(.system(size: 15, weight: .semibold).monospacedDigit())
                            .frame(width: 56, height: 44)
                    }
                    Spacer()
                    Button { player.skip(-10) } label: {
                        Image(systemName: "gobackward.10").font(.system(size: 24)).frame(width: 56, height: 44)
                    }
                    Button { player.toggle() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Palette.sheet)
                            .frame(width: 60, height: 60)
                            .background(Palette.pen, in: Circle())
                    }
                    .padding(.horizontal, 14)
                    Button { player.skip(10) } label: {
                        Image(systemName: "goforward.10").font(.system(size: 24)).frame(width: 56, height: 44)
                    }
                    Spacer()
                    Color.clear.frame(width: 56, height: 44)
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
            } else {
                Text("No narration for this story yet.")
                    .font(Fonts.italic(14))
                    .foregroundStyle(Palette.muted)
                    .padding(.vertical, 12)
            }
        }
        .padding(.bottom, 4)
        .background(Palette.paper.opacity(0.97))
    }
}

struct QuizView: View {
    let story: Story
    let onFinish: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var answers: [Int: Int] = [:]
    @State private var showFrench: Set<Int> = []

    private var score: Int { story.questions.indices.filter { answers[$0] == story.questions[$0].answer }.count }
    private var complete: Bool { answers.count == story.questions.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(story.questions.enumerated()), id: \.offset) { i, q in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("\(i + 1).").font(Fonts.display(20, weight: .light)).foregroundStyle(Palette.margin)
                                Text(q.ru).font(Fonts.display(20)).foregroundStyle(Palette.ink)
                            }
                            Button(showFrench.contains(i) ? q.fr : "in French?") { showFrench.insert(i) }
                                .font(Fonts.italic(14))
                                .foregroundStyle(Palette.pen)
                            ForEach(Array(q.options.enumerated()), id: \.offset) { j, option in
                                optionRow(i, j, option, q)
                            }
                        }
                        .padding(.vertical, 18)
                        Rule()
                    }
                    if complete {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(score)/\(story.questions.count)")
                                .font(Fonts.display(48, weight: .regular))
                                .foregroundStyle(score == story.questions.count ? Palette.pen : Palette.margin)
                            Text(score == story.questions.count ? "Отлично!" : "Хорошо! Re-read the sentences you missed.")
                                .font(Fonts.italic(17)).foregroundStyle(Palette.muted)
                            Button("Done") {
                                onFinish(score)
                                dismiss()
                            }
                            .buttonStyle(InkButtonStyle())
                        }
                        .padding(.top, 24)
                    }
                }
                .padding(.leading, 44)
                .padding(.trailing, 20)
                .padding(.bottom, 30)
            }
            .background(NotebookPaper())
            .navigationTitle("Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private func optionRow(_ i: Int, _ j: Int, _ option: String, _ q: Story.Question) -> some View {
        let chosen = answers[i]
        let isAnswer = j == q.answer
        let mark: String = chosen == nil ? "○" : isAnswer ? "✓" : (chosen == j ? "✗" : "○")
        let color: Color = chosen == nil ? Palette.ink : isAnswer ? Palette.pen : (chosen == j ? Palette.margin : Palette.muted)
        return Button {
            guard answers[i] == nil else { return }
            withAnimation(.snappy) { answers[i] = j }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(mark).font(.system(size: 16, weight: .semibold)).frame(width: 18)
                Text(option).font(Fonts.reading(18))
                    .strikethrough(chosen == j && !isAnswer, color: Palette.margin)
                Spacer()
            }
            .foregroundStyle(color)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
