//
//  VoiceReportPromptModifier.swift
//  VoiceMeal
//
//  Problematic-session one-tap prompt + "Thanks, sent" toast.
//  Extracted from HomeView so body stays within compiler type-inference budget.
//

import Sentry
import SwiftUI

struct VoiceReportPromptModifier: ViewModifier {
    let appLanguage: String
    @Binding var showPrompt: Bool
    @Binding var session: VoiceSession?
    @Binding var showThanksToast: Bool

    private var isEN: Bool { appLanguage == "en" }

    func body(content: Content) -> some View {
        content
            .alert(
                isEN ? "A tricky session 🤔" : "Biraz zorlu bir kayıt oldu 🤔",
                isPresented: $showPrompt,
                presenting: session
            ) { target in
                Button(
                    isEN ? "No thanks" : "Hayır, gerek yok",
                    role: .cancel
                ) {
                    declineReport(target)
                }
                Button(isEN ? "Yes, send" : "Evet, gönder") {
                    acceptReport(target)
                }
            } message: { _ in
                Text(isEN
                     ? "Want to send this session to the developer? It helps make the app better."
                     : "Bu session'ı geliştiriciye göndermek ister misin? Daha iyi hale getirmek için yardımcı olur.")
            }
            .overlay(alignment: .top) {
                if showThanksToast {
                    thanksToast
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showThanksToast)
    }

    private var thanksToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(isEN ? "Thanks, sent 🙏" : "Teşekkürler, gönderildi 🙏")
                .font(.subheadline.bold())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.green.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .padding(.top, 60)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func declineReport(_ target: VoiceSession) {
        let crumb = Breadcrumb()
        crumb.level = .info
        crumb.category = "user.declined_report"
        crumb.message = "User declined problematic-session auto-report"
        crumb.data = ["session_id": target.id]
        SentrySDK.addBreadcrumb(crumb)
        session = nil
    }

    private func acceptReport(_ target: VoiceSession) {
        Task {
            do {
                try await FeedbackService.shared.sendVoiceReport(
                    userMessage: "",
                    session: target
                )
                showThanksToast = true
                try? await Task.sleep(for: .seconds(3))
                showThanksToast = false
            } catch {
                // Silent fail — user already saw save confirmation
            }
            session = nil
        }
    }
}
