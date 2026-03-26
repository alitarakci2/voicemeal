//
//  NotificationService.swift
//  VoiceMeal
//

import Foundation
import HealthKit
import UIKit
import UserNotifications

class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Weight Reminder

    func scheduleWeightReminder(enabled: Bool, days: Int, hour: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weight_reminder"])

        guard enabled else { return }

        let content = UNMutableNotificationContent()
        let lang = (UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first ?? Locale.current.language.languageCode?.identifier ?? "tr")
        let isEnglish = lang.hasPrefix("en")

        content.title = isEnglish
            ? "⚖️ Time to weigh in!"
            : "⚖️ Tartılmayı unuttun mu?"
        content.body = isEnglish
            ? "No weight data for \(days) day\(days > 1 ? "s" : ""). Morning weigh-ins help!"
            : "\(days) gündür tartı bilgin yok. Sabah tartısı motivasyonu artırır!"
        content.sound = .default
        content.categoryIdentifier = "WEIGHT_REMINDER"

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "weight_reminder",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func checkAndRescheduleWeightReminder(profile: UserProfile) async {
        guard profile.weightReminderEnabled else {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: ["weight_reminder"])
            return
        }

        let hasWeight = await hasRecentWeightEntry(withinDays: profile.weightReminderDays)
        if hasWeight {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: ["weight_reminder"])
        } else {
            scheduleWeightReminder(
                enabled: true,
                days: profile.weightReminderDays,
                hour: profile.weightReminderHour
            )
        }
    }

    private func hasRecentWeightEntry(withinDays days: Int) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let store = HKHealthStore()
        let type = HKQuantityType(.bodyMass)
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        let predicate = HKQuery.predicateForSamples(withStart: cutoff, end: .now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: !(samples ?? []).isEmpty)
            }
            store.execute(query)
        }
    }

    func reschedule(profile: UserProfile) {
        cancelAll()

        scheduleWeightReminder(
            enabled: profile.weightReminderEnabled,
            days: profile.weightReminderDays,
            hour: profile.weightReminderHour
        )
    }
}
