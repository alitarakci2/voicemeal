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
    let intensityLevel: Double
    let waterMl: Int
    let waterGoalMl: Int
    let plannedMeals: String?
    @Environment(\.modelContext) private var modelContext

    @State private var insightText: String?
    @State private var isLoading = false
    @State private var generatedAt: Date?
    @State private var hasAttempted = false
    @State private var lastTimeOfDay: GroqService.TimeOfDay?
    @State private var isAutoRefreshing = false

    private let groqService = GroqService()

    private var sleepSummary: String? {
        guard let s = sleep else { return nil }
        let hours = s.totalMinutes / 60
        let mins = s.totalMinutes % 60
        return "\(hours)s \(mins)dk"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\u{1F9E0} Günlük Değerlendirme")
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }

            // Sleep + HRV summary line
            HStack(spacing: 8) {
                if let summary = sleepSummary {
                    PillBadge(text: "\u{1F634} \(summary)")
                }
                if let s = sleep {
                    PillBadge(text: "Kalite: \(s.quality.rawValue)")
                }
                if hrvStatus != .noData {
                    PillBadge(text: "\u{1FAC0} \(hrvStatus.rawValue)")
                }
            }

            // Insight content
            if isLoading && !isAutoRefreshing {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Analiz ediliyor...")
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
                    Text("Güncelleniyor...")
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
                Text("Bugünkü veriler analiz edilemedi. Sağlıklı beslenmeye devam et!")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text("Yeterli veri yok \u{2014} birkaç gün sonra görünür")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
            }

            // Footer
            HStack {
                Button {
                    Task { await generateInsight(force: true) }
                } label: {
                    Label("Yenile", systemImage: "arrow.clockwise")
                        .font(Theme.captionFont)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .disabled(isLoading)

                Spacer()

                if let time = generatedAt {
                    Text("\(time.formatted(.dateTime.hour().minute()))'de güncellendi")
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding()
        .themeCard()
        .task {
            loadCachedInsight()
            lastTimeOfDay = GroqService.currentTimeOfDay()
            if insightText == nil {
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

                if timeOfDayChanged || needsRefresh {
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
           Calendar.current.isDateInToday(generatedDate) {
            insightText = insight
            generatedAt = generatedDate
        }
    }

    private func generateInsight(force: Bool) async {
        if !force {
            let snapshot = SnapshotService.fetchSnapshot(for: .now, modelContext: modelContext)
            if let insight = snapshot?.dailyInsight,
               let generatedDate = snapshot?.insightGeneratedAt,
               Calendar.current.isDateInToday(generatedDate) {
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
                intensityLevel: intensityLevel,
                waterMl: waterMl,
                waterGoalMl: waterGoalMl,
                plannedMeals: plannedMeals
            )
            insightText = text
            generatedAt = .now

            // Save to snapshot
            if let snapshot = SnapshotService.fetchSnapshot(for: .now, modelContext: modelContext) {
                snapshot.dailyInsight = text
                snapshot.insightGeneratedAt = .now
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
            // Daily insight error
            if insightText == nil {
                insightText = "Bugünkü veriler analiz edilemedi. Sağlıklı beslenmeye devam et!"
            }
        }

        isLoading = false
    }
}
