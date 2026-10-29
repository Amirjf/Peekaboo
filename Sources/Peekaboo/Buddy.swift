import SwiftUI

enum Mood {
    case idle, working, happy, alert
}

/// The mascots. Each one is a skin: same states, its own drawing, voice and sounds.
enum Buddy: String, CaseIterable, Identifiable {
    case boo, tofu, bit, edith

    var id: String { rawValue }

    var name: String {
        switch self {
        case .boo: "Boo"
        case .tofu: "Tofu"
        case .bit: "Bit"
        case .edith: "Edith"
        }
    }

    /// Session colors. Each session gets one, so several Claudes are easy to tell apart.
    var tints: [Color] {
        switch self {
        case .boo: [Color(hex: 0xCDBBFF), Color(hex: 0xFFC6AE), Color(hex: 0xA9EED3)]
        case .tofu: [Color(hex: 0xFFF1DC), Color(hex: 0xFFC9D6), Color(hex: 0xCFE6FF)]
        case .bit: [Color(hex: 0x7CFFB2), Color(hex: 0xFF7BC5), Color(hex: 0x7FD8FF)]
        case .edith: [Color(hex: 0x2FA6C4), Color(hex: 0xE05A7A), Color(hex: 0xF2B544)]
        }
    }

    var isPixel: Bool { self == .bit || self == .edith }

    func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        isPixel ? .system(size: size, weight: weight, design: .monospaced) : .system(size: size, weight: weight, design: .rounded)
    }

    var doneHeading: String {
        switch self {
        case .boo: "Boo! All done"
        case .tofu: "Done! Purr"
        case .bit: "DONE!"
        case .edith: "Task complete"
        }
    }

    var needsHeading: String {
        switch self {
        case .boo: "Psst, I need you"
        case .tofu: "Mrow? Need you"
        case .bit: "NEED YOU!"
        case .edith: "Edith here: need you"
        }
    }

    var doneSound: String {
        switch self {
        case .boo: "Pop"
        case .tofu: "Purr"
        case .bit: "Tink"
        case .edith: "Glass"
        }
    }

    var needsSound: String {
        switch self {
        case .boo: "Bottle"
        case .tofu: "Morse"
        case .bit: "Funk"
        case .edith: "Ping"
        }
    }

    func tint(for sessionId: String) -> Color {
        var hash: UInt32 = 5381
        for b in sessionId.utf8 { hash = (hash &* 33) &+ UInt32(b) }
        return tints[Int(hash % UInt32(tints.count))]
    }
}
