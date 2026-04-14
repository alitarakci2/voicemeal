//
//  FeedbackService.swift
//  VoiceMeal
//

import Combine
import Foundation
import UIKit

class FeedbackService: ObservableObject {
    static let shared = FeedbackService()

    // EmailJS config - fill these after setup
    private let serviceID = "service_XXXXXX"
    private let templateID = "voicemeal_bug_report"
    private let publicKey = "XXXXXXXXXXXXXX"

    // Current app context (updated by views)
    var currentTab: String = "Record"
    var lastAction: String = ""
    var recentLogs: [String] = []

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
    }

    func sendReport(userMessage: String) async throws {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let systemVersion = device.systemVersion
        let deviceModel = device.model
        let deviceName = device.name

        let systemInfo = """
        --- Sistem Bilgisi ---
        Sekme: \(currentTab)
        iOS: \(systemVersion)
        Cihaz: \(deviceModel)
        App: v\(appVersion) (build \(buildNumber))
        Tarih: \(Date().formatted())

        --- Son İşlemler ---
        \(recentLogs.suffix(10).joined(separator: "\n"))
        """

        let fullMessage = userMessage.isEmpty
            ? systemInfo
            : "\(userMessage)\n\n\(systemInfo)"

        let params: [String: String] = [
            "subject": userMessage.isEmpty
                ? "Kullanıcı raporu"
                : String(userMessage.prefix(50)),
            "message": fullMessage,
            "current_tab": currentTab,
            "ios_version": systemVersion,
            "device": "\(deviceModel) - \(deviceName)",
            "app_version": "v\(appVersion) (\(buildNumber))",
            "date": Date().formatted(),
            "last_action": lastAction
        ]

        let body: [String: Any] = [
            "service_id": serviceID,
            "template_id": templateID,
            "user_id": publicKey,
            "template_params": params
        ]

        guard let url = URL(string: "https://api.emailjs.com/api/v1.0/email/send") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
}
