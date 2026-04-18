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
    @State private var recordingPulse = false
    @State private var lastTranscript = ""
    @StateObject private var speechService = SpeechService()
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
                headerView
                    .padding()
                    .background(themeManager.current.gradientTop.opacity(0.95))
                    .overlay(Divider().opacity(0.2), alignment: .bottom)

                ScrollView {
                    VStack(spacing: 16) {
                        if sent {
                            successView
                        } else {
                            messageInputSection
                            autoInfoSection
                            if error { errorView }
                        }
                    }
                    .padding()
                    .padding(.bottom, 20)
                }

                if !sent {
                    sendButton
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

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L.sendFeedback.localized)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Text(L.describeWhatHappened.localized)
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
    }

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text(L.feedbackSent.localized)
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
    }

    private var messageInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appLanguage == "en"
                ? "What happened? (optional)"
                : "Ne oldu? (opsiyonel)")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            if isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(recordingPulse ? 1 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6).repeatForever(),
                            value: recordingPulse
                        )
                    Text(appLanguage == "en"
                        ? "Listening..." : "Dinliyorum...")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .onAppear { recordingPulse = true }
            }

            TextEditor(text: $message)
                .frame(minHeight: 120)
                .padding(10)
                .background(themeManager.current.cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            Color.white.opacity(isRecording ? 0.3 : 0.06),
                            lineWidth: isRecording ? 1.5 : 1
                        )
                )
                .foregroundColor(.white)
                .font(.subheadline)
                .overlay(alignment: .bottomTrailing) {
                    micButton
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(L.done.localized) {
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
    }

    private var micButton: some View {
        Button {
            toggleRecording()
        } label: {
            Image(systemName: isRecording
                ? "stop.circle.fill"
                : "mic.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(isRecording ? .red : themeManager.current.accent)
        }
        .buttonStyle(.plain)
        .padding(8)
    }

    private var autoInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(themeManager.current.accent)
                    .font(.caption)
                Text(L.autoIncluded.localized)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                let device = UIDevice.current
                let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"

                InfoRow(icon: "iphone", text: "\(device.model) · iOS \(device.systemVersion)")
                InfoRow(icon: "app.badge", text: "VoiceMeal v\(appVersion)")
                InfoRow(icon: "rectangle.3.group", text: "\(L.currentTab.localized): \(FeedbackService.shared.currentTab)")
                InfoRow(icon: "clock", text: Date().formatted(date: .abbreviated, time: .shortened))
            }
            .padding(12)
            .background(themeManager.current.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private var errorView: some View {
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

    private var sendButton: some View {
        Button {
            Task { await sendFeedback() }
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
                    : themeManager.current.accent
            )
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .disabled(isSending)
    }

    // MARK: - Actions

    private func sendFeedback() async {
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

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        recordingPulse = true
        lastTranscript = ""
        Task {
            let granted = await speechService.requestPermissions()
            guard granted else {
                isRecording = false
                recordingPulse = false
                return
            }
            do {
                try speechService.startListening()
            } catch {
                isRecording = false
                recordingPulse = false
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
        recordingPulse = false
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
