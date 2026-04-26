//
//  ProteinTrackingCard.swift
//  VoiceMeal
//

import SwiftUI

struct ProteinTrackingCard: View {
    let stats: [DayStat]
    let proteinTarget: Double
    var appLanguage: String

    var daysOnTarget: Int {
        stats.filter {
            $0.hasData && $0.protein >= proteinTarget * 0.9
        }.count
    }
    var daysWithData: Int {
        stats.filter { $0.hasData }.count
    }
    var avgProtein: Double {
        let days = stats.filter { $0.hasData }
        guard !days.isEmpty else { return 0 }
        return days.reduce(0) { $0 + $1.protein } / Double(days.count)
    }
    var onTargetPct: Int {
        daysWithData > 0
            ? Int(Double(daysOnTarget) / Double(daysWithData) * 100)
            : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "bolt.circle.fill")
                    .foregroundColor(Theme.protein)
                    .font(.system(size: 16))
                    .frame(width: 30, height: 30)
                    .background(Theme.protein.opacity(0.15))
                    .cornerRadius(8)
                Text(L.proteinGoalTitle.localized)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(proteinTarget))g " +
                     L.targetLabel.localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Stats row
            HStack(spacing: 0) {
                // Days on target
                VStack(spacing: 4) {
                    Text("\(daysOnTarget)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Theme.protein)
                    Text(L.daysOnTarget.localized)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 50).opacity(0.2)

                // Average protein
                VStack(spacing: 4) {
                    Text("\(Int(avgProtein))g")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(
                            avgProtein >= proteinTarget ? .green : .orange)
                    Text(L.dailyAvg.localized)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 50).opacity(0.2)

                // On target percentage
                VStack(spacing: 4) {
                    Text("\(onTargetPct)%")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(
                            onTargetPct >= 70 ? .green : .orange)
                    Text(L.hitRate.localized)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }

            // Per-day breakdown
            Divider().opacity(0.2)
            Text(L.dailyBreakdown.localized)
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(stats.filter { $0.hasData }.suffix(7),
                    id: \.date) { stat in
                HStack(spacing: 8) {
                    // Day label
                    Text(shortDayLabel(stat.date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .leading)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.06))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(stat.protein >= proteinTarget * 0.9
                                      ? Theme.protein : Theme.warning)
                                .frame(width: min(
                                    geo.size.width,
                                    geo.size.width * (stat.protein / max(1, proteinTarget))
                                ))
                        }
                    }
                    .frame(height: 5)

                    // Value
                    Text("\(Int(stat.protein))g")
                        .font(.caption2.bold())
                        .foregroundColor(
                            stat.protein >= proteinTarget * 0.9
                                ? .white : .orange)
                        .frame(width: 38, alignment: .trailing)

                    // Check
                    Image(systemName:
                            stat.protein >= proteinTarget * 0.9
                          ? "checkmark.circle.fill"
                          : "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(
                            stat.protein >= proteinTarget * 0.9
                                ? .green : .red.opacity(0.6))
                }
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

    func shortDayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier:
                                    appLanguage == "en" ? "en_US" : "tr_TR")
        return formatter.string(from: date)
    }
}
