//
//  HomeView+DailyTargetCard.swift
//  VoiceMeal
//

import SwiftUI

extension HomeView {

    var dailyGoalCard: some View {
        let remaining = goalEngine.dailyCalorieTarget - eatenCalories
        let targetDeficit = Int(goalEngine.cappedDailyDeficit)
        let actualDeficit = Int(goalEngine.tdee) - eatenCalories
        let gapKind = CalorieGapKind.from(signedTargetDeficit: targetDeficit)
        let eatingProgress = goalEngine.dailyCalorieTarget > 0
            ? min(Double(eatenCalories) / Double(goalEngine.dailyCalorieTarget), 1.0) : 0
        let deficitProgress: Double = targetDeficit != 0
            ? min(max(Double(actualDeficit) / Double(targetDeficit), 0), 1.0) : 0
        let gapRingColor: Color = {
            switch CalorieGapCopy.colorCue(actual: actualDeficit, target: targetDeficit, kind: gapKind) {
            case .good: return Theme.green
            case .warn: return Theme.orange
            case .bad:  return Theme.red
            }
        }()

        return VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    let names = goalEngine.todayActivityNames
                        .compactMap { GoalEngine.activityDisplayNames[$0] }
                    let emojis = goalEngine.todayActivityNames
                        .compactMap { activityEmoji(for: $0) }
                        .joined(separator: " ")
                    if !names.isEmpty {
                        HStack(spacing: 4) {
                            if !emojis.isEmpty {
                                Text(emojis)
                            }
                            Text(names.joined(separator: " · "))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                        }
                    }
                }
                Spacer()
                HStack(spacing: 14) {
                    Button { Task { await refreshHealthKit() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Button { showGoalInfo = true } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                metricRingCard(
                    title: "eating_goal".localized,
                    value: "\(eatenCalories)",
                    subtitle: "/ \(goalEngine.dailyCalorieTarget) kcal",
                    progress: eatingProgress,
                    ringColor: remaining < 0 ? Theme.red : Theme.accent
                )

                metricRingCard(
                    title: CalorieGapCopy.cardTitle(kind: gapKind),
                    value: "\(abs(actualDeficit))",
                    subtitle: "/ \(abs(targetDeficit)) kcal",
                    progress: deficitProgress,
                    ringColor: gapRingColor,
                    tooltip: Tooltips.caloricDeficitRing
                )

                metricStatCard(
                    title: "remaining_label".localized,
                    value: "\(remaining)",
                    unit: "kcal",
                    color: remaining < 0 ? Theme.red : Theme.green
                )

                metricStatCard(
                    title: "TDEE",
                    value: "\(Int(goalEngine.tdee))",
                    unit: "kcal",
                    color: .white,
                    tooltip: Tooltips.tdee
                )
            }

            VStack(spacing: 8) {
                HStack {
                    InfoTooltipButton(tooltip: Tooltips.macros, size: 11)
                    Spacer()
                }
                macroProgressRow(label: "pro_short".localized, value: eatenProtein, target: Double(goalEngine.proteinTarget), color: Theme.blue)
                macroProgressRow(label: "carb_short".localized, value: eatenCarbs, target: Double(goalEngine.carbTarget), color: Theme.orange)
                macroProgressRow(label: "fat_short".localized, value: eatenFat, target: Double(goalEngine.fatTarget), color: Theme.fatColor)
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Theme.gradientTop.opacity(0.7),
                    Color(hex: "0D0D1A").opacity(0.8),
                    Color(hex: "0A0A0F").opacity(0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    func activityEmoji(for activity: String) -> String? {
        switch activity {
        case "weights": return "\u{1F3CB}\u{FE0F}"
        case "running": return "\u{1F3C3}"
        case "cycling": return "\u{1F6B4}"
        case "walking": return "\u{1F6B6}"
        case "rest": return "\u{1F4A4}"
        default: return nil
        }
    }

    func metricRingCard(title: String, value: String, subtitle: String, progress: Double, ringColor: Color, tooltip: TooltipItem? = nil) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                if let tooltip { InfoTooltipButton(tooltip: tooltip, size: 10) }
            }

            ZStack {
                Circle()
                    .fill(ringColor.opacity(0.08))
                    .frame(width: 105, height: 105)
                    .blur(radius: 8)

                Circle()
                    .stroke(Theme.trackBackground, lineWidth: 7)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(width: 95, height: 95)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [ringColor, ringColor.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .cornerRadius(1)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    func metricStatCard(title: String, value: String, unit: String, color: Color, tooltip: TooltipItem? = nil) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                if let tooltip { InfoTooltipButton(tooltip: tooltip, size: 10) }
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    func macroProgressRow(label: String, value: Double, target: Double, color: Color) -> some View {
        let progress = target > 0 ? min(value / target, 1.0) : 0
        return HStack(spacing: 6) {
            Text(String(label.prefix(3)))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .leading)
                .lineLimit(1)
                .fixedSize()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut(duration: 0.6), value: progress)
                }
            }
            .frame(height: 8)

            Text("\(Int(value))g")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 34, alignment: .trailing)
                .lineLimit(1)

            Text("/\(Int(target))g")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .leading)
                .lineLimit(1)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
