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
    @State private var isRecording = false
    @State private var lastTranscript = ""
    @StateObject private var speechService = SpeechService()
    @EnvironmentObject var themeManager: ThemeManager
    var appLanguage: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [themeManager.current.gradientTop,
                         Color(hex: "0A0A1F")],
                startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // FIXED HEADER
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appLanguage == "en"
                            ? "Send Feedback" : "Geri Bildirim")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        Text(appLanguage == "en"
                            ? "Describe what happened"
                            : "Ne olduğunu anlat")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(themeManager.current.gradientTop.opacity(0.95))
                .overlay(Divider().opacity(0.2), alignment: .bottom)

                // SCROLLABLE CONTENT
                ScrollView {
                    VStack(spacing: 16) {
                        if sent {
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.green)
                                Text(appLanguage == "en"
                                    ? "Feedback sent!"
                                    : "Gönderildi!")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                Text(appLanguage == "en"
                                    ? "Thanks for helping improve VoiceMeal"
                                    : "VoiceMeal'i geliştirmemize yardım ettiğin için teşekkürler")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(30)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(appLanguage == "en"
                                    ? "What happened? (optional)"
                                    : "Ne oldu? (opsiyonel)")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)

                                ZStack(alignment: .bottomTrailing) {
                                    TextEditor(text: $message)
                                        .frame(minHeight: 130)
                                        .padding(10)
                                        .padding(.trailing, 50)
                                        .background(themeManager.current.cardBackground)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    isRecording
                                                        ? Color.red.opacity(0.4)
                                                        : Color.white.opacity(0.06),
                                                    lineWidth: 1)
                                        )
                                        .foregroundColor(.white)
                                        .font(.subheadline)

                                    Button {
                                        toggleRecording()
                                    } label: {
                                        Image(systemName: isRecording
                                            ? "stop.circle.fill"
                                            : "mic.circle.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(isRecording
                                                ? .red
                                                : themeManager.current.accent)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(10)
                                }

                                if isRecording {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 7, height: 7)
                                        Text(appLanguage == "en"
                                            ? "Listening..." : "Dinliyorum...")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }

                                Text(appLanguage == "en"
                                    ? "App info and recent actions will be included automatically"
                                    : "Uygulama bilgileri otomatik eklenir")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(themeManager.current.accent)
                                        .font(.caption)
                                    Text(appLanguage == "en"
                                        ? "Automatically included"
                                        : "Otomatik eklenenler")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    let device = UIDevice.current
                                    let ver = Bundle.main.infoDictionary?[
                                        "CFBundleShortVersionString"] as? String ?? "?"
                                    InfoRow(icon: "iphone",
                                            text: "\(device.model) · iOS \(device.systemVersion)")
                                    InfoRow(icon: "app.badge",
                                            text: "VoiceMeal v\(ver)")
                                    InfoRow(icon: "rectangle.3.group",
                                            text: "\(L.currentTab.localized): \(FeedbackService.shared.currentTab)")
                                    InfoRow(icon: "clock",
                                            text: Date().formatted(date: .abbreviated, time: .shortened))
                                }
                                .padding(10)
                                .background(themeManager.current.cardBackground)
                                .cornerRadius(10)
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
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)

                // FIXED SEND BUTTON AT BOTTOM
                if !sent {
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
                        HStack(spacing: 8) {
                            if isSending {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text(isSending
                                ? L.sendingFeedback.localized
                                : L.sendFeedback.localized)
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            isSending
                                ? themeManager.current.accent.opacity(0.5)
                                : themeManager.current.accent)
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSending)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(themeManager.current.cardBackground.opacity(0.95))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: speechService.transcript) { _, newValue in
            guard isRecording, !newValue.isEmpty else { return }
            if lastTranscript.isEmpty {
                if message.isEmpty {
                    message = newValue
                } else {
                    message += " " + newValue
                }
            } else {
                let prefix = message.hasSuffix(lastTranscript)
                    ? String(message.dropLast(lastTranscript.count))
                    : message
                message = prefix + newValue
            }
            lastTranscript = newValue
        }
        .onDisappear {
            if isRecording {
                stopRecording()
            }
        }
    }

    // MARK: - Actions

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        lastTranscript = ""
        Task {
            let granted = await speechService.requestPermissions()
            guard granted else {
                isRecording = false
                return
            }
            do {
                try speechService.startListening()
            } catch {
                isRecording = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if isRecording {
                stopRecording()
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        speechService.stopListening()
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
