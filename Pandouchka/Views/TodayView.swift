import SwiftData
import SwiftUI
import PandouchkaCore

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter
    @Query(sort: \ReviewLog.date, order: .reverse) private var logs: [ReviewLog]
    @Query private var cards: [Card]
    @Query private var progress: [StoryProgress]
    @AppStorage(Prefs.directions) private var directions = "both"
    @AppStorage(Prefs.newPerDay) private var newPerDay = 10

    @State private var due = 0
    @State private var wordOfDay: DictEntry?
    @State private var showSettings = false
    @State private var openWord: DictEntry?

    private var nextStory: (Int, Story)? {
        let done = Set(progress.filter { $0.completedAt != nil }.map(\.storyID))
        return StoryLibrary.all.enumerated().first { !done.contains($0.element.id) }.map { ($0.offset + 1, $0.element) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    dateHeader
                    section("To review") { reviewBlock }
                    if let next = nextStory {
                        section("Next story") { storyBlock(next.0, next.1) }
                    }
                    if let w = wordOfDay {
                        section("Word of the day") { wordBlock(w) }
                    }
                    section("Last fourteen days") { activityStrip }
                }
                .padding(.leading, 44)
                .padding(.trailing, 20)
                .padding(.bottom, 40)
            }
            .background(NotebookPaper())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                        .tint(Palette.ink)
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $openWord) { entry in
                NavigationStack { WordDetailView(entry: entry) }
                    .presentationDetents([.medium, .large])
            }
            .onAppear(perform: refresh)
            .onChange(of: router.reviewing) { refresh() }
        }
    }

    private func refresh() {
        due = CardStore.dueCount(in: context, directions: Prefs.enabledDirections(directions), newLimit: newPerDay)
        if wordOfDay == nil { wordOfDay = RussianDictionary.shared.wordOfTheDay() }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(title)
            content()
            Rule().padding(.top, 10)
        }
        .padding(.top, 22)
    }

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "en_GB"))))
                .font(Fonts.italic(15))
                .foregroundStyle(Palette.pen)
            Text(Date().russianDay)
                .font(Fonts.display(34))
                .foregroundStyle(Palette.ink)
                .onTapGesture { Speech.shared.say(Date().russianDay) }
        }
        .padding(.top, 12)
    }

    private var reviewBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(due)")
                    .font(Fonts.display(56, weight: .regular))
                    .foregroundStyle(due > 0 ? Palette.pen : Palette.muted)
                    .contentTransition(.numericText())
                Text(due == 1 ? "card waiting" : "cards waiting")
                    .font(Fonts.italic(17))
                    .foregroundStyle(Palette.muted)
            }
            if cards.isEmpty {
                Text("Tap a word in a story and add it: it will show up here.")
                    .font(Fonts.ui(.subheadline)).foregroundStyle(Palette.muted)
            } else if due > 0 {
                Button("Review now") { router.reviewing = true }
                    .buttonStyle(InkButtonStyle())
            } else {
                Text("Nothing left for today. \(cards.count) words in your deck.")
                    .font(Fonts.ui(.subheadline)).foregroundStyle(Palette.muted)
            }
        }
    }

    private func storyBlock(_ n: Int, _ story: Story) -> some View {
        Button { router.tab = .stories } label: {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(String(format: "%02d", n))
                    .font(Fonts.display(30, weight: .light))
                    .foregroundStyle(Palette.margin)
                VStack(alignment: .leading, spacing: 2) {
                    Text(story.title).font(Fonts.display(22)).foregroundStyle(Palette.ink)
                    Text(story.titleFr).font(Fonts.italic(15)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Image(systemName: "arrow.right").foregroundStyle(Palette.pen)
            }
        }
        .buttonStyle(.plain)
    }

    private func wordBlock(_ w: DictEntry) -> some View {
        Button { openWord = w } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(w.word).font(Fonts.display(28)).foregroundStyle(Palette.ink)
                    Text(w.grammarLine).font(Fonts.italic(14)).foregroundStyle(Palette.muted)
                }
                Text(w.shortFrench).font(Fonts.reading(17)).foregroundStyle(Palette.pen).lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
    }

    private var activityStrip: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var counts: [Date: Int] = [:]
        for l in logs {
            let d = cal.startOfDay(for: l.date)
            if today.timeIntervalSince(d) > 14 * 86_400 { break }
            counts[d, default: 0] += 1
        }
        let days = (0..<14).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        return HStack(spacing: 5) {
            ForEach(days, id: \.self) { d in
                let c = counts[d] ?? 0
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(c == 0 ? Palette.rule : Palette.pen.opacity(min(0.3 + Double(c) / 40, 1)))
                        .frame(height: 18)
                    Text(d.formatted(.dateTime.weekday(.narrow).locale(Locale(identifier: "ru_RU"))))
                        .font(.system(size: 9))
                        .foregroundStyle(cal.isDateInToday(d) ? Palette.margin : Palette.muted)
                }
            }
        }
    }
}
