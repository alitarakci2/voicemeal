//
//  TooltipContent.swift
//  VoiceMeal
//

import Foundation

struct TooltipItem {
    let id: String
    let titleKey: String
    let bodyKey: String
}

enum Tooltips {
    static let tdee = TooltipItem(
        id: "tdee",
        titleKey: "tooltip_tdee_title",
        bodyKey: "tooltip_tdee_body"
    )

    static let deficit = TooltipItem(
        id: "deficit",
        titleKey: "tooltip_deficit_title",
        bodyKey: "tooltip_deficit_body"
    )

    static let bmr = TooltipItem(
        id: "bmr",
        titleKey: "tooltip_bmr_title",
        bodyKey: "tooltip_bmr_body"
    )

    static let activityMultiplier = TooltipItem(
        id: "activity_multiplier",
        titleKey: "tooltip_activity_multiplier_title",
        bodyKey: "tooltip_activity_multiplier_body"
    )

    static let vo2Max = TooltipItem(
        id: "vo2max",
        titleKey: "tooltip_vo2max_title",
        bodyKey: "tooltip_vo2max_body"
    )

    static let hrv = TooltipItem(
        id: "hrv",
        titleKey: "tooltip_hrv_title",
        bodyKey: "tooltip_hrv_body"
    )

    static let protein = TooltipItem(
        id: "protein",
        titleKey: "tooltip_protein_title",
        bodyKey: "tooltip_protein_body"
    )

    static let caloricDeficitRing = TooltipItem(
        id: "caloric_deficit_ring",
        titleKey: "tooltip_deficit_ring_title",
        bodyKey: "tooltip_deficit_ring_body"
    )

    static let macros = TooltipItem(
        id: "macros",
        titleKey: "tooltip_macros_title",
        bodyKey: "tooltip_macros_body"
    )

    static let consistency = TooltipItem(
        id: "consistency",
        titleKey: "tooltip_consistency_title",
        bodyKey: "tooltip_consistency_body"
    )
}
