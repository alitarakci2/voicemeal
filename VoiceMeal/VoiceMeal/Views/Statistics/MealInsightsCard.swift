//
//  MealInsightsCard.swift
//  VoiceMeal
//

import SwiftUI

struct MealInsightsCard: View {
    let entries: [FoodEntry]
    let appLanguage: String

    // Top 5 most eaten foods by frequency
    var topFoods: [(name: String, count: Int, avgCalories: Int)] {
        let grouped = Dictionary(grouping: entries) {
            $0.name.lowercased().trimmingCharacters(in: .whitespaces)
        }
        return grouped.map { name, items in
            (
                name: items.first?.name.capitalized ?? name,
                count: items.count,
                avgCalories: items.reduce(0) { $0 + $1.calories } / items.count
            )
        }
        .sorted { $0.count > $1.count }
        .prefix(5)
        .map { $0 }
    }

    // Meal frequency by time of day
    var mealTiming: (morning: Int, afternoon: Int, evening: Int, night: Int) {
        var morning = 0, afternoon = 0, evening = 0, night = 0
        for entry in entries {
            let hour = Calendar.current.component(.hour, from: entry.date)
            switch hour {
            case 6..<12:  morning += 1
            case 12..<17: afternoon += 1
            case 17..<21: evening += 1
            default:      night += 1
            }
        }
        return (morning, afternoon, evening, night)
    }

    // Average meals per day
    var avgMealsPerDay: Double {
        let days = Set(entries.map {
            Calendar.current.startOfDay(for: $0.date)
        }).count
        return days > 0 ? Double(entries.count) / Double(days) : 0
    }

    // Average calories per meal
    var avgCaloriesPerMeal: Int {
        entries.isEmpty ? 0 :
            entries.reduce(0) { $0 + $1.calories } / entries.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "fork.knife.circle.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 16))
                    .frame(width: 30, height: 30)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.s))

                Text(L.mealInsights.localized)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                Spacer()

                Text("\(entries.count) " +
                     L.entriesLabel.localized)
                    .font(.caption2)
                    .foregroundStyle(BrandColors.textMuted)
            }

            Divider().opacity(0.2)

            // Quick stats row
            HStack(spacing: 0) {
                QuickStatCell(
                    value: String(format: "%.1f", avgMealsPerDay),
                    label: L.mealsPerDayStat.localized,
                    color: Theme.accent
                )

                Divider()
                    .frame(height: 40)
                    .opacity(0.2)

                QuickStatCell(
                    value: "\(avgCaloriesPerMeal)",
                    label: L.kcalPerMeal.localized,
                    color: Theme.warning
                )

                Divider()
                    .frame(height: 40)
                    .opacity(0.2)

                QuickStatCell(
                    value: "\(topFoods.first?.count ?? 0)",
                    label: L.mostEatenCount.localized,
                    color: Theme.green
                )
            }

            if !topFoods.isEmpty {
                Divider().opacity(0.2)

                // Top foods
                Text(L.mostEatenTitle.localized)
                    .font(.caption.bold())
                    .foregroundStyle(BrandColors.textDim)
                    .textCase(.uppercase)
                    .tracking(0.5)

                ForEach(topFoods.prefix(5), id: \.name) { food in
                    HStack(spacing: 10) {
                        Text(emojiFor(food.name))
                            .font(.body)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(food.name)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("\(food.avgCalories) kcal " +
                                 L.avgShort.localized)
                                .font(.caption2)
                                .foregroundStyle(BrandColors.textMuted)
                        }

                        Spacer()

                        // Frequency badge
                        Text("\(food.count)x")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            Divider().opacity(0.2)

            // Meal timing
            Text(appLanguage == "en"
                 ? "Meal Timing" : "Öğün Saatleri")
                .font(.caption.bold())
                .foregroundStyle(BrandColors.textDim)
                .textCase(.uppercase)
                .tracking(0.5)

            let timing = mealTiming
            let total = max(1, entries.count)

            VStack(spacing: 6) {
                TimingRow(
                    icon: "sunrise.fill",
                    iconColor: Theme.warning,
                    label: appLanguage == "en"
                        ? "Morning (6-12)" : "Sabah (6-12)",
                    count: timing.morning,
                    total: total
                )
                TimingRow(
                    icon: "sun.max.fill",
                    iconColor: Theme.indioOrange,
                    label: appLanguage == "en"
                        ? "Afternoon (12-17)" : "Öğleden Sonra (12-17)",
                    count: timing.afternoon,
                    total: total
                )
                TimingRow(
                    icon: "sunset.fill",
                    iconColor: Theme.danger,
                    label: appLanguage == "en"
                        ? "Evening (17-21)" : "Akşam (17-21)",
                    count: timing.evening,
                    total: total
                )
                TimingRow(
                    icon: "moon.fill",
                    iconColor: Theme.accent,
                    label: appLanguage == "en"
                        ? "Night (21+)" : "Gece (21+)",
                    count: timing.night,
                    total: total
                )
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.l))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.l)
                .stroke(BrandColors.border, lineWidth: 0.5)
        )
    }

    func emojiFor(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("yumurta") || lower.contains("egg") { return "🥚" }
        if lower.contains("tavuk") || lower.contains("chicken") { return "🍗" }
        if lower.contains("et") || lower.contains("dana") { return "🥩" }
        if lower.contains("balık") || lower.contains("somon") { return "🐟" }
        if lower.contains("süt") || lower.contains("milk") { return "🥛" }
        if lower.contains("yoğurt") || lower.contains("yogurt") { return "🥛" }
        if lower.contains("ekmek") || lower.contains("bread") { return "🍞" }
        if lower.contains("çorba") || lower.contains("soup") { return "🍲" }
        if lower.contains("pilav") || lower.contains("rice") { return "🍚" }
        if lower.contains("makarna") || lower.contains("pasta") { return "🍝" }
        if lower.contains("salata") || lower.contains("salad") { return "🥗" }
        if lower.contains("meyve") || lower.contains("fruit") { return "🍎" }
        if lower.contains("peynir") || lower.contains("cheese") { return "🧀" }
        if lower.contains("yulaf") || lower.contains("oat") { return "🥣" }
        if lower.contains("protein") { return "💪" }
        return "🍽️"
    }
}

struct QuickStatCell: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(BrandColors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TimingRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let count: Int
    let total: Int

    var progress: Double {
        Double(count) / Double(total)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.system(size: 12))
                .frame(width: 20)

            Text(label)
                .font(.caption)
                .foregroundStyle(BrandColors.textMuted)
                .frame(width: 130, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Radius.xs)
                        .fill(BrandColors.surface2)
                    RoundedRectangle(cornerRadius: Radius.xs)
                        .fill(iconColor)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 5)

            Text("\(count)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, alignment: .trailing)
        }
    }
}
