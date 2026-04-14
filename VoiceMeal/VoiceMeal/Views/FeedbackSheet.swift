//
//  FeedbackSheet.swift
//  VoiceMeal
//

import SwiftUI
import UIKit

struct FeedbackSheet: View {
    @Binding var isPresented: Bool
    @State private var message: String = ""
    @State private var isSending: Bool = false
    @State private var sent: Bool = false
    @State private var error: Bool = false
    @EnvironmentObject var themeManager: ThemeManager
    var appLanguage: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    themeManager.current.gradientTop,
                    Color(hex: "0A0A0F")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appLanguage == "en" ? "Send Feedback" : "Geri Bildirim")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        Text(appLanguage == "en" ? "Describe what happened" : "Ne olduğunu anlat")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(themeManager.current.gradientTop.opacity(0.95))
                .overlay(Divider().opacity(0.2), alignment: .bottom)

                ScrollView {
                    VStack(spacing: 16) {
                        if sent {
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.green)
                                Text(appLanguage == "en" ? "Feedback sent!" : "Gönderildi!")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                Text(appLanguage == "en"
                                    ? "Thanks for helping improve VoiceMeal"
                                    : "VoiceMeal'i geliştirmemize yardım ettiğin için teşekkürler")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(30)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(appLanguage == "en"
                                    ? "What happened? (optional)"
                                    : "Ne oldu? (opsiyonel)")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)

                                TextEditor(text: $message)
                                    .frame(minHeight: 120)
                                    .padding(10)
                                    .background(themeManager.current.cardBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                                    .toolbar {
                                        ToolbarItemGroup(placement: .keyboard) {
                                            Spacer()
                                            Button(appLanguage == "en" ? "Done" : "Tamam") {
                                                UIApplication.shared.sendAction(
                                                    #selector(UIResponder.resignFirstResponder),
                                                    to: nil, from: nil, for: nil
                                                )
                                            }
                                            .foregroundColor(themeManager.current.accent)
                                        }
                                    }

                                Text(appLanguage == "en"
                                    ? "App info and recent actions will be included automatically"
                                    : "Uygulama bilgileri ve son işlemler otomatik eklenir")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(themeManager.current.accent)
                                        .font(.caption)
                                    Text(appLanguage == "en" ? "Automatically included" : "Otomatik eklenenler")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    let device = UIDevice.current
                                    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"

                                    InfoRow(
                                        icon: "iphone",
                                        text: "\(device.model) · iOS \(device.systemVersion)"
                                    )
                                    InfoRow(
                                        icon: "app.badge",
                                        text: "VoiceMeal v\(appVersion)"
                                    )
                                    InfoRow(
                                        icon: "rectangle.3.group",
                                        text: "\(appLanguage == "en" ? "Current tab" : "Mevcut sekme"): \(FeedbackService.shared.currentTab)"
                                    )
                                    InfoRow(
                                        icon: "clock",
                                        text: Date().formatted(date: .abbreviated, time: .shortened)
                                    )
                                }
                                .padding(12)
                                .background(themeManager.current.cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                            }

                            if error {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(appLanguage == "en"
                                        ? "Could not send. Try again."
                                        : "Gönderilemedi. Tekrar dene.")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }

                            Button {
                                Task {
                                    isSending = true
                                    error = false
                                    do {
                                        try await FeedbackService.shared.sendReport(userMessage: message)
                                        sent = true
                                    } catch {
                                        self.error = true
                                    }
                                    isSending = false
                                }
                            } label: {
                                HStack {
                                    if isSending {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                    }
                                    Text(isSending
                                        ? (appLanguage == "en" ? "Sending..." : "Gönderiliyor...")
                                        : (appLanguage == "en" ? "Send Feedback" : "Gönder"))
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    isSending
                                        ? themeManager.current.accent.opacity(0.5)
                                        : themeManager.current.accent
                                )
                                .cornerRadius(14)
                            }
                            .buttonStyle(.plain)
                            .disabled(isSending)
                        }
                    }
                    .padding()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
