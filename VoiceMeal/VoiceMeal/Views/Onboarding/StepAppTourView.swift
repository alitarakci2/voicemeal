//
//  StepAppTourView.swift
//  VoiceMeal
//

import SwiftUI

struct StepAppTourView: View {
    var appLanguage: String
    var onContinue: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @State private var currentCard = 0

    private var cards: [(icon: String, iconColor: Color, title: String, titleEN: String, body: String, bodyEN: String, example: String, exampleEN: String)] {
        [
            (
                icon: "mic.circle.fill",
                iconColor: themeManager.current.accent,
                title: "Sesini Kullan",
                titleEN: "Use Your Voice",
                body: "Yediğin yemeği doğal bir şekilde söyle. AI kalorini hesaplar.",
                bodyEN: "Just say what you ate naturally. AI calculates your calories.",
                example: "\"3 haşlanmış yumurta ve bir dilim tam buğday ekmek yedim\"",
                exampleEN: "\"I had 3 boiled eggs and a slice of whole wheat bread\""
            ),
            // V2: Camera card hidden until photo-based meal entry ships
            (
                icon: "brain.head.profile",
                iconColor: Color(hex: "5E9FFF"),
                title: "Kişisel AI Koçun",
                titleEN: "Your Personal AI Coach",
                body: "Her gün sağlık verilerini analiz eder. HRV, uyku, kalori — hepsini değerlendirir.",
                bodyEN: "Analyzes your health data daily. HRV, sleep, calories — evaluated together.",
                example: "\"HRV değerin mükemmel! Protein hedefine dikkat et.\"",
                exampleEN: "\"Your HRV is excellent! Watch your protein intake today.\""
            ),
            (
                icon: "chart.bar.fill",
                iconColor: Color(hex: "4CD964"),
                title: "İlerlemeni Takip Et",
                titleEN: "Track Your Progress",
                body: "Haftalık ve aylık istatistikler. Streak, tutarlılık, en iyi günler.",
                bodyEN: "Weekly and monthly statistics. Streak, consistency, best days.",
                example: "🔥 5 günlük seri · %87 tutarlılık",
                exampleEN: "🔥 5-day streak · 87% consistency"
            )
        ]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [themeManager.current.gradientTop, Color(hex: "0A0A1F")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    ForEach(0..<cards.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentCard ? themeManager.current.accent : Color.white.opacity(0.2))
                            .frame(width: i == currentCard ? 20 : 8, height: 8)
                            .animation(.spring(), value: currentCard)
                    }
                }
                .padding(.top, 60)
                .frame(maxWidth: .infinity)

                Spacer()

                TabView(selection: $currentCard) {
                    ForEach(0..<cards.count, id: \.self) { i in
                        let card = cards[i]
                        VStack(spacing: 28) {
                            Image(systemName: card.icon)
                                .font(.system(size: 72))
                                .foregroundColor(card.iconColor)
                                .padding(24)
                                .background(card.iconColor.opacity(0.12))
                                .clipShape(Circle())

                            Text(appLanguage == "en" ? card.titleEN : card.title)
                                .font(.title.bold())
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text(appLanguage == "en" ? card.bodyEN : card.body)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            Text(appLanguage == "en" ? card.exampleEN : card.example)
                                .font(.subheadline.italic())
                                .foregroundColor(card.iconColor)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(card.iconColor.opacity(0.1))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(card.iconColor.opacity(0.2), lineWidth: 1)
                                )
                                .padding(.horizontal, 32)
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 480)

                Spacer()

                Button {
                    if currentCard < cards.count - 1 {
                        withAnimation(.spring()) {
                            currentCard += 1
                        }
                    } else {
                        onContinue()
                    }
                } label: {
                    HStack {
                        Text(currentCard < cards.count - 1
                             ? (appLanguage == "en" ? "Next" : "İleri")
                             : (appLanguage == "en" ? "Get Started" : "Başlayalım"))
                            .font(.headline)
                        Image(systemName: "arrow.right")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(themeManager.current.accent)
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)

                if currentCard < cards.count - 1 {
                    Button {
                        onContinue()
                    } label: {
                        Text(appLanguage == "en" ? "Skip" : "Geç")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                }

                Spacer().frame(height: 40)
            }
        }
    }
}
