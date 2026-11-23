import SwiftUI
import UIKit

extension Color {
    /// A color that adapts to light and dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let v = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                           blue: CGFloat(v & 0xFF) / 255, alpha: 1)
        })
    }
}

/// «Cahier de russe»: a French school notebook. Off-white paper, a red margin,
/// fountain-pen blue for what you write, black for what is printed.
enum Palette {
    static let paper = Color(light: 0xFBF8F0, dark: 0x16171B)
    static let sheet = Color(light: 0xFFFEFA, dark: 0x1E1F24)
    static let ink = Color(light: 0x1D1C1A, dark: 0xEAE6DC)
    static let muted = Color(light: 0x7A756B, dark: 0x8F8A80)
    static let rule = Color(light: 0xE2DBCB, dark: 0x2E3036)
    /// Fountain-pen blue.
    static let pen = Color(light: 0x2849A6, dark: 0x93A9F2)
    /// The red margin line.
    static let margin = Color(light: 0xD8524A, dark: 0xEE7C72)
    /// Seyès ruling.
    static let seyes = Color(light: 0xC9D6EC, dark: 0x2A3348)
    /// Highlighter, for the sentence being read.
    static let highlighter = Color(light: 0xF6E8A0, dark: 0x4A4220)
    static let green = Color(light: 0x2E7D4F, dark: 0x6FCB95)
    static let amber = Color(light: 0xB86E00, dark: 0xF0B24A)

    /// Memory strength: red margin when fragile, pen blue when solid.
    static func memory(_ r: Double) -> Color {
        switch r {
        case ..<0.6: return margin
        case ..<0.85: return amber
        default: return pen
        }
    }
}

enum Fonts {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func reading(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static func italic(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif).italic() }
    static func ui(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style).weight(weight)
    }
}

/// Small letter-spaced capitals used for section labels.
struct Eyebrow: View {
    let text: String
    var color: Color = Palette.muted
    init(_ text: String, color: Color = Palette.muted) {
        self.text = text
        self.color = color
    }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

/// A hairline rule.
struct Rule: View {
    var color: Color = Palette.rule
    var body: some View {
        Rectangle().fill(color).frame(height: 0.75)
    }
}

/// Paper with the red margin line of a French notebook.
struct NotebookPaper: View {
    var marginX: CGFloat = 26
    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.paper
            Rectangle().fill(Palette.margin.opacity(0.55)).frame(width: 1.2).padding(.leading, marginX)
        }
        .ignoresSafeArea()
    }
}

/// Seyès ruling: a strong line every four faint ones, as in French school notebooks.
struct SeyesRuling: View {
    var pitch: CGFloat = 8
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = pitch
            var i = 1
            while y < size.height {
                let strong = i % 4 == 0
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(Palette.seyes.opacity(strong ? 1 : 0.45)), lineWidth: strong ? 0.8 : 0.5)
                y += pitch
                i += 1
            }
        }
    }
}

/// Solid pen-blue button with square-ish corners.
struct InkButtonStyle: ButtonStyle {
    var color: Color = Palette.pen
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body).weight(.semibold))
            .foregroundStyle(Palette.sheet)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// Outlined button: a box drawn in pen.
struct OutlineButtonStyle: ButtonStyle {
    var color: Color = Palette.pen
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline).weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(color.opacity(configuration.isPressed ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(color.opacity(0.6), lineWidth: 1))
    }
}

/// Lays out views left to right, wrapping onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxX: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0, x + s.width > width {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += s.width + spacing
            maxX = max(maxX, x)
            lineHeight = max(lineHeight, s.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX, x + s.width > bounds.maxX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            lineHeight = max(lineHeight, s.height)
        }
    }
}

extension Date {
    /// "понедельник, 23 ноября"
    var russianDay: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return f.string(from: self)
    }
}
