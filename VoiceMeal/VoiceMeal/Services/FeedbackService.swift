//
//  FeedbackService.swift
//  VoiceMeal
//

import Combine
import Foundation
import Sentry
import UIKit

class FeedbackService: ObservableObject {
    static let shared = FeedbackService()

    // EmailJS config - fill these after setup
    private let serviceID = Config.emailJSServiceID
    private let templateID = Config.emailJSTemplateID
    private let publicKey = Config.emailJSPublicKey

    // Unique per app session, for correlating EmailJS mails with Sentry events
    let sessionID: String = {
        UUID().uuidString.components(separatedBy: "-").first ?? "UNKNOWN"
    }()

    // Current app context (updated by views)
    var currentTab: String = "Record"
    var lastAction: String = ""
    var recentLogs: [String] = []

    func configureSentryScope() {
        SentrySDK.configureScope { [sessionID] scope in
            scope.setTag(value: sessionID, key: "session_id")
            let deviceID = UIDevice.current
                .identifierForVendor?.uuidString
                .components(separatedBy: "-").first ?? "unknown"
            scope.setTag(value: deviceID, key: "device_id")
        }
    }

    func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .none,
            timeStyle: .medium
        )
        recentLogs.append("[\(timestamp)] \(message)")
        if recentLogs.count > 20 {
            recentLogs.removeFirst()
        }

        let crumb = Breadcrumb()
        crumb.level = .info
        crumb.category = "user.action"
        crumb.message = message
        SentrySDK.addBreadcrumb(crumb)
    }

    func sendReport(userMessage: String) async throws {
        print("📧 [EmailJS] Sending report...")
        print("📧 [EmailJS] ServiceID: \(serviceID)")
        print("📧 [EmailJS] TemplateID: \(templateID)")
        print("📧 [EmailJS] PublicKey: \(publicKey.prefix(4))...")

        SentrySDK.configureScope { scope in
            scope.setTag(value: "feedback_sent", key: "feedback")
        }
        _ = SentrySDK.capture(message: "📧 User Feedback [\(sessionID)]: \(userMessage.prefix(100))")

        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let systemVersion = device.systemVersion
        let deviceModel = device.model
        let deviceName = device.name

        let systemInfo = """
        --- Rapor ID: \(sessionID) ---
        Sekme: \(currentTab)
        iOS: \(systemVersion)
        Cihaz: \(deviceModel)
        App: v\(appVersion) (build \(buildNumber))
        Tarih: \(Date().formatted())

        --- Son İşlemler ---
        \(recentLogs.suffix(10).joined(separator: "\n"))

        --- Sentry'de Ara ---
        session_id:\(sessionID)
        """

        let fullMessage = userMessage.isEmpty
            ? systemInfo
            : "\(userMessage)\n\n\(systemInfo)"

        let subject = "[\(sessionID)] " + (userMessage.isEmpty
            ? "User Report"
            : String(userMessage.prefix(40)))

        let params: [String: String] = [
            "subject": subject,
            "message": fullMessage,
            "current_tab": currentTab,
            "ios_version": systemVersion,
            "device": "\(deviceModel) - \(deviceName)",
            "app_version": "v\(appVersion) (\(buildNumber))",
            "date": Date().formatted(),
            "last_action": lastAction,
            "session_id": sessionID
        ]

        let body: [String: Any] = [
            "service_id": serviceID,
            "template_id": templateID,
            "user_id": publicKey,
            "accessToken": Config.emailJSPrivateKey,
            "template_params": params
        ]

        guard let url = URL(string: "https://api.emailjs.com/api/v1.0/email/send") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("📧 [EmailJS] Request URL: \(url)")
        print("📧 [EmailJS] Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "nil")")

        let (data, response) = try await URLSession.shared.data(for: request)

        print("📧 [EmailJS] Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        print("📧 [EmailJS] Response: \(String(data: data, encoding: .utf8) ?? "nil")")

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
}
