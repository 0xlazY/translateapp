import Charts
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

    private var streak: Int {
        let cal = Calendar.current
        let days = Set(logs.map { cal.dateComponents([.year, .month, .day], from: $0.date) })
        return Streak.days(activeDays: days, today: Date(), calendar: cal)
    }

    private var reviewedToday: Int {
        let start = Calendar.current.startOfDay(for: Date())
        return logs.prefix { $0.date >= start }.count
    }

    private var nextStory: Story? {
        let done = Set(progress.filter { $0.completedAt != nil }.map(\.storyID))
        return StoryLibrary.all.first { !done.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    reviewCard
                    if let story = nextStory { continueCard(story) }
                    if let w = wordOfDay { wordCard(w) }
                    activityCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
            .background(Palette.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
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

    private var greeting: (String, String) {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return ("Доброе утро", "Good morning")
        case 12..<18: return ("Добрый день", "Good afternoon")
        case 18..<23: return ("Добрый вечер", "Good evening")
        default: return ("Доброй ночи", "Good night")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image("Logo")
                .resizable()
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting.0).font(Fonts.display(28))
                    .foregroundStyle(Palette.ink)
                    .onTapGesture { Speech.shared.say(greeting.0) }
                Text(greeting.1).font(Fonts.ui(.subheadline)).foregroundStyle(Palette.muted)
            }
            Spacer()
            VStack(spacing: 0) {
                Image(systemName: streak > 0 ? "flame.fill" : "flame")
                    .font(.title2)
                    .foregroundStyle(streak > 0 ? Palette.red : Palette.muted)
                Text("\(streak)").font(Fonts.ui(.headline, weight: .bold)).foregroundStyle(Palette.ink)
            }
            .accessibilityLabel("\(streak) day streak")
        }
        .padding(.top, 8)
    }

    private var reviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Flashcards").font(Fonts.ui(.caption, weight: .semibold)).foregroundStyle(Palette.muted).textCase(.uppercase)
                    Text(due == 0 ? "All caught up" : "\(due) to review")
                        .font(Fonts.display(30))
                        .foregroundStyle(Palette.ink)
                    Text(cards.isEmpty ? "Tap words in a story to start your deck." : "\(cards.count) words in your deck · \(reviewedToday) reviewed today")
                        .font(Fonts.ui(.footnote))
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                ProgressRing(progress: cards.isEmpty ? 0 : Double(reviewedToday) / Double(max(reviewedToday + due, 1)))
                    .frame(width: 64, height: 64)
            }
            Button {
                router.reviewing = true
            } label: {
                Label(due == 0 ? "Nothing due" : "Start review", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle(color: due == 0 ? Palette.muted : Palette.blue))
            .disabled(due == 0)
        }
        .padding(18)
        .card()
    }

    private func continueCard(_ story: Story) -> some View {
        Button {
            router.tab = .stories
        } label: {
            HStack(spacing: 14) {
                StoryCover(story: story, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next story · \(story.level.rawValue)").font(Fonts.ui(.caption, weight: .semibold)).foregroundStyle(Palette.muted).textCase(.uppercase)
                    Text(story.title).font(Fonts.display(20)).foregroundStyle(Palette.ink)
                    Text(story.titleFr).font(Fonts.ui(.footnote)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Palette.muted)
            }
            .padding(14)
            .card()
        }
        .buttonStyle(.plain)
    }

    private func wordCard(_ w: DictEntry) -> some View {
        Button { openWord = w } label: {
            HStack(spacing: 0) {
                Tricolor(axis: .russian).frame(width: 6)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Word of the day").font(Fonts.ui(.caption, weight: .semibold)).foregroundStyle(Palette.muted).textCase(.uppercase)
                    HStack(alignment: .firstTextBaseline) {
                        Text(w.word).font(Fonts.display(30)).foregroundStyle(Palette.ink)
                        Text(w.grammarLine).font(Fonts.ui(.caption)).foregroundStyle(Palette.muted)
                    }
                    Text(w.shortFrench).font(Fonts.ui(.body)).foregroundStyle(Palette.ink.opacity(0.85)).lineLimit(2)
                }
                .padding(16)
                Spacer()
                Button {
                    Speech.shared.say(w.word)
                } label: {
                    Image(systemName: "speaker.wave.2.fill").padding(16)
                }
            }
            .card()
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private struct DayCount: Identifiable {
        let day: Date
        let count: Int
        var id: Date { day }
    }

    private var lastTwoWeeks: [DayCount] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var counts: [Date: Int] = [:]
        for l in logs {
            let d = cal.startOfDay(for: l.date)
            if today.timeIntervalSince(d) > 14 * 86_400 { break }
            counts[d, default: 0] += 1
        }
        return (0..<14).reversed().compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: today).map { DayCount(day: $0, count: counts[$0] ?? 0) }
        }
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last two weeks").font(Fonts.ui(.caption, weight: .semibold)).foregroundStyle(Palette.muted).textCase(.uppercase)
            Chart(lastTwoWeeks) { d in
                BarMark(x: .value("Day", d.day, unit: .day), y: .value("Reviews", d.count))
                    .foregroundStyle(Calendar.current.isDateInToday(d.day) ? Palette.red : Palette.blue)
                    .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 120)
        }
        .padding(18)
        .card()
    }
}

struct ProgressRing: View {
    var progress: Double
    var body: some View {
        ZStack {
            Circle().stroke(Palette.sunken, lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(AngularGradient(colors: [Palette.blue, Palette.red], center: .center), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((progress * 100).rounded()))%").font(Fonts.ui(.caption, weight: .bold)).foregroundStyle(Palette.ink)
        }
    }
}
