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
        print("🔍 [Sentry] DSN length: \(Config.sentryDSN.count)")
        print("🔍 [Sentry] DSN preview: \(Config.sentryDSN.prefix(30))...")
        SentrySDK.start { options in
            options.dsn = "https://fdd7f717c68cc04d76091364e7552586@o4511222363455488.ingest.de.sentry.io/4511222378856528"
            options.debug = true
            options.tracesSampleRate = 0.2
            options.attachScreenshot = false
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
                .environmentObject(ThemeManager.shared)
        }
        .modelContainer(for: [FoodEntry.self, UserProfile.self, DailySnapshot.self, WaterEntry.self])
    }
}
