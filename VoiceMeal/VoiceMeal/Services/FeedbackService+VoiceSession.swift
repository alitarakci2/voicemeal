//
//  FeedbackService+VoiceSession.swift
//  VoiceMeal
//
//  Voice capture session telemetry: lifecycle state machine, event log,
//  metric counters, and one-tap structured report via EmailJS.
//

import Foundation
import Sentry

// MARK: - Model

enum VoiceSessionState: String {
    case recording
    case parsing
    case reviewing
    case saved
    case cancelled
    case abandoned
}

enum VoiceSessionEndReason: String {
    case saved, cancelled, abandoned
}

struct VoiceSessionEvent {
    let timestamp: Date
    let icon: String
    let message: String
    let data: [String: String]
}

enum VoiceSessionMetric {
    case groqCall
    case retry
    case tryAgain
    case clarification
    case correction
    case inlineEdit
    case mealRemoved
    case guessUsed
}

final class VoiceSession: Identifiable {
    static let eventCap = 200

    let id: String
    let startedAt: Date
    var endedAt: Date?
    var state: VoiceSessionState = .recording
    var events: [VoiceSessionEvent] = []

    // Metrics
    var groqCallCount: Int = 0
    var retryCount: Int = 0
    var tryAgainTapCount: Int = 0
    var clarificationLoopCount: Int = 0
    var correctionCount: Int = 0
    var inlineEditCount: Int = 0
    var mealRemovedCount: Int = 0
    var guessUsedCount: Int = 0

    init() {
        self.id = UUID().uuidString.components(separatedBy: "-").first ?? "UNK"
        self.startedAt = Date()
    }

    var durationSeconds: Double {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }

    /// Problematic-session heuristics (spec thresholds).
    /// Any single condition flips the session into one-tap-prompt territory.
    var isProblematic: Bool {
        durationSeconds > 180
            || groqCallCount > 4
            || retryCount >= 1
            || tryAgainTapCount > 1
            || clarificationLoopCount > 1
            || correctionCount > 3
    }
}

// MARK: - FeedbackService extension

extension FeedbackService {
    // MARK: Lifecycle

    func startVoiceSession() {
        if currentVoiceSession != nil {
            endVoiceSession(reason: .abandoned)
        }
        let session = VoiceSession()
        currentVoiceSession = session
        logVoiceEvent(icon: "🟢", message: "Session başladı")

        let crumb = Breadcrumb()
        crumb.level = .info
        crumb.category = "voice.session.started"
        crumb.message = "Voice session started"
        crumb.data = ["session_id": session.id]
        SentrySDK.addBreadcrumb(crumb)
    }

    func endVoiceSession(reason: VoiceSessionEndReason) {
        guard let session = currentVoiceSession else { return }
        guard session.endedAt == nil else { return }

        session.endedAt = Date()
        switch reason {
        case .saved:     session.state = .saved
        case .cancelled: session.state = .cancelled
        case .abandoned: session.state = .abandoned
        }

        let icon: String
        switch reason {
        case .saved:     icon = "✅"
        case .cancelled: icon = "❌"
        case .abandoned: icon = "⏳"
        }

        logVoiceEvent(
            icon: icon,
            message: reason.rawValue.uppercased(),
            data: [
                "duration_s": String(format: "%.1f", session.durationSeconds),
                "groq_calls": "\(session.groqCallCount)",
                "problematic": "\(session.isProblematic)"
            ]
        )

        let crumb = Breadcrumb()
        crumb.level = reason == .abandoned ? .warning : .info
        crumb.category = "voice.session.\(reason.rawValue)"
        crumb.message = "Voice session ended: \(reason.rawValue)"
        crumb.data = [
            "session_id": session.id,
            "duration_s": session.durationSeconds,
            "problematic": session.isProblematic
        ]
        SentrySDK.addBreadcrumb(crumb)
    }

