//
//  MealSuggestionCardView.swift
//  VoiceMeal
//

import SwiftUI

struct MealSuggestionCardView: View {
    let suggestion: MealPlanSuggestion
    let isSelected: Bool
    let isDimmed: Bool
    let onSelect: () -> Void
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(suggestion.emoji)
                    .font(.system(size: 24))
                Text(suggestion.name)
                    .font(Theme.bodyFont)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Macros
            Text("\(suggestion.calories) kcal | P:\(Int(suggestion.protein))g K:\(Int(suggestion.carbs))g Y:\(Int(suggestion.fat))g")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textSecondary)

            // Ingredients
            Text(suggestion.ingredients.joined(separator: ", "))
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(2)

            // Prep note
            Text(suggestion.prepNote)
                .font(Theme.microFont)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(2)

            // Select button
            Button {
                onSelect()
            } label: {
                HStack {
                    Spacer()
                    if isSelected {
                        Label("Se\u{00E7}ildi", systemImage: "checkmark.circle.fill")
                            .font(Theme.captionFont)
                            .fontWeight(.semibold)
                    } else {
                        Text("Se\u{00E7}")
                            .font(Theme.captionFont)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
                .background(isSelected ? Theme.green.opacity(0.2) : Theme.accent.opacity(0.15))
                .foregroundStyle(isSelected ? Theme.green : Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(isSelected)
        }
        .padding(12)
        .frame(width: 240)
        .background(Theme.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Theme.green : Theme.cardBorder, lineWidth: isSelected ? 2 : 1)
        )
        .opacity(isDimmed ? 0.5 : 1.0)
        .onTapGesture {
            onTap()
        }
    }
}
