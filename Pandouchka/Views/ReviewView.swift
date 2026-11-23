import SwiftData
import SwiftUI
import PandouchkaCore

struct ReviewView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.directions) private var directions = "both"
    @AppStorage(Prefs.newPerDay) private var newPerDay = 10
    @AppStorage(Prefs.autoPlay) private var autoPlay = true
    @AppStorage(Prefs.showStress) private var showStress = true

    @State private var queue: [CardSchedule] = []
    @State private var index = 0
    @State private var flipped = false
    @State private var drag: CGSize = .zero
    @State private var answered = 0
    @State private var correct = 0
    @State private var loaded = false
    @State private var initialCount = 0

    private var current: CardSchedule? { index < queue.count ? queue[index] : nil }
    private var direction: Direction { current.flatMap { Direction(rawValue: $0.direction) } ?? .ruFr }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if let s = current, let card = s.card {
                Spacer(minLength: 12)
                cardView(card)
                    .id(s.persistentModelID)
                    .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity),
                                            removal: .move(edge: drag.width < 0 ? .leading : .trailing).combined(with: .opacity)))
                Spacer(minLength: 12)
                answerBar(s)
            } else if loaded {
                summary
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
        .background(Palette.paper.ignoresSafeArea())
        .onAppear(perform: load)
        .onDisappear { Speech.shared.stop() }
    }

    private func load() {
        guard !loaded else { return }
        queue = CardStore.queue(in: context, directions: Prefs.enabledDirections(directions), newLimit: newPerDay)
        initialCount = queue.count
        loaded = true
        autoSpeakFront()
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.headline).frame(width: 36, height: 36)
                    .background(Palette.sunken, in: Circle())
            }
            .foregroundStyle(Palette.ink)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.sunken)
                    Capsule()
                        .fill(LinearGradient(colors: [Palette.blue, Palette.red], startPoint: .leading, endPoint: .trailing))
                        .frame(width: g.size.width * progress)
                }
            }
            .frame(height: 8)
            Text("\(max(queue.count - index, 0))")
                .font(Fonts.ui(.subheadline, weight: .bold))
                .foregroundStyle(Palette.muted)
                .frame(minWidth: 28)
        }
        .padding(.top, 10)
    }

    private var progress: Double {
        guard !queue.isEmpty else { return 1 }
        return Double(index) / Double(queue.count)
    }

    private func russianText(_ card: Card) -> String {
        showStress ? card.russian : RussianText.stripStress(card.russian)
    }

    private func cardView(_ card: Card) -> some View {
        let isRuFront = direction == .ruFr
        let tint: Color = drag.width > 40 ? Palette.green : drag.width < -40 ? Palette.red : .clear
        return ZStack {
            face(front: true, card: card, russianFront: isRuFront)
                .opacity(flipped ? 0 : 1)
            face(front: false, card: card, russianFront: isRuFront)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(tint, lineWidth: 4)
                .opacity(min(abs(drag.width) / 120, 1))
        )
        .offset(x: drag.width, y: drag.height * 0.2)
        .rotationEffect(.degrees(Double(drag.width) / 22))
        .gesture(
            DragGesture()
                .onChanged { v in if flipped { drag = v.translation } }
                .onEnded { v in
                    guard flipped, let s = current else { drag = .zero; return }
                    if v.translation.width > 110 {
                        answer(s, .good)
                    } else if v.translation.width < -110 {
                        answer(s, .again)
                    } else {
                        withAnimation(.spring) { drag = .zero }
                    }
                }
        )
        .onTapGesture { flip() }
    }

    private func face(front: Bool, card: Card, russianFront: Bool) -> some View {
        let showsRussian = front == russianFront
        return VStack(spacing: 18) {
            (showsRussian ? Tricolor(axis: .russian) : Tricolor(axis: .french))
                .frame(width: 54, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Palette.line, lineWidth: 0.5))
            Spacer()
            if showsRussian {
                Text(russianText(card))
                    .font(Fonts.display(card.russian.count > 14 ? 34 : 46))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                Button { Speech.shared.say(card.russian) } label: {
                    Image(systemName: "speaker.wave.2.fill").font(.title3).frame(width: 48, height: 48)
                        .background(Palette.blue.opacity(0.12), in: Circle())
                }
            } else {
                Text(card.french)
                    .font(Fonts.display(card.french.count > 30 ? 26 : 34, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
            }
            if !front {
                VStack(spacing: 6) {
                    if !card.notes.isEmpty {
                        Text(card.notes).font(Fonts.ui(.footnote)).foregroundStyle(Palette.muted)
                    }
                    if !card.example.isEmpty {
                        Text(card.example).font(Fonts.reading(17)).foregroundStyle(Palette.ink.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .onTapGesture { Speech.shared.say(card.example) }
                        if !card.exampleTranslation.isEmpty {
                            Text(card.exampleTranslation).font(Fonts.ui(.footnote)).italic().foregroundStyle(Palette.muted)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.top, 8)
            }
            Spacer()
            Text(front ? "Tap to reveal" : (direction == .ruFr ? "Russian → French" : "French → Russian"))
                .font(Fonts.ui(.caption))
                .foregroundStyle(Palette.muted)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: 520)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }

    private func answerBar(_ s: CardSchedule) -> some View {
        let preview = Prefs.fsrs.preview(s.value)
        let now = Date()
        return Group {
            if flipped {
                HStack(spacing: 8) {
                    rateButton(s, .again, "Again", Palette.red, preview[.again], now)
                    rateButton(s, .hard, "Hard", Palette.amber, preview[.hard], now)
                    rateButton(s, .good, "Good", Palette.green, preview[.good], now)
                    rateButton(s, .easy, "Easy", Palette.blue, preview[.easy], now)
                }
            } else {
                Button("Show answer") { flip() }
                    .buttonStyle(PrimaryButtonStyle(color: Palette.ink))
            }
        }
        .frame(height: 64)
    }

    private func rateButton(_ s: CardSchedule, _ r: Rating, _ label: String, _ color: Color, _ due: Date?, _ now: Date) -> some View {
        Button { answer(s, r) } label: {
            VStack(spacing: 2) {
                Text(label).font(Fonts.ui(.subheadline, weight: .bold))
                Text(due.map { IntervalFormat.short(from: now, to: $0) } ?? "").font(Fonts.ui(.caption2))
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(color)
            .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var summary: some View {
        VStack(spacing: 18) {
            Spacer()
            Image("Logo").resizable().frame(width: 96, height: 96).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            Text(answered == 0 ? "Nothing to review" : "Молодец!").font(Fonts.display(36)).foregroundStyle(Palette.ink)
            if answered > 0 {
                Text("\(answered) answers · \(Int(Double(correct) / Double(max(answered, 1)) * 100))% remembered")
                    .font(Fonts.ui(.headline)).foregroundStyle(Palette.muted)
            } else {
                Text("Add words from stories or the dictionary, or come back later.")
                    .font(Fonts.ui(.subheadline)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            }
            Spacer()
            Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: Actions

    private func flip() {
        withAnimation(.spring(duration: 0.45)) { flipped.toggle() }
        if flipped, autoPlay, let card = current?.card, direction == .frRu {
            Speech.shared.say(card.russian)
        }
    }

    private func autoSpeakFront() {
        guard autoPlay, let card = current?.card, direction == .ruFr else { return }
        Speech.shared.say(card.russian)
    }

    private func answer(_ s: CardSchedule, _ r: Rating) {
        CardStore.answer(s, rating: r, in: context)
        answered += 1
        if r != .again { correct += 1 }
        UIImpactFeedbackGenerator(style: r == .again ? .rigid : .soft).impactOccurred()
        // Cards back in a short learning step come round again in this session.
        let requeue = s.due.timeIntervalSinceNow < 20 * 60
        withAnimation(.spring(duration: 0.35)) {
            if requeue { queue.append(s) }
            index += 1
            flipped = false
            drag = .zero
        }
        autoSpeakFront()
    }
}
