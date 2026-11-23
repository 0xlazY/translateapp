import SwiftData
import SwiftUI
import PandouchkaCore

/// Review session on lined index cards: the prompt is printed above the red line,
/// the answer is written below it in pen.
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

    private var current: CardSchedule? { index < queue.count ? queue[index] : nil }
    private var direction: Direction { current.flatMap { Direction(rawValue: $0.direction) } ?? .ruFr }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if let s = current, let card = s.card {
                Spacer(minLength: 16)
                cardView(card)
                    .id(index)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 24)),
                                            removal: .opacity.combined(with: .offset(x: drag.width < 0 ? -300 : 300))))
                Spacer(minLength: 16)
                answerBar(s)
            } else if loaded {
                summary
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(Palette.paper.ignoresSafeArea())
        .onAppear(perform: load)
        .onDisappear { Speech.shared.stop() }
    }

    private func load() {
        guard !loaded else { return }
        queue = CardStore.queue(in: context, directions: Prefs.enabledDirections(directions), newLimit: newPerDay)
        loaded = true
        autoSpeakFront()
    }

    // MARK: Pieces

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .medium)).frame(width: 36, height: 36)
                }
                .foregroundStyle(Palette.ink)
                Spacer()
                if !queue.isEmpty {
                    Text("\(min(index + 1, queue.count)) / \(queue.count)")
                        .font(Fonts.italic(16).monospacedDigit())
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Palette.rule)
                    Rectangle().fill(Palette.pen).frame(width: g.size.width * progress)
                }
            }
            .frame(height: 2)
        }
        .padding(.top, 8)
    }

    private var progress: Double {
        guard !queue.isEmpty else { return 1 }
        return Double(index) / Double(queue.count)
    }

    private func russian(_ card: Card) -> String {
        showStress ? card.russian : RussianText.stripStress(card.russian)
    }

    private func cardView(_ card: Card) -> some View {
        let tint: Color = drag.width > 40 ? Palette.pen : drag.width < -40 ? Palette.margin : .clear
        return ZStack {
            indexCard(front: true, card: card)
                .opacity(flipped ? 0 : 1)
            indexCard(front: false, card: card)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .overlay(alignment: drag.width > 0 ? .topLeading : .topTrailing) {
            if abs(drag.width) > 40 {
                Text(drag.width > 0 ? "good" : "again")
                    .font(Fonts.italic(22))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(tint, lineWidth: 1.5))
                    .rotationEffect(.degrees(drag.width > 0 ? -12 : 12))
                    .padding(22)
                    .opacity(min(abs(drag.width) / 120, 1))
            }
        }
        .offset(x: drag.width, y: drag.height * 0.15)
        .rotationEffect(.degrees(Double(drag.width) / 28))
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

    private let headerHeight: CGFloat = 132

    private func indexCard(front: Bool, card: Card) -> some View {
        let ruFirst = direction == .ruFr
        return ZStack(alignment: .top) {
            // The card itself: ruling, red header line.
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Palette.sheet)
            VStack(spacing: 0) {
                Color.clear.frame(height: headerHeight)
                Rectangle().fill(Palette.margin.opacity(0.7)).frame(height: 1.2)
                Canvas { ctx, size in
                    var y: CGFloat = 34
                    while y < size.height - 8 {
                        var p = Path()
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                        ctx.stroke(p, with: .color(Palette.seyes), lineWidth: 0.7)
                        y += 34
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(spacing: 0) {
                // Above the red line: the prompt.
                VStack(spacing: 8) {
                    HStack {
                        Eyebrow(ruFirst ? "Russian → French" : "French → Russian", color: Palette.muted)
                        Spacer()
                        if ruFirst || !front {
                            Button { Speech.shared.say(card.russian) } label: {
                                Image(systemName: "speaker.wave.2").foregroundStyle(Palette.pen)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Text(ruFirst ? russian(card) : card.french)
                        .font(ruFirst ? Fonts.display(card.russian.count > 14 ? 32 : 42) : Fonts.display(card.french.count > 30 ? 24 : 32))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .frame(height: headerHeight - 12)
                .padding(.top, 12)

                // Below the red line: the answer, in pen.
                VStack(spacing: 14) {
                    if front {
                        Spacer()
                        Text("tap to turn over").font(Fonts.italic(15)).foregroundStyle(Palette.muted.opacity(0.7))
                        Spacer()
                    } else {
                        Text(ruFirst ? card.french : russian(card))
                            .font(ruFirst ? Fonts.italic(card.french.count > 30 ? 24 : 30) : Fonts.display(card.russian.count > 14 ? 30 : 38))
                            .foregroundStyle(Palette.pen)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.5)
                            .padding(.top, 18)
                        if !card.notes.isEmpty {
                            Text(card.notes).font(Fonts.italic(14)).foregroundStyle(Palette.muted)
                        }
                        if !card.example.isEmpty {
                            VStack(spacing: 4) {
                                Text(card.example).font(Fonts.reading(17)).foregroundStyle(Palette.ink)
                                    .onTapGesture { Speech.shared.say(card.example) }
                                if !card.exampleTranslation.isEmpty {
                                    Text(card.exampleTranslation).font(Fonts.italic(14)).foregroundStyle(Palette.pen)
                                }
                            }
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: 500)
        .shadow(color: .black.opacity(0.10), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.06), radius: 14, y: 8)
    }

    private func answerBar(_ s: CardSchedule) -> some View {
        let preview = Prefs.fsrs.preview(s.value)
        let now = Date()
        return Group {
            if flipped {
                HStack(spacing: 0) {
                    rateButton(s, .again, "again", Palette.margin, preview[.again], now)
                    Rectangle().fill(Palette.rule).frame(width: 1, height: 40)
                    rateButton(s, .hard, "hard", Palette.amber, preview[.hard], now)
                    Rectangle().fill(Palette.rule).frame(width: 1, height: 40)
                    rateButton(s, .good, "good", Palette.green, preview[.good], now)
                    Rectangle().fill(Palette.rule).frame(width: 1, height: 40)
                    rateButton(s, .easy, "easy", Palette.pen, preview[.easy], now)
                }
                .overlay(alignment: .top) { Rule() }
            } else {
                Button("Turn over") { flip() }
                    .buttonStyle(InkButtonStyle(color: Palette.ink))
            }
        }
        .frame(height: 66)
    }

    private func rateButton(_ s: CardSchedule, _ r: Rating, _ label: String, _ color: Color, _ due: Date?, _ now: Date) -> some View {
        Button { answer(s, r) } label: {
            VStack(spacing: 3) {
                Text(label).font(Fonts.display(18)).foregroundStyle(color)
                Text(due.map { IntervalFormat.short(from: now, to: $0) } ?? "")
                    .font(Fonts.italic(12)).foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer()
            Text(answered == 0 ? "Nothing to review." : "Молоде́ц!")
                .font(Fonts.display(40))
                .foregroundStyle(Palette.ink)
            if answered > 0 {
                Text("\(answered) answers, \(Int(Double(correct) / Double(max(answered, 1)) * 100))% remembered.")
                    .font(Fonts.italic(18)).foregroundStyle(Palette.pen)
            } else {
                Text("Add words from the stories or the dictionary, or come back later.")
                    .font(Fonts.italic(17)).foregroundStyle(Palette.muted)
            }
            Spacer()
            Button("Close") { dismiss() }.buttonStyle(InkButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
