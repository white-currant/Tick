import AppKit
import Foundation

// Иконка Tick: карточка чеклиста в стиле приложения — тёмная шапка с янтарным
// заголовком, жёлто-чёрная аварийная полоса, кремовое тело с квадратными
// чекбоксами и точечными лидерами.

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1])

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let ink = rgb(0x1B1D21)
let inkSoft = rgb(0x2A2D33)
let paper = rgb(0xF6F3EC)
let amber = rgb(0xF2B705)
let rule = rgb(0xCFC9BC)
let code = rgb(0xE6E1D4)

func draw(into context: CGContext, side: CGFloat) {
    let s = side / 1024
    // Сетка иконок macOS: полотно 1024, изображение 824 со скруглением 185.
    let inset = 100 * s
    let rect = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    let radius = 185 * s

    context.saveGState()
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.clip()

    // Тело карточки — бумага.
    context.setFillColor(paper)
    context.fill(rect)

    // Тёмная шапка (координаты снизу вверх).
    let headerHeight = rect.height * 0.36
    let headerRect = CGRect(x: rect.minX, y: rect.maxY - headerHeight, width: rect.width, height: headerHeight)
    context.setFillColor(ink)
    context.fill(headerRect)

    // Заголовок в шапке — одна толстая янтарная строка.
    func bar(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, color: CGColor) {
        let r = CGRect(x: x, y: y, width: width, height: height)
        context.setFillColor(color)
        context.addPath(CGPath(roundedRect: r, cornerWidth: height / 2, cornerHeight: height / 2, transform: nil))
        context.fillPath()
    }
    let pad = rect.width * 0.13
    bar(x: rect.minX + pad, y: headerRect.midY - 42 * s, width: rect.width * 0.52, height: 84 * s, color: amber)

    // Аварийная полоса по нижней кромке шапки.
    let stripeHeight = 48 * s
    let stripeRect = CGRect(x: rect.minX, y: headerRect.minY - stripeHeight, width: rect.width, height: stripeHeight)
    context.saveGState()
    context.clip(to: stripeRect)
    context.setFillColor(amber)
    context.fill(stripeRect)
    context.setFillColor(ink)
    let step = 96 * s
    var x = stripeRect.minX - stripeHeight
    while x < stripeRect.maxX + stripeHeight {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: stripeRect.minY))
        path.addLine(to: CGPoint(x: x + step / 2, y: stripeRect.minY))
        path.addLine(to: CGPoint(x: x + step / 2 + stripeHeight, y: stripeRect.maxY))
        path.addLine(to: CGPoint(x: x + stripeHeight, y: stripeRect.maxY))
        path.closeSubpath()
        context.addPath(path)
        context.fillPath()
        x += step
    }
    context.restoreGState()

    // Две крупные строки: отмеченный чекбокс и пустой, рядом толстая линия текста.
    let rows: [(done: Bool, textWidth: CGFloat)] = [(true, 0.40), (false, 0.30)]
    let bodyTop = stripeRect.minY
    let bodyHeight = bodyTop - rect.minY
    let box = 140 * s
    // Строки разнесены: первая на 30% высоты тела, вторая на 72%.
    let rowCenters: [CGFloat] = [bodyTop - bodyHeight * 0.32, bodyTop - bodyHeight * 0.69]
    for (index, row) in rows.enumerated() {
        let cy = rowCenters[index]
        let boxRect = CGRect(x: rect.minX + pad, y: cy - box / 2, width: box, height: box)
        let boxPath = CGPath(roundedRect: boxRect, cornerWidth: 26 * s, cornerHeight: 26 * s, transform: nil)
        if row.done {
            context.setFillColor(amber)
            context.addPath(boxPath)
            context.fillPath()
            context.setStrokeColor(ink)
            context.setLineWidth(22 * s)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            let check = CGMutablePath()
            check.move(to: CGPoint(x: boxRect.minX + box * 0.25, y: boxRect.midY))
            check.addLine(to: CGPoint(x: boxRect.minX + box * 0.44, y: boxRect.minY + box * 0.27))
            check.addLine(to: CGPoint(x: boxRect.maxX - box * 0.20, y: boxRect.maxY - box * 0.28))
            context.addPath(check)
            context.strokePath()
        } else {
            context.setStrokeColor(inkSoft)
            context.setLineWidth(16 * s)
            context.addPath(CGPath(roundedRect: boxRect.insetBy(dx: 8 * s, dy: 8 * s), cornerWidth: 20 * s, cornerHeight: 20 * s, transform: nil))
            context.strokePath()
        }
        let textX = boxRect.maxX + 56 * s
        bar(x: textX, y: cy - 28 * s, width: rect.width * row.textWidth, height: 56 * s, color: row.done ? rgb(0x9A9DA6) : inkSoft)
    }

    context.restoreGState()
}

for (name, pixels) in sizes {
    guard let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { continue }
    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high
    draw(into: context, side: CGFloat(pixels))
    guard let image = context.makeImage() else { continue }
    let representation = NSBitmapImageRep(cgImage: image)
    guard let data = representation.representation(using: .png, properties: [:]) else { continue }
    try data.write(to: outputDirectory.appendingPathComponent("\(name).png"))
}
print("ok")
