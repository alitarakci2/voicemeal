//
//  Step3ModeSelectView.swift
//  VoiceMeal
//

import SwiftUI

struct Step3ModeSelectView: View {
    @Binding var selectedMode: TrackingMode

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(L.modeSelectTitle.localized)
                        .font(Theme.titleFont)
                        .multilineTextAlignment(.center)

                    Text(L.modeSelectSubtitle.localized)
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                VStack(spacing: 12) {
                    modeCard(
                        mode: .goal,
                        emoji: "🎯",
                        title: L.modeGoalTitle.localized,
                        desc: L.modeGoalDesc.localized
                    )
                    modeCard(
                        mode: .observe,
                        emoji: "📝",
                        title: L.modeObserveTitle.localized,
                        desc: L.modeObserveDesc.localized
                    )
                }
            }
            .padding()
        }
    }

    private func modeCard(mode: TrackingMode, emoji: String, title: String, desc: String) -> some View {
        Button {
            selectedMode = mode
        } label: {
            HStack(spacing: 14) {
                Text(emoji)
                    .font(.system(size: 32))
                    .frame(width: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Theme.bodyFont)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(desc)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: selectedMode == mode ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedMode == mode ? Theme.accent : Theme.textTertiary)
                    .font(.system(size: 24))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selectedMode == mode
                    ? Theme.accent.opacity(0.12)
                    : Theme.cardBackground
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selectedMode == mode ? Theme.accent.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
