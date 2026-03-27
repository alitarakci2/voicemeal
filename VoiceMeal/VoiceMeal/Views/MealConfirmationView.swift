//
//  MealConfirmationView.swift
//  VoiceMeal
//

import SwiftUI

// MARK: - Emoji Helper

func mealEmoji(for name: String) -> String {
    let lower = name.lowercased()
    if lower.contains("tavuk") || lower.contains("chicken") { return "\u{1F357}" }
    if lower.contains("dana") || lower.contains("et") || lower.contains("beef") { return "\u{1F969}" }
    if lower.contains("bal\u{0131}k") || lower.contains("somon") || lower.contains("fish") { return "\u{1F41F}" }
    if lower.contains("yumurta") || lower.contains("egg") { return "\u{1F95A}" }
    if lower.contains("s\u{00FC}t") || lower.contains("yo\u{011F}urt") || lower.contains("milk") { return "\u{1F95B}" }
    if lower.contains("ayran") { return "\u{1F95B}" }
    if lower.contains("ekmek") || lower.contains("bread") { return "\u{1F35E}" }
    if lower.contains("\u{00E7}orba") || lower.contains("soup") { return "\u{1F372}" }
    if lower.contains("pilav") || lower.contains("pirin\u{00E7}") || lower.contains("rice") { return "\u{1F35A}" }
    if lower.contains("makarna") || lower.contains("pasta") { return "\u{1F35D}" }
    if lower.contains("salata") || lower.contains("salad") { return "\u{1F957}" }
    if lower.contains("meyve") || lower.contains("fruit") { return "\u{1F34E}" }
    if lower.contains("peynir") || lower.contains("cheese") { return "\u{1F9C0}" }
    if lower.contains("kahve") || lower.contains("coffee") { return "\u{2615}" }
    if lower.contains("\u{00E7}ay") || lower.contains("tea") { return "\u{1FAD6}" }
    return "\u{1F37D}\u{FE0F}"
}
