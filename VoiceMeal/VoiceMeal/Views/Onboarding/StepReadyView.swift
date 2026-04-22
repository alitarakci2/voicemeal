//
//  StepReadyView.swift
//  VoiceMeal
//

import SwiftUI

struct StepReadyView: View {
    var appLanguage: String
    var userName: String
    var dailyTarget: Int
    var isObserveMode: Bool = false
    var onStart: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [themeManager.current.gradientTop, Color(hex: "0A0A1F")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 40)

                    Text("🎉")
                        .font(.system(size: 72))

                    VStack(spacing: 8) {
                        Text(isObserveMode
                             ? L.readyObserveTitle.localized
                             : (appLanguage == "en" ? "You're all set, \(userName)!" : "Hazırsın, \(userName)!"))
                            .font(.title.bold())
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        if !isObserveMode {
                            Text(appLanguage == "en"
                                 ? "Your program is ready"
                                 : "Programın oluşturuldu")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isObserveMode
                                 ? L.readyObserveTdeeNote.localized
                                 : (appLanguage == "en" ? "Daily calorie target" : "Günlük kalori hedefin"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(dailyTarget) kcal")
                                .font(.title2.bold())
                                .foregroundColor(themeManager.current.accent)
                        }
                        Spacer()
                        Image(systemName: "flame.fill")
                            .font(.system(size: 32))
                            .foregroundColor(themeManager.current.accent)
                    }
                    .padding(16)
                    .background(themeManager.current.cardBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(themeManager.current.accent.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 32)

                    if isObserveMode {
                        Text(L.readyObserveSubtitle.localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(appLanguage == "en"
                             ? "Your first 3 days:"
                             : "İlk 3 günün hedefi:")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.bottom, 12)

                        FirstStepRow(
                            number: "1",
                            icon: "mic.fill",
                            iconColor: themeManager.current.accent,
                            text: appLanguage == "en"
                                ? "After each meal → tap mic → say what you ate"
                                : "Her yemekten sonra → mikrofona bas → ne yediğini söyle"
                        )

                        FirstStepRow(
                            number: "2",
                            icon: "brain.head.profile",
                            iconColor: Color(hex: "5E9FFF"),
                            text: appLanguage == "en"
                                ? "Each evening → read your daily AI assessment"
                                : "Her akşam → günlük AI değerlendirmeni oku"
                        )

                        FirstStepRow(
                            number: "3",
                            icon: "chart.bar.fill",
                            iconColor: Color(hex: "4CD964"),
                            text: appLanguage == "en"
                                ? "After 7 days → check your weekly statistics"
                                : "7 gün sonra → haftalık istatistiklerine bak"
                        )
                    }
                    .padding(16)
                    .background(themeManager.current.cardBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal, 32)

                    HStack(spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 14))
                        Text(appLanguage == "en"
                             ? "Tap ⓘ icons anywhere in the app to learn about terms like TDEE, HRV, VO₂ Max"
                             : "Uygulamada gördüğün ⓘ ikonlarına dokunarak TDEE, HRV, VO₂ Max gibi terimleri öğrenebilirsin")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal, 32)

                    Spacer().frame(height: 20)

                    Button {
                        onStart()
                    } label: {
                        HStack {
                            Text(appLanguage == "en"
                                 ? "Let's Go! 🚀"
                                 : "Hadi Başlayalım! 🚀")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [themeManager.current.accent, themeManager.current.accent.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)

                    Spacer().frame(height: 40)
                }
            }
        }
    }
}

struct FirstStepRow: View {
    let number: String
    let icon: String
    let iconColor: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(iconColor)
                .clipShape(Circle())

            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 14))
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.vertical, 8)
        .overlay(
            Divider().opacity(0.15),
            alignment: .bottom
        )
    }
}
