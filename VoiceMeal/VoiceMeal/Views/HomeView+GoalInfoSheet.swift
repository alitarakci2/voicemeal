//
//  HomeView+GoalInfoSheet.swift
//  VoiceMeal
//

import SwiftUI

extension HomeView {

    // MARK: - Goal Info Sheet

    var goalInfoSheet: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.gradientTop, Color(hex: "0A0A0F")],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text(L.goalDetails.localized)
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        showGoalInfo = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Theme.gradientTop.opacity(0.95))
                .overlay(Divider().opacity(0.2), alignment: .bottom)

                ScrollView {
                    VStack(spacing: 14) {
                        tdeeSourceCard

                        if goalEngine.isCalorieClamped || goalEngine.isCapped {
                            warningsCard
                        }

                        HStack(spacing: 12) {
                            MetricInfoCard(
                                icon: "flame.fill",
                                iconColor: Theme.orange,
                                label: "TDEE",
                                value: "\(Int(goalEngine.tdee))",
                                unit: "kcal",
                                tooltip: Tooltips.tdee
                            )
                            MetricInfoCard(
                                icon: "arrow.down.circle.fill",
                                iconColor: Theme.accent,
                                label: L.dailyTarget.localized,
                                value: "\(goalEngine.dailyCalorieTarget)",
                                unit: "kcal"
                            )
                        }

                        HStack(spacing: 12) {
                            MetricInfoCard(
                                icon: "minus.circle.fill",
                                iconColor: Theme.red,
                                label: L.deficit.localized,
                                value: "\(Int(goalEngine.cappedDailyDeficit))",
                                unit: "kcal",
                                tooltip: Tooltips.deficit
                            )
                            MetricInfoCard(
                                icon: "scalemass.fill",
                                iconColor: Theme.green,
                                label: L.estWeekly.localized,
                                value: String(format: "%.2f", goalEngine.projectedWeeklyLossKg),
                                unit: "kg"
                            )
                        }

                        healthDataCard

                        formulaBreakdownCard
                    }
                    .padding()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Nutrition Check Sheet

    func generateNutritionCheckText(entries: [FoodEntry]) -> String {
        var lines: [String] = []
        for entry in entries {
            if !entry.amount.isEmpty {
                lines.append("\(entry.amount) \(entry.name)")
            } else {
                lines.append(entry.name)
            }
        }
        let foodList = lines.joined(separator: ", ")
        return String(format: "nutrition_check_prompt".localized, foodList)
    }

    var nutritionCheckSheet: some View {
        let text = generateNutritionCheckText(entries: todayEntries)
        return NavigationStack {
            ScrollView {
                Text(text)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textPrimary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.background)
            .navigationTitle("nutrition_check".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L.close.localized) {
                        showNutritionCheck = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = text
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }

    // MARK: - TDEE Source Helpers

    var tdeeSourceIcon: String {
        if goalEngine.isUsingExtrapolatedTDEE { return "iphone" }
        if goalEngine.usingHealthKit { return "iphone" }
        if healthKitService.dayFraction < 0.40 && healthKitService.isAvailable { return "function" }
        if goalEngine.healthKitBurn > 0 { return "hourglass" }
        return "function"
    }

    var tdeeSourceColor: Color {
        if goalEngine.isUsingExtrapolatedTDEE { return Theme.blue }
        if goalEngine.usingHealthKit { return Theme.green }
        if healthKitService.dayFraction < 0.40 && healthKitService.isAvailable { return Theme.orange }
        if goalEngine.healthKitBurn > 0 { return Theme.orange }
        return Theme.textSecondary
    }

    var tdeeSourceTitle: String {
        if goalEngine.isUsingExtrapolatedTDEE {
            return L.extrapolatedTdee.localized
        }
        if goalEngine.usingHealthKit {
            return "Apple Health"
        }
        if healthKitService.dayFraction < 0.40 && healthKitService.isAvailable {
            return L.earlyMorning.localized
        }
        if goalEngine.healthKitBurn > 0 {
            return L.healthkitInsufficient.localized
        }
        return L.calculatedFormula.localized
    }

    var tdeeSourceSubtitle: String {
        if goalEngine.isUsingExtrapolatedTDEE {
            let pct = Int(healthKitService.dayFraction * 100)
            return String(format: L.dayExtrapolatedFormat.localized, pct)
        }
        if goalEngine.usingHealthKit {
            return L.realtimeBurn.localized
        }
        if healthKitService.dayFraction < 0.40 && healthKitService.isAvailable {
            return L.waitingData.localized
        }
        if goalEngine.healthKitBurn > 0 {
            return L.bmrEstimate.localized
        }
        return "\(Int(goalEngine.tdee)) kcal"
    }

    var confidenceColor: Color {
        let conf = goalEngine.tdeeConfidence.lowercased()
        if conf.contains("yüksek") || conf.contains("high") { return Theme.green }
        if conf.contains("orta") || conf.contains("med") { return Theme.orange }
        return Theme.red
    }

    // MARK: - Goal Info Cards

    var tdeeSourceCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: tdeeSourceIcon)
                    .foregroundColor(tdeeSourceColor)
                    .font(.system(size: 18))
                    .frame(width: 36, height: 36)
                    .background(tdeeSourceColor.opacity(0.15))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tdeeSourceTitle)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text(tdeeSourceSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(goalEngine.tdeeConfidence)
                    .font(.caption.bold())
                    .foregroundColor(confidenceColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(confidenceColor.opacity(0.15))
                    .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tdeeSourceColor.opacity(0.3), lineWidth: 1)
        )
    }

    var warningsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if goalEngine.isCalorieClamped {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("min_healthy_calorie".localized)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            if goalEngine.isCapped {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("goal_too_aggressive".localized)
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                        if let reason = goalEngine.capReason {
                            Text(reason)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    var healthDataCard: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 13))
                    .frame(width: 26, height: 26)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(8)
                Text(L.healthData.localized)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
            }

            Divider().opacity(0.2)

            if let vo2 = goalEngine.vo2Max {
                modernInfoRow(
                    label: "VO2 Max",
                    value: "\(String(format: "%.1f", vo2)) ml/kg/min",
                    valueColor: Theme.green,
                    tooltip: Tooltips.vo2Max
                )
                modernInfoRow(
                    label: L.fitnessLevel.localized,
                    value: goalEngine.vo2MaxLevel,
                    valueColor: Theme.blue
                )
            } else {
                modernInfoRow(
                    label: "VO2 Max",
                    value: "no_data".localized,
                    valueColor: Theme.textSecondary,
                    tooltip: Tooltips.vo2Max
                )
            }

            if let w = goalEngine.latestWeightFromHealth {
                let dateStr = goalEngine.latestWeightDate?.formatted(.dateTime.day().month(.abbreviated)) ?? ""
                modernInfoRow(
                    label: L.weightHealth.localized,
                    value: "\(String(format: "%.2f", w)) kg \u{2014} \(dateStr)",
                    valueColor: .white
                )
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    var formulaBreakdownCard: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "function")
                    .foregroundColor(Theme.accent)
                    .font(.system(size: 13))
                    .frame(width: 26, height: 26)
                    .background(Theme.accent.opacity(0.15))
                    .cornerRadius(8)
                Text(L.formulaBreakdown.localized)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
            }

            Divider().opacity(0.2)

            modernInfoRow(label: "BMR", value: "\(Int(goalEngine.bmr)) kcal", tooltip: Tooltips.bmr)
            modernInfoRow(
                label: L.activityMultiplier.localized,
                value: String(format: "%.2fx", goalEngine.activityMultiplier),
                tooltip: Tooltips.activityMultiplier
            )
            if goalEngine.vo2Max != nil {
                modernInfoRow(
                    label: "VO2 Adj.",
                    value: String(format: "%+.2f", goalEngine.vo2MaxAdjustment)
                )
            }

            Divider().opacity(0.1)

            HStack(spacing: 8) {
                MacroTargetPill(
                    label: "P",
                    value: "\(goalEngine.proteinTarget)g",
                    color: Color(hex: "5E9FFF")
                )
                MacroTargetPill(
                    label: "K",
                    value: "\(goalEngine.carbTarget)g",
                    color: Color(hex: "FF9F43")
                )
                MacroTargetPill(
                    label: "Y",
                    value: "\(goalEngine.fatTarget)g",
                    color: Theme.fatColor
                )
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    func modernInfoRow(label: String, value: String, valueColor: Color = .white, tooltip: TooltipItem? = nil) -> some View {
        HStack {
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let tooltip { InfoTooltipButton(tooltip: tooltip, size: 12) }
            }
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Goal Info Sheet Components

struct MetricInfoCard: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let unit: String
    var tooltip: TooltipItem? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 13))
                    .frame(width: 26, height: 26)
                    .background(iconColor.opacity(0.15))
                    .cornerRadius(8)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let tooltip { InfoTooltipButton(tooltip: tooltip, size: 11) }
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

struct MacroTargetPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(color)
            Text(value)
                .font(.caption.bold())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.12))
        .cornerRadius(8)
    }
}
