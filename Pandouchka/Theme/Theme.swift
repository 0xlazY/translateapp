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

/// Ink-on-paper base with the blue, white and red that France and Russia share.
enum Palette {
    static let paper = Color(light: 0xF6F3EC, dark: 0x0E1120)
    static let surface = Color(light: 0xFFFFFF, dark: 0x191D31)
    static let sunken = Color(light: 0xECE7DC, dark: 0x23283F)
    static let ink = Color(light: 0x1B2140, dark: 0xEDEFF7)
    static let muted = Color(light: 0x6B6F82, dark: 0x9499AE)
    static let line = Color(light: 0xDDD6C8, dark: 0x2E3450)
    static let blue = Color(light: 0x2747D0, dark: 0x7B95FF)
    static let red = Color(light: 0xD3223C, dark: 0xFF6C7C)
    static let green = Color(light: 0x23845A, dark: 0x58D196)
    static let amber = Color(light: 0xC77700, dark: 0xFFB547)
    static let violet = Color(light: 0x6A3FC2, dark: 0xB496FF)
    static let teal = Color(light: 0x0F7C8C, dark: 0x4FD2E0)

    static func theme(_ name: String) -> Color {
        switch name {
        case "red": return red
        case "green": return green
        case "amber": return amber
        case "violet": return violet
        case "teal": return teal
        default: return blue
        }
    }

    /// Memory strength: red when fragile, blue when solid.
    static func memory(_ r: Double) -> Color {
        switch r {
        case ..<0.5: return red
        case ..<0.8: return amber
        case ..<0.93: return green
        default: return blue
        }
    }
}

enum Fonts {
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func reading(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static func ui(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight)
    }
}

/// The tricolour motif: vertical stripes for French, horizontal for Russian.
struct Tricolor: View {
    enum Axis { case french, russian }
    var axis: Axis
    var body: some View {
        switch axis {
        case .french:
            HStack(spacing: 0) {
                Palette.blue
                Color.white
                Palette.red
            }
        case .russian:
            VStack(spacing: 0) {
                Color.white
                Palette.blue
                Palette.red
            }
        }
    }
}

struct CardBackground: ViewModifier {
    var radius: CGFloat = 22
    func body(content: Content) -> some View {
        content
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Palette.line.opacity(0.6), lineWidth: 0.5))
            .shadow(color: Color.black.opacity(0.06), radius: 12, y: 6)
    }
}

extension View {
    func card(radius: CGFloat = 22) -> some View { modifier(CardBackground(radius: radius)) }
}

struct Chip: View {
    var text: String
    var color: Color = Palette.blue
    var filled = false
    var body: some View {
        Text(text)
            .font(Fonts.ui(.caption, weight: .semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(filled ? Color.white : color)
            .background(filled ? color : color.opacity(0.12), in: Capsule())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Palette.blue
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Fonts.ui(.headline, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    var color: Color = Palette.blue
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Fonts.ui(.subheadline, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(color.opacity(configuration.isPressed ? 0.22 : 0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
