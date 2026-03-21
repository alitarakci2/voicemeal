//
//  TDEEWarningBanner.swift
//  VoiceMeal
//

import SwiftUI

struct TDEEWarningBanner: View {
    let morningTDEE: Int
    let currentTDEE: Int
    let dropPercent: Int
    let currentGoal: Int
    let updatedGoal: Int
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("⚠️ \("tdee_drop_warning".localized)")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.orange)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("morning_estimate".localized)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(morningTDEE) kcal")
                        .foregroundStyle(Theme.textPrimary)
                }
                HStack {
                    Text("current_estimate".localized)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(currentTDEE) kcal")
                        .foregroundStyle(Theme.orange)
                }
                Text(String(format: "drop_percent".localized, dropPercent))
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.red)
            }
            .font(Theme.captionFont)

            Divider()
                .overlay(Theme.cardBorder)

            Text(String(format: "goal_would_change".localized, currentGoal, updatedGoal))
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 12) {
                Button {
                    onAccept()
                } label: {
                    Label("update_goal".localized, systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.green)

                Button {
                    onDismiss()
                } label: {
                    Label("keep_goal".localized, systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.cardBackground)
            }
            .font(Theme.captionFont)
        }
        .padding()
        .themeCard()
    }
}
