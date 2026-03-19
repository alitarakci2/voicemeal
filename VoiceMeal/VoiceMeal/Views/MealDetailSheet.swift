//
//  MealDetailSheet.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct MealDetailSheet: View {
    let suggestion: MealPlanSuggestion
    let onSaveToFood: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showSavedToast = false

    private var mealTypeLabel: String {
        switch suggestion.mealType {
        case "breakfast": return "Kahvalt\u{0131}"
        case "lunch": return "\u{00D6}\u{011F}le Yeme\u{011F}i"
        case "dinner": return "Ak\u{015F}am Yeme\u{011F}i"
        default: return "\u{00D6}\u{011F}\u{00FC}n"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hero
                    HStack {
                        Text(suggestion.emoji)
                            .font(.system(size: 48))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.name)
                                .font(Theme.titleFont)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.textPrimary)
                            Text(mealTypeLabel)
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    // Macro breakdown
                    HStack(spacing: 16) {
                        macroBox("Kalori", value: "\(suggestion.calories)", unit: "kcal", color: Theme.accent)
                        macroBox("Protein", value: "\(Int(suggestion.protein))", unit: "g", color: Theme.blue)
                        macroBox("Karb", value: "\(Int(suggestion.carbs))", unit: "g", color: Theme.orange)
                        macroBox("Ya\u{011F}", value: "\(Int(suggestion.fat))", unit: "g", color: .yellow)
                    }

                    // Ingredients
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Malzemeler")
                            .font(Theme.headlineFont)
                            .foregroundStyle(Theme.textPrimary)

                        ForEach(suggestion.ingredients, id: \.self) { ingredient in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Theme.accent)
                                    .frame(width: 6, height: 6)
                                Text(ingredient)
                                    .font(Theme.bodyFont)
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                    }

                    // Prep note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Haz\u{0131}rlan\u{0131}\u{015F}\u{0131}")
                            .font(Theme.headlineFont)
                            .foregroundStyle(Theme.textPrimary)

                        Text(suggestion.prepNote)
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Save button
                    Button {
                        onSaveToFood()
                        showSavedToast = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            dismiss()
                        }
                    } label: {
                        Text("Bu \u{00D6}\u{011F}\u{00FC}n\u{00FC} Kaydet")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .navigationTitle("\u{00D6}\u{011F}\u{00FC}n Detay\u{0131}")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    Text("Kaydedildi \u{2713}")
                        .font(Theme.bodyFont)
                        .fontWeight(.medium)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Theme.green)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 20)
                }
            }
            .animation(.easeInOut, value: showSavedToast)
        }
        .presentationDetents([.medium, .large])
    }

    private func macroBox(_ label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
            Text(unit)
                .font(Theme.microFont)
                .foregroundStyle(Theme.textTertiary)
            Text(label)
                .font(Theme.microFont)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
