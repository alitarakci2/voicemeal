//
//  NutritionReportMigrator.swift
//  VoiceMeal
//

import Foundation
import SwiftData

enum NutritionReportMigrator {
    private static let migrationFlagKey = "migrated_v2_nutrition_reports"

    /// One-time migration — backfills `periodTypeRaw`, `periodStartDate`, `periodEndDate`
    /// for existing week-only reports created before the period-aware refactor.
    /// Safe to call on every launch; no-op after first successful run.
    @MainActor
    static func migrateLegacyReportsIfNeeded(context: ModelContext) {
        if UserDefaults.standard.bool(forKey: migrationFlagKey) { return }

        let descriptor = FetchDescriptor<NutritionReport>()
        guard let reports = try? context.fetch(descriptor) else {
            FeedbackService.shared.addErrorLog("nutrition_report_migration_fetch_failed")
            return
        }

        var migrated = 0
        for report in reports where report.periodStartDate == .distantPast {
            report.periodTypeRaw = ReportPeriod.week.rawValue
            report.periodStartDate = report.weekStartDate
            report.periodEndDate = report.weekEndDate
            migrated += 1
        }

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: migrationFlagKey)
            FeedbackService.shared.addLog("nutrition_report_migration_completed: migrated=\(migrated) total=\(reports.count)")
        } catch {
            FeedbackService.shared.addErrorLog("nutrition_report_migration_save_failed: \(error.localizedDescription)")
        }
    }
}
