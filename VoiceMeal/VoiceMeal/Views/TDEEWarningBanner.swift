//
//  TDEEWarningBanner.swift
//  VoiceMeal
//

import SwiftUI

struct TDEEWarningBanner: View {
    let hasWorkout: Bool
    let currentGoal: Int
    let updatedGoal: Int
    let gapKind: CalorieGapKind
    let onAccept: () -> Void
    let onDismiss: () -> Void

    private var noWorkoutBodyKey: String {
        switch gapKind {
        case .surplus:  return "banner_no_workout_body_surplus"
        case .maintain: return "banner_no_workout_body_maintain"
        case .deficit:  return "banner_no_workout_body"
        case .observe:  return "banner_no_workout_body"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hasWorkout {
                workoutScenario
            } else {
                noWorkoutScenario
            }
        }
        .padding()
        .themeCard()
    }

    // MARK: - Scenario A: Workout scheduled

    private var workoutScenario: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("💪 \("banner_workout_title".localized)")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.green)

            Text(String(format: "banner_workout_body".localized, currentGoal))
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textSecondary)

            Text("banner_workout_note".localized)
                .font(Theme.microFont)
                .foregroundStyle(Theme.textTertiary)

            Button {
                onDismiss()
            } label: {
                Text("banner_ok".localized)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.green)
            .font(Theme.captionFont)
        }
    }

    // MARK: - Scenario B: No workout, TDEE dropped

    private var noWorkoutScenario: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🌙 \("banner_no_workout_title".localized)")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.warning)

            Text(String(format: noWorkoutBodyKey.localized, updatedGoal))
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
    }
}
