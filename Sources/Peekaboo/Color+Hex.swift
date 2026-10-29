import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    static let doneGreen = Color(hex: 0x93F2C8)
    static let needsAmber = Color(hex: 0xFFCB6B)
    static let workBlue = Color(hex: 0xA9B8FF)
}
