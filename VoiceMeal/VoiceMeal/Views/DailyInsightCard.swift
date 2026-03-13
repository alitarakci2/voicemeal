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
    let remainingCalories: Int
    let calorieDeficit: Int
    let intensityLevel: Double
    @Environment(\.modelContext) private var modelContext

    @State private var insightText: String?
    @State private var isLoading = false
    @State private var generatedAt: Date?
    @State private var hasAttempted = false

    private let groqService = GroqService()

    private var isInMorningWindow: Bool {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour >= 7 && hour < 11
    }

    private var sleepSummary: String? {
        guard let s = sleep else { return nil }
        let hours = s.totalMinutes / 60
        let mins = s.totalMinutes % 60
        return "\(hours)s \(mins)dk"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\u{1F9E0} G\u{00FC}nl\u{00FC}k De\u{011F}erlendirme")
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
            if isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Analiz ediliyor...")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                }
            } else if let text = insightText {
                Text(text)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !isInMorningWindow && !hasAttempted {
                Text("De\u{011F}erlendirme sabah 7-11 aras\u{0131} g\u{00FC}ncellenir")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
            } else if hasAttempted {
                Text("Bug\u{00FC}nk\u{00FC} veriler analiz edilemedi. Sa\u{011F}l\u{0131}kl\u{0131} beslenmeye devam et!")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text("Yeterli veri yok \u{2014} birka\u{00E7} g\u{00FC}n sonra g\u{00F6}r\u{00FC}n\u{00FC}r")
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
                    Text("\(time.formatted(.dateTime.hour().minute()))'de \u{00FC}retildi")
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding()
        .themeCard()
        .task {
            loadCachedInsight()
            if insightText == nil && isInMorningWindow {
                await generateInsight(force: false)
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
                hrvStatus: hrvStatus,
                todayHRV: todayHRV,
                hrvBaseline: hrvBaseline,
                sleep: sleep,
                todayActivities: todayActivities,
                remainingCalories: remainingCalories,
                calorieDeficit: calorieDeficit,
                intensityLevel: intensityLevel
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
            print("[DailyInsight] Error: \(error)")
            insightText = "Bug\u{00FC}nk\u{00FC} veriler analiz edilemedi. Sa\u{011F}l\u{0131}kl\u{0131} beslenmeye devam et!"
        }

        isLoading = false
    }
}
