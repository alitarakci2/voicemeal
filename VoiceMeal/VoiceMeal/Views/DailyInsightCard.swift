//
//  DailyInsightCard.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct DailyInsightCard: View {
    let hrvStatus: HRVStatus
    let todayHRV: Double?
    let hrvBaseline: Double?
    let sleep: SleepData?
    let todayActivities: [String]
    let consumed: Int
    let dailyCalorieTarget: Int
    let remainingCalories: Int
    let targetDeficit: Int
    let actualDeficit: Int
    let deficitGap: Int
    let proteinConsumed: Double
    let proteinTarget: Int
    let tdee: Int
    let waterMl: Int
    let waterGoalMl: Int
    var coachStyle: CoachStyle = .supportive
    var personalContext: String = ""
    var completedWorkouts: [(type: String, duration: Int, calories: Int)] = []
    var isObserveMode: Bool = false
    @Environment(\.modelContext) private var modelContext

    @State private var insightText: String?
    @State private var isLoading = false
    @State private var generatedAt: Date?
    @State private var hasAttempted = false
    @State private var lastTimeOfDay: GroqService.TimeOfDay?
    @State private var isAutoRefreshing = false

    @Environment(GroqService.self) private var groqService

    private var sleepSummary: String? {
        guard let s = sleep else { return nil }
        let hours = s.totalMinutes / 60
        let mins = s.totalMinutes % 60
        return "\(hours)s \(mins)dk"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.indioOrange)
                    .symbolEffect(.pulse, options: .repeating, isActive: insightText != nil)
                Text(L.dailyAssessment.localized)
                    .font(BrandTypography.bodyMedium())
                    .foregroundStyle(Theme.indioOrange)
                Spacer()
            }

            // Sleep + HRV summary line
            HStack(spacing: 8) {
                if let summary = sleepSummary {
                    PillBadge(text: "\u{1F634} \(summary)")
                }
                if let s = sleep {
                    PillBadge(text: s.quality.localized)
                }
                if hrvStatus != .noData {
                    HStack(spacing: 2) {
                        PillBadge(text: "\u{1FAC0} \(hrvStatus.localized)")
                        InfoTooltipButton(tooltip: Tooltips.hrv, size: 10)
                    }
                }
            }

            // Insight content
            if isLoading && !isAutoRefreshing {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text(L.analyzingInsight.localized)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                }
            } else if isAutoRefreshing, insightText != nil {
                // Show existing text with subtle update indicator
                VStack(alignment: .leading, spacing: 4) {
                    Text(insightText!)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textPrimary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L.updating.localized)
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                }
            } else if let text = insightText {
                Text(text)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            } else if hasAttempted {
                Text(L.insightFallback.localized)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text(L.insufficientData.localized)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
            }

            // Footer
            HStack {
                Button {
                    Task { await generateInsight(force: true) }
                } label: {
                    Label(L.refreshInsight.localized, systemImage: "arrow.clockwise")
                        .font(Theme.captionFont)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .disabled(isLoading)

                Spacer()

                if let time = generatedAt {
                    Text("\(time.formatted(.dateTime.hour().minute())) \(L.updatedAt.localized)")
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.l))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.l)
                .stroke(Theme.indioOrange.opacity(0.30), lineWidth: 1)
        )
        .task {
            loadCachedInsight()
            lastTimeOfDay = GroqService.currentTimeOfDay()

            if insightText != nil {
                if let cachedTime = generatedAt {
                    let generatedPeriod = GroqService.TimeOfDay.from(date: cachedTime)
                    let currentPeriod = GroqService.currentTimeOfDay()
                    let hoursSince = Date().timeIntervalSince(cachedTime) / 3600

                    if generatedPeriod != currentPeriod || hoursSince > 3 {
                        await generateInsight(force: true)
                    }
                }
            } else {
                await generateInsight(force: false)
            }

            // Periodic refresh loop: check every 60s if 3 hours elapsed or timeOfDay changed
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }

                let currentTOD = GroqService.currentTimeOfDay()
                let timeOfDayChanged = currentTOD != lastTimeOfDay
                let threeHoursAgo = Date().addingTimeInterval(-3 * 3600)
                let needsRefresh = generatedAt == nil || generatedAt! < threeHoursAgo

                let snapshot = SnapshotService.fetchSnapshot(for: .now, modelContext: modelContext)
                let storedTarget = snapshot?.insightGeneratedWithTarget ?? 0
                let targetDrift = storedTarget > 0 ? abs(dailyCalorieTarget - storedTarget) : 0
                let targetChanged = targetDrift > 100

                if timeOfDayChanged || needsRefresh || targetChanged {
                    lastTimeOfDay = currentTOD
                    isAutoRefreshing = true
                    await generateInsight(force: true)
                    isAutoRefreshing = false
                }
            }
        }
    }

    private func loadCachedInsight() {
        let snapshot = SnapshotService.fetchSnapshot(for: .now, modelContext: modelContext)
        if let insight = snapshot?.dailyInsight,
           let generatedDate = snapshot?.insightGeneratedAt,
           Calendar.current.isDateInToday(generatedDate),
           (snapshot?.dailyInsightPromptVersion ?? 0) >= GroqService.dailyInsightPromptVersion {
            insightText = insight
            generatedAt = generatedDate
        }
    }

    private func generateInsight(force: Bool) async {
        if !force {
            let snapshot = SnapshotService.fetchSnapshot(for: .now, modelContext: modelContext)
            if let insight = snapshot?.dailyInsight,
               let generatedDate = snapshot?.insightGeneratedAt,
               Calendar.current.isDateInToday(generatedDate),
               (snapshot?.dailyInsightPromptVersion ?? 0) >= GroqService.dailyInsightPromptVersion {
                insightText = insight
                generatedAt = generatedDate
                return
            }
        }

        isLoading = true
        hasAttempted = true

        do {
            let text = try await groqService.generateDailyInsight(
                timeOfDay: GroqService.currentTimeOfDay(),
                hrvStatus: hrvStatus,
                todayHRV: todayHRV,
                hrvBaseline: hrvBaseline,
                sleep: sleep,
                todayActivities: todayActivities,
                consumed: consumed,
                dailyCalorieTarget: dailyCalorieTarget,
                remainingCalories: remainingCalories,
                targetDeficit: targetDeficit,
                actualDeficit: actualDeficit,
                deficitGap: deficitGap,
                proteinConsumed: proteinConsumed,
                proteinTarget: proteinTarget,
                tdee: tdee,
                waterMl: waterMl,
                waterGoalMl: waterGoalMl,
                coachStyle: coachStyle,
                personalContext: personalContext,
                completedWorkouts: completedWorkouts,
                isObserveMode: isObserveMode
            )
            insightText = text
            generatedAt = .now

            // Save to snapshot
            if let snapshot = SnapshotService.fetchSnapshot(for: .now, modelContext: modelContext) {
                snapshot.dailyInsight = text
                snapshot.insightGeneratedAt = .now
                snapshot.insightGeneratedWithTarget = dailyCalorieTarget
                snapshot.dailyInsightPromptVersion = GroqService.dailyInsightPromptVersion
                if let s = sleep {
                    snapshot.sleepMinutes = s.totalMinutes
                    snapshot.deepSleepMinutes = s.deepSleepMinutes
                    snapshot.sleepQuality = s.quality.rawValue
                }
                snapshot.todayHRV = todayHRV
                snapshot.hrvBaseline = hrvBaseline
                snapshot.hrvStatus = hrvStatus.rawValue
            }
        } catch {
            FeedbackService.shared.addErrorLog("DailyInsight: \(error.localizedDescription)")
            if insightText == nil {
                insightText = L.insightFallback.localized
            }
        }

        isLoading = false
    }
}
