import AppKit
import SwiftUI

/// Draws a buddy in a given mood. Vector buddies live in a 64×64 space; pixel buddies on their own grid.
struct BuddyView: View {
    let buddy: Buddy
    let mood: Mood
    let tint: Color

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: buddy.isPixel ? 1.0 / 8 : 1.0 / 60, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                switch buddy {
                case .boo: BooArt.draw(&context, size: size, mood: mood, tint: tint, t: t)
                case .tofu: TofuArt.draw(&context, size: size, mood: mood, tint: tint, t: t)
                case .bit: BitArt.draw(&context, size: size, mood: mood, tint: tint, t: t)
                case .edith: EdithArt.draw(&context, size: size, mood: mood, tint: tint, t: t)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

// MARK: - Shared vector helpers

private func fit64(_ context: inout GraphicsContext, _ size: CGSize) {
    let s = min(size.width, size.height) / 64
    context.translateBy(x: (size.width - 64 * s) / 2, y: (size.height - 64 * s) / 2)
    context.scaleBy(x: s, y: s)
}

private func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
}

/// Eased glance: eyes rest, slide right, hold, flick back.
private func glance(_ t: Double) -> CGFloat {
    let p = (t / 2.6).truncatingRemainder(dividingBy: 1)
    func ease(_ x: Double) -> Double { x * x * (3 - 2 * x) }
    switch p {
    case ..<0.35: return 0
    case ..<0.45: return CGFloat(3 * ease((p - 0.35) / 0.1))
    case ..<0.80: return 3
    case ..<0.90: return CGFloat(3 - 5 * ease((p - 0.8) / 0.1))
    default: return CGFloat(-2 + 2 * ease((p - 0.9) / 0.1))
    }
}

private func drawEyes(_ c: inout GraphicsContext, mood: Mood, x1: CGFloat, x2: CGFloat, y: CGFloat, ink: Color, t: Double) {
    let round = StrokeStyle(lineWidth: 3, lineCap: .round)
    switch mood {
    case .happy:
        var p = Path()
        for x in [x1, x2] {
            p.move(to: CGPoint(x: x - 4, y: y + 1))
            p.addQuadCurve(to: CGPoint(x: x + 4, y: y + 1), control: CGPoint(x: x, y: y - 5))
        }
        c.stroke(p, with: .color(ink), style: round)
    case .alert:
        for x in [x1, x2] {
            c.fill(ellipse(x, y, 5.4, 5.4), with: .color(ink))
            c.fill(ellipse(x + 1.8, y - 2, 1.8, 1.8), with: .color(.white))
        }
    case .idle:
        var p = Path()
        for x in [x1, x2] {
            p.move(to: CGPoint(x: x - 4, y: y + 1))
            p.addQuadCurve(to: CGPoint(x: x + 4, y: y + 1), control: CGPoint(x: x, y: y + 4))
        }
        c.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
    case .working:
        let dx = glance(t)
        for x in [x1 + dx, x2 + dx] {
            c.fill(ellipse(x, y, 3.4, 4.8), with: .color(ink))
            c.fill(ellipse(x + 1.2, y - 1.8, 1.2, 1.2), with: .color(.white))
        }
    }
}

private func blush(_ c: inout GraphicsContext, _ points: [(CGFloat, CGFloat)], rx: CGFloat, ry: CGFloat) {
    for (x, y) in points {
        c.fill(ellipse(x, y, rx, ry), with: .color(Color(hex: 0xFF8FA3, opacity: 0.6)))
    }
}

// MARK: - Boo, the soft ghost

private enum BooArt {
    static let ink = Color(hex: 0x231B3A)

