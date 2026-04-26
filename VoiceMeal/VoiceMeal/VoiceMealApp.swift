//
//  VoiceMealApp.swift
//  VoiceMeal
//
//  Created by Ali Tarakçı on 11.03.2026.
//

import Sentry
import SwiftData
import SwiftUI

@main
struct VoiceMealApp: App {
    init() {
        SentrySDK.start { options in
            options.dsn = Config.sentryDSN
            options.debug = false
            options.tracesSampleRate = 0.2
            options.attachScreenshot = true
            options.enableAppHangTracking = true
            options.appHangTimeoutInterval = 3.0
            options.enableAutoBreadcrumbTracking = true
        }
        FeedbackService.shared.configureSentryScope()
        _ = WatchConnectivityService.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { @MainActor in
                    NutritionReportMigrator.migrateLegacyReportsIfNeeded(context: sharedContainer.mainContext)
                }
        }
        .modelContainer(sharedContainer)
    }

    private let sharedContainer: ModelContainer = {
        let schema = Schema([
            FoodEntry.self,
            UserProfile.self,
            DailySnapshot.self,
            WaterEntry.self,
            NutritionReport.self
        ])
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("ModelContainer init failed: \(error)")
        }
    }()
}