    /// Called from instrumentation points. No-op when no active session.
    func logVoiceEvent(icon: String, message: String, data: [String: String] = [:]) {
        guard let session = currentVoiceSession else { return }
        let event = VoiceSessionEvent(
            timestamp: Date(),
            icon: icon,
            message: message,
            data: data
        )
        session.events.append(event)
        if session.events.count > VoiceSession.eventCap {
            session.events.removeFirst(session.events.count - VoiceSession.eventCap)
        }
    }

    func trackVoiceMetric(_ metric: VoiceSessionMetric) {
        guard let session = currentVoiceSession else { return }
        switch metric {
        case .groqCall:      session.groqCallCount += 1
        case .retry:         session.retryCount += 1
        case .tryAgain:      session.tryAgainTapCount += 1
        case .clarification: session.clarificationLoopCount += 1
        case .correction:    session.correctionCount += 1
        case .inlineEdit:    session.inlineEditCount += 1
        case .mealRemoved:   session.mealRemovedCount += 1
        case .guessUsed:     session.guessUsedCount += 1
        }
    }

    // MARK: Reporting

    /// Sends a structured voice-session report via EmailJS. Callers may pass an
    /// explicit `session` (captured at sheet-open time) for stable reporting
    /// across session state changes; otherwise falls back to `currentVoiceSession`,
    /// and finally to a generic report when no session exists.
    func sendVoiceReport(userMessage: String, session: VoiceSession? = nil) async throws {
        guard let session = session ?? currentVoiceSession else {
            try await sendReport(userMessage: userMessage)
            return
        }

        let body = buildVoiceReportBody(userMessage: userMessage, session: session)
        let subject = "[VOICE-\(session.id)] " + (userMessage.isEmpty
            ? "Voice Session Report"
            : String(userMessage.prefix(40)))

        SentrySDK.configureScope { scope in
            scope.setTag(value: "voice_report_sent", key: "feedback")
        }
        let crumb = Breadcrumb()
        crumb.level = .info
        crumb.category = "voice.session.report_sent"
        crumb.message = "Voice session report sent"
        crumb.data = [
            "session_id": session.id,
            "problematic": session.isProblematic,
            "state": session.state.rawValue
        ]
        SentrySDK.addBreadcrumb(crumb)

        try await postToEmailJS(subject: subject, message: body)
    }

    private func buildVoiceReportBody(userMessage: String, session: VoiceSession) -> String {
        let timelineLines = session.events.map { event -> String in
            let ts = DateFormatter.localizedString(
                from: event.timestamp,
                dateStyle: .none,
                timeStyle: .medium
            )
            let dataStr: String
            if event.data.isEmpty {
                dataStr = ""
            } else {
                let pairs = event.data.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
                dataStr = "  (" + pairs + ")"
            }
            return "[\(ts)] \(event.icon) \(event.message)\(dataStr)"
        }
        let timeline = timelineLines.joined(separator: "\n")

        let statusLabel = session.isProblematic
            ? "\(session.state.rawValue.uppercased()) (auto-report threshold aşıldı)"
            : session.state.rawValue.uppercased()

        return """
        KULLANICI YORUMU
        ━━━━━━━━━━━━━━━
        \(userMessage.isEmpty ? "(boş)" : userMessage)

        SESSION DETAYLARI
        ━━━━━━━━━━━━━━━
        Session ID: \(session.id)
        Durum: \(statusLabel)
        Süre: \(formatDuration(session.durationSeconds))
        Groq çağrı: \(session.groqCallCount)
        Retry: \(session.retryCount)
        Try again: \(session.tryAgainTapCount)
        Clarification: \(session.clarificationLoopCount)
        Düzeltme: \(session.correctionCount)
        Inline edit: \(session.inlineEditCount)
        Meal removed: \(session.mealRemovedCount)
        Tahmin modu: \(session.guessUsedCount)

        SENARYO
        ━━━━━━━━━━━━━━━
        \(timeline)

        \(buildSystemInfo())
        """
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return m > 0 ? "\(m)dk \(s)sn" : "\(s)sn"
    }
}
