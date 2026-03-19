//
//  NotificationService.swift
//  VoiceMeal
//

import Foundation
import UIKit
import UserNotifications

enum MealNotificationType: String {
    case afternoon = "afternoon"
    case evening = "evening"
}

extension Notification.Name {
    static let openMealSuggestion = Notification.Name("OpenMealSuggestion")
}

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
        let category = response.notification.request.content.categoryIdentifier
        let type: MealNotificationType
        switch category {
        case "MEAL_SUGGESTION_AFTERNOON":
            type = .afternoon
        case "MEAL_SUGGESTION_EVENING":
            type = .evening
        default:
            completionHandler()
            return
        }

        NotificationCenter.default.post(
            name: .openMealSuggestion,
            object: nil,
            userInfo: ["type": type.rawValue]
        )
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

    func scheduleDaily(type: MealNotificationType, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.sound = .default

        switch type {
        case .afternoon:
            content.title = "Ak\u{015F}am yeme\u{011F}ini planla"
            content.body = "Kalan makrolar\u{0131}na g\u{00F6}re \u{00F6}neri almak i\u{00E7}in t\u{0131}kla"
            content.categoryIdentifier = "MEAL_SUGGESTION_AFTERNOON"
        case .evening:
            content.title = "G\u{00FC}n\u{00FC} kapat"
            content.body = "Yatmadan \u{00F6}nce hafif bir at\u{0131}\u{015F}t\u{0131}rmal\u{0131}k \u{00F6}nerisi almak i\u{00E7}in t\u{0131}kla"
            content.categoryIdentifier = "MEAL_SUGGESTION_EVENING"
        }

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "meal_\(type.rawValue)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
    }

    func reschedule(profile: UserProfile) {
        cancelAll()

        if profile.notification1Enabled {
            scheduleDaily(type: .afternoon, hour: profile.notification1Hour, minute: profile.notification1Minute)
        }

        if profile.notification2Enabled {
            scheduleDaily(type: .evening, hour: profile.notification2Hour, minute: profile.notification2Minute)
        }
    }
}
