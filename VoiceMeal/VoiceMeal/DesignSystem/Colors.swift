import SwiftUI

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

enum BrandColors {
    // Indio canvas (shared brand)
    static let black       = Color(hex: "#0A0A0A")
    static let surface     = Color(hex: "#141414")
    static let surface2    = Color(hex: "#1F1F1F")
    static let border      = Color(hex: "#262626")
    static let borderHi    = Color(hex: "#3A3A3A")
    static let text        = Color(hex: "#F5F5F5")
    static let textMuted   = Color(hex: "#A3A3A3")
    static let textDim     = Color(hex: "#8A8A8A")

    // Indio orange (PROMINENT in VoiceMeal — brand presence woven in)
    static let indioOrange     = Color(hex: "#FF6B1A")
    static let indioOrangeDim  = Color(hex: "#CC5510")
    static let indioOrangeSoft = Color(hex: "#FF8B4A")

    // VoiceMeal emerald (PRIMARY APP ACCENT — replaces purple)
    static let vmEmerald      = Color(hex: "#1D9E75")
    static let vmEmeraldDim   = Color(hex: "#146B4F")
    static let vmEmeraldSoft  = Color(hex: "#2EBC8E")

    // Functional / semantic
    static let macroProtein = Color(hex: "#0A84FF")
    static let macroCarb    = Color(hex: "#FF9F0A")
    static let macroFat     = Color(hex: "#FF6B9D")
    static let success      = Color(hex: "#34C759")
    static let warning      = Color(hex: "#FFA533")
    static let danger       = Color(hex: "#FF453A")
    static let trackBg      = Color(hex: "#2A2A38")
}
