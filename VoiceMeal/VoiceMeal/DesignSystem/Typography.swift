import SwiftUI

enum BrandTypography {
    static func display() -> Font          { .system(size: 44, weight: .bold, design: .rounded) }
    static func displayNumeric() -> Font   { .system(size: 32, weight: .bold, design: .rounded) }
    static func title1() -> Font           { .system(size: 28, weight: .semibold) }
    static func title2() -> Font           { .system(size: 22, weight: .medium) }
    static func title3() -> Font           { .system(size: 18, weight: .medium) }
    static func body() -> Font             { .system(size: 16, weight: .regular) }
    static func bodyMedium() -> Font       { .system(size: 16, weight: .medium) }
    static func bodySmall() -> Font        { .system(size: 14, weight: .regular) }
    static func statValue() -> Font        { .system(size: 24, weight: .semibold, design: .rounded) }
    static func statValueLarge() -> Font   { .system(size: 36, weight: .bold, design: .rounded) }
    static func statValueHero() -> Font    { .system(size: 56, weight: .bold, design: .rounded) }
    static func monoMicro() -> Font        { .system(size: 11, weight: .medium, design: .monospaced) }
    static func monoCaption() -> Font      { .system(size: 12, weight: .medium, design: .monospaced) }
    static func caption() -> Font          { .system(size: 12, weight: .regular) }
}