    static let body: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 8, y: 30))
        p.addCurve(to: CGPoint(x: 32, y: 4), control1: CGPoint(x: 8, y: 13), control2: CGPoint(x: 20, y: 4))
        p.addCurve(to: CGPoint(x: 56, y: 30), control1: CGPoint(x: 44, y: 4), control2: CGPoint(x: 56, y: 13))
        p.addLine(to: CGPoint(x: 56, y: 54))
        p.addCurve(to: CGPoint(x: 44, y: 54), control1: CGPoint(x: 52, y: 50), control2: CGPoint(x: 48, y: 50))
        p.addCurve(to: CGPoint(x: 32, y: 54), control1: CGPoint(x: 40, y: 58), control2: CGPoint(x: 36, y: 58))
        p.addCurve(to: CGPoint(x: 20, y: 54), control1: CGPoint(x: 28, y: 50), control2: CGPoint(x: 24, y: 50))
        p.addCurve(to: CGPoint(x: 8, y: 54), control1: CGPoint(x: 16, y: 58), control2: CGPoint(x: 12, y: 58))
        p.closeSubpath()
        return p
    }()

    static func draw(_ c: inout GraphicsContext, size: CGSize, mood: Mood, tint: Color, t: Double) {
        fit64(&c, size)
        c.translateBy(x: 0, y: -CGFloat(sin(t * 2 * .pi / 2.4)) * 1.6)

        if mood == .alert {
            var arm = c
            let angle = sin(t * 2 * .pi / 1.4) * 15
            arm.translateBy(x: 55, y: 36)
            arm.rotate(by: .degrees(angle))
            arm.translateBy(x: -55, y: -36)
            var p = Path()
            p.move(to: CGPoint(x: 54, y: 38))
            p.addCurve(to: CGPoint(x: 62, y: 26), control1: CGPoint(x: 60, y: 37), control2: CGPoint(x: 63, y: 32))
            arm.stroke(p, with: .color(tint), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
        }

        c.fill(body, with: .color(tint))
        var shine = Path()
        shine.move(to: CGPoint(x: 15, y: 21))
        shine.addCurve(to: CGPoint(x: 28, y: 10), control1: CGPoint(x: 17, y: 15), control2: CGPoint(x: 22, y: 11))
        c.stroke(shine, with: .color(.white.opacity(0.65)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        drawEyes(&c, mood: mood, x1: 24, x2: 40, y: 30, ink: ink, t: t)
        blush(&c, [(16.5, 38.5), (47.5, 38.5)], rx: 4, ry: 2.4)

        switch mood {
        case .happy:
            var m = Path()
            m.move(to: CGPoint(x: 28, y: 39.5))
            m.addQuadCurve(to: CGPoint(x: 36, y: 39.5), control: CGPoint(x: 32, y: 44.5))
            c.stroke(m, with: .color(ink), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        case .alert:
            c.fill(ellipse(32, 42, 3, 3.6), with: .color(ink))
        case .working:
            var m = Path()
            m.move(to: CGPoint(x: 29.5, y: 41))
            m.addLine(to: CGPoint(x: 34.5, y: 41))
            c.stroke(m, with: .color(ink), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        case .idle:
            var m = Path()
            m.move(to: CGPoint(x: 30, y: 41))
            m.addQuadCurve(to: CGPoint(x: 34, y: 41), control: CGPoint(x: 32, y: 42.5))
            c.stroke(m, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
    }
}

// MARK: - Tofu, the sticker cat

private enum TofuArt {
    static let ink = Color(hex: 0x2A1F1A)
    static let earPink = Color(hex: 0xF7A1B5)

    static func triangle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Path {
        var p = Path()
        p.move(to: a)
        p.addLine(to: b)
        p.addLine(to: c)
        p.closeSubpath()
        return p
    }

    static func draw(_ c: inout GraphicsContext, size: CGSize, mood: Mood, tint: Color, t: Double) {
        fit64(&c, size)
        c.translateBy(x: 0, y: -CGFloat(sin(t * 2 * .pi / 2.4)) * 1.4)
        let line = StrokeStyle(lineWidth: 3, lineJoin: .round)

        let leftEar = triangle(CGPoint(x: 10, y: 30), CGPoint(x: 13, y: 6), CGPoint(x: 29, y: 18))
        c.fill(leftEar, with: .color(tint))
        c.stroke(leftEar, with: .color(ink), style: line)
        c.fill(triangle(CGPoint(x: 15.5, y: 21), CGPoint(x: 16.5, y: 13), CGPoint(x: 22.5, y: 18)), with: .color(earPink))

        // The right ear twitches now and then.
        var ear = c
        let p = (t / 3.2).truncatingRemainder(dividingBy: 1)
        let twitch: Double = p > 0.86 ? sin((p - 0.86) / 0.14 * .pi * 2) * -12 : 0
        ear.translateBy(x: 46, y: 24)
        ear.rotate(by: .degrees(twitch))
        ear.translateBy(x: -46, y: -24)
        let rightEar = triangle(CGPoint(x: 54, y: 30), CGPoint(x: 51, y: 6), CGPoint(x: 35, y: 18))
        ear.fill(rightEar, with: .color(tint))
        ear.stroke(rightEar, with: .color(ink), style: line)
        ear.fill(triangle(CGPoint(x: 48.5, y: 21), CGPoint(x: 47.5, y: 13), CGPoint(x: 41.5, y: 18)), with: .color(earPink))

        let head = ellipse(32, 34, 24, 19)
        c.fill(head, with: .color(tint))
        c.stroke(head, with: .color(ink), lineWidth: 3)

        drawEyes(&c, mood: mood, x1: 23, x2: 41, y: 33, ink: ink, t: t)
        blush(&c, [(15, 40), (49, 40)], rx: 3.6, ry: 2.2)

        let nose = triangle(CGPoint(x: 30, y: 38.5), CGPoint(x: 34, y: 38.5), CGPoint(x: 32, y: 41.1))
        c.fill(nose, with: .color(Color(hex: 0xF07A93)))

        switch mood {
        case .alert:
            c.fill(ellipse(32, 44, 2.6, 3), with: .color(ink))
        case .happy:
            var m = Path()
            m.move(to: CGPoint(x: 27, y: 42))
            m.addQuadCurve(to: CGPoint(x: 32, y: 42), control: CGPoint(x: 29.5, y: 46))
            m.addQuadCurve(to: CGPoint(x: 37, y: 42), control: CGPoint(x: 34.5, y: 46))
            c.stroke(m, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        default:
            var m = Path()
            m.move(to: CGPoint(x: 28, y: 42.5))
            m.addQuadCurve(to: CGPoint(x: 32, y: 42.5), control: CGPoint(x: 30, y: 44.5))
            m.addQuadCurve(to: CGPoint(x: 36, y: 42.5), control: CGPoint(x: 34, y: 44.5))
            c.stroke(m, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }

        var whiskers = Path()
        for (a, b) in [((3.0, 35.0), (12.0, 35.0)), ((3, 40.5), (12, 38.5)), ((61, 35), (52, 35)), ((61, 40.5), (52, 38.5))] {
            whiskers.move(to: CGPoint(x: a.0, y: a.1))
            whiskers.addLine(to: CGPoint(x: b.0, y: b.1))
        }
        c.stroke(whiskers, with: .color(ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

        // Paws on the ledge; they tap when Tofu needs you.
        for (i, x) in [21.0, 43.0].enumerated() {
            let tap = mood == .alert ? CGFloat(abs(sin(t * 2 * .pi / 0.9 + Double(i) * 1.6))) * 3 : 0
            let paw = ellipse(x, 55 - tap, 7.5, 5)
            c.fill(paw, with: .color(tint))
            c.stroke(paw, with: .color(ink), lineWidth: 3)
        }
    }
}

// MARK: - Pixel buddies

private struct PixelRect {
    var x: Int, y: Int, w: Int = 1, h: Int = 1
    var color: Color
}

private enum PixelGrid {
    /// Sets up a context where one unit is one pixel cell, for a grid of the given view box.
    static func setup(_ c: inout GraphicsContext, size: CGSize, originX: CGFloat, originY: CGFloat, width: CGFloat, height: CGFloat) {
        let s = min(size.width / width, size.height / height)
        c.translateBy(x: (size.width - width * s) / 2, y: (size.height - height * s) / 2)
        c.scaleBy(x: s, y: s)
        c.translateBy(x: -originX, y: -originY)
    }

    static func draw(_ c: inout GraphicsContext, map: [String], colors: [Character: Color], dy: Int = 0) {
        for (y, row) in map.enumerated() {
            let chars = Array(row)
            var x = 0
            while x < chars.count {
                let ch = chars[x]
                guard ch != ".", let color = colors[ch] else { x += 1; continue }
                let start = x
                while x < chars.count && chars[x] == ch { x += 1 }
                // A hair of overlap hides seams between cells when scaled.
                c.fill(Path(CGRect(x: CGFloat(start), y: CGFloat(y + dy), width: CGFloat(x - start) + 0.02, height: 1.02)), with: .color(color))
            }
        }
    }

    static func draw(_ c: inout GraphicsContext, _ rects: [PixelRect]) {
        for r in rects {
            c.fill(Path(CGRect(x: r.x, y: r.y, width: r.w, height: r.h)), with: .color(r.color))
        }
    }

    /// Two-frame step used for pixel motion (no tweening, on purpose).
    static func step(_ t: Double, period: Double) -> Bool {
        Int(floor(t / (period / 2))) % 2 == 1
    }
}

private enum BitArt {
    static let ink = Color(hex: 0x0B0B10)
    static let map = [
        "....XXXXXX....", "..XXXXXXXXXX..", ".XXXXXXXXXXXX.", "XXXXXXXXXXXXXX",
        "XXXXXXXXXXXXXX", "XXXXXXXXXXXXXX", "XXXXXXXXXXXXXX", "XXXXXXXXXXXXXX",
        "XXXXXXXXXXXXXX", "XX.XXX..XXX.XX", "X...XX..XX...X",
    ]

    static func draw(_ c: inout GraphicsContext, size: CGSize, mood: Mood, tint: Color, t: Double) {
        PixelGrid.setup(&c, size: size, originX: -1, originY: 0, width: 17, height: 14)
        if PixelGrid.step(t, period: 1) { c.translateBy(x: 0, y: -1) }
        PixelGrid.draw(&c, map: map, colors: ["X": tint], dy: 2)
        let pink = Color(hex: 0xFF7BC5)
        let yellow = Color(hex: 0xFFD25E)
        var rects: [PixelRect] = []
        switch mood {
        case .happy:
            rects = [(3, 7), (4, 6), (5, 7), (8, 7), (9, 6), (10, 7)].map { PixelRect(x: $0.0, y: $0.1, color: ink) }
            rects.append(PixelRect(x: 6, y: 9, w: 2, color: ink))
        case .alert:
            rects = [
                PixelRect(x: 3, y: 5, w: 2, h: 3, color: ink), PixelRect(x: 9, y: 5, w: 2, h: 3, color: ink),
                PixelRect(x: 3, y: 5, color: .white), PixelRect(x: 9, y: 5, color: .white),
                PixelRect(x: 6, y: 9, w: 2, h: 2, color: ink),
                PixelRect(x: 1, y: 8, color: pink), PixelRect(x: 12, y: 8, color: pink),
            ]
            if !PixelGrid.step(t, period: 1) {
                rects += [PixelRect(x: 15, y: 1, h: 3, color: yellow), PixelRect(x: 15, y: 5, color: yellow)]
            }
        case .idle:
            rects = [PixelRect(x: 3, y: 7, w: 2, color: ink), PixelRect(x: 9, y: 7, w: 2, color: ink),
                     PixelRect(x: 13, y: 0, w: 2, color: tint), PixelRect(x: 14, y: 1, color: tint), PixelRect(x: 13, y: 2, w: 2, color: tint)]
        case .working:
            let dx = PixelGrid.step(t, period: 2) ? 1 : 0
            rects = [
                PixelRect(x: 3 + dx, y: 6, w: 2, h: 2, color: ink), PixelRect(x: 9 + dx, y: 6, w: 2, h: 2, color: ink),
                PixelRect(x: 3 + dx, y: 6, color: .white), PixelRect(x: 9 + dx, y: 6, color: .white),
                PixelRect(x: 1, y: 8, color: pink), PixelRect(x: 12, y: 8, color: pink),
            ]
        }
        PixelGrid.draw(&c, rects)
    }
}

private enum EdithArt {
    static let ink = Color(hex: 0x1A1A3A)
    static let skin = Color(hex: 0xF6F1F4)
    static let map = [
        "......OOOOOO......", ".....OHHHHHHO.....", "....OHHHHHHHHO....", "....OHHhHHHHHO....",
        ".....OTTTTTTO.....", "...OOHHHHHHHHOO...", "..OHHHHHHHHHHHHO..", ".OHHHHHHHHHSSSHHO.",
        ".OHHHHHSSSSSSSSHO.", ".OHHOOOOOSOOOOOHO.", ".OHHOLLLOOOLLLOHO.", ".OHHOLLLOSOLLLOHO.",
        ".OHHSOOOSSSOOOSHO.", ".OHHSSSSSSSSSSSHO.", ".OHHHSSSSMMSSSHHO.", "..OHHOSSSSSSSOHHO.",
        "...OOOOSSSSOOOO...", ".......OSSO.......", "...OOBBOWWOBBOO...", "..OBBBBBOZOBBBBBO.",
        ".OBBBBBBBZBBBBBBBO",
    ]

    static func draw(_ c: inout GraphicsContext, size: CGSize, mood: Mood, tint: Color, t: Double) {
        PixelGrid.setup(&c, size: size, originX: -0.5, originY: -0.5, width: 20, height: 22)
        if PixelGrid.step(t, period: 1.2) { c.translateBy(x: 0, y: -1) }
        PixelGrid.draw(&c, map: map, colors: [
            "O": ink, "H": Color(hex: 0xC8435A), "h": Color(hex: 0xEE7B8A), "T": Color(hex: 0x3BC9D6),
            "S": skin, "L": Color(hex: 0x7BEBDF), "M": Color(hex: 0xD97A8A), "B": tint, "W": skin,
            "Z": Color(hex: 0x145A78),
        ])
        var rects: [PixelRect] = []
        switch mood {
        case .idle:
            let dim = Color(hex: 0x3A6A70)
            rects = [
                PixelRect(x: 5, y: 10, w: 3, h: 2, color: dim), PixelRect(x: 11, y: 10, w: 3, h: 2, color: dim),
                PixelRect(x: 5, y: 11, w: 3, color: ink), PixelRect(x: 11, y: 11, w: 3, color: ink),
                PixelRect(x: 14, y: 0, w: 2, color: tint), PixelRect(x: 15, y: 1, color: tint), PixelRect(x: 14, y: 2, w: 2, color: tint),
            ]
        case .happy:
            rects = [(5, 11), (6, 10), (7, 11), (11, 11), (12, 10), (13, 11), (8, 14), (11, 14)].map { PixelRect(x: $0.0, y: $0.1, color: ink) }
            rects += [PixelRect(x: 9, y: 14, w: 2, color: skin), PixelRect(x: 9, y: 15, w: 2, color: ink)]
        case .alert:
            if !PixelGrid.step(t, period: 1) {
                rects = [PixelRect(x: 5, y: 10, w: 3, h: 2, color: .white), PixelRect(x: 11, y: 10, w: 3, h: 2, color: .white)]
            }
            rects += [
                PixelRect(x: 6, y: 11, color: ink), PixelRect(x: 12, y: 11, color: ink), PixelRect(x: 9, y: 14, w: 2, h: 2, color: ink),
                // Hand to the temple, her signature pose.
                PixelRect(x: 14, y: 4, w: 5, h: 6, color: ink), PixelRect(x: 15, y: 5, w: 3, h: 4, color: skin),
                PixelRect(x: 15, y: 6, w: 3, color: ink), PixelRect(x: 15, y: 10, w: 4, h: 11, color: ink),
                PixelRect(x: 16, y: 10, w: 2, h: 10, color: tint),
            ]
        case .working:
            let dx = PixelGrid.step(t, period: 2) ? 1 : 0
            rects = [PixelRect(x: 6 + dx, y: 11, color: ink), PixelRect(x: 12 + dx, y: 11, color: ink)]
        }
        PixelGrid.draw(&c, rects)
    }
}
