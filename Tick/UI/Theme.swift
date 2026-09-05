import AppKit
import SwiftUI

extension NSColor {
    convenience init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    /// Цвет, меняющийся вместе с оформлением окна (светлое / тёмное).
    init(light: String, dark: String) {
        let lightColor = NSColor(hex: light)
        let darkColor = NSColor(hex: dark)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkColor : lightColor
        })
    }
}

extension AppTheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Палитра «ламинированной карточки»: бумага, чернила, янтарь предупреждений.
enum Palette {
    static let paper = Color(light: "F6F3EC", dark: "17191E")
    static let paperRaised = Color(light: "FFFFFF", dark: "1E2127")
    static let ink = Color(light: "1B1D21", dark: "ECE8DE")
    static let inkMuted = Color(light: "6B6E75", dark: "9A9DA6")
    static let rule = Color(light: "D6D0C3", dark: "33373F")
    static let amber = Color(light: "E5A400", dark: "F2B705")
    static let header = Color(light: "1B1D21", dark: "0D0F12")
    static let headerInk = Color(light: "F6F3EC", dark: "ECE8DE")
    static let done = Color(light: "2E8B57", dark: "4CB878")
    static let code = Color(light: "ECE7DA", dark: "24282F")
}

enum Typo {
    static let title = Font.system(size: 20, weight: .heavy)
    static let label = Font.system(size: 10.5, weight: .bold, design: .monospaced)
    static let number = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let item = Font.system(size: 14.5, weight: .medium)
    static let section = Font.system(size: 11, weight: .heavy)
    static let code = Font.system(size: 12.5, weight: .medium, design: .monospaced)
}

/// Косая жёлто-чёрная полоса, как на кромке аварийной карты.
struct HazardStripe: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: "F2B705")))
            let step: CGFloat = 14
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + step / 2, y: 0))
                path.addLine(to: CGPoint(x: x + step / 2 + size.height, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .color(Color(hex: "1B1D21")))
                x += step
            }
        }
    }
}

extension Color {
    init(hex: String) { self.init(nsColor: NSColor(hex: hex)) }
}

/// Точечный лидер между пунктом и значением: «ЗАКРЫЛКИ ........ 15».
struct DotLeader: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 4
            var x: CGFloat = spacing / 2
            while x < size.width {
                let dot = Path(ellipseIn: CGRect(x: x, y: size.height - 1.5, width: 1.5, height: 1.5))
                context.fill(dot, with: .color(Palette.inkMuted.opacity(0.7)))
                x += spacing
            }
        }
        .frame(height: 6)
        .frame(minWidth: 18)
        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] }
    }
}

/// Квадратный чекбокс с карточки.
struct CheckBox: View {
    var isDone: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(isDone ? Palette.done : Color.clear)
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(isDone ? Palette.done : Palette.inkMuted, lineWidth: 1.5)
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 17, height: 17)
        .contentShape(Rectangle())
    }
}

/// Кнопка в тёмной шапке.
struct HeaderButton: View {
    var symbol: String
    var help: String
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.headerInk.opacity(hovering ? 1 : 0.75))
                .frame(width: 26, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(hovering ? 0.12 : 0))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

extension View {
    /// Копирует строку в буфер обмена.
    func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
