//
//  ReportPeriod.swift
//  VoiceMeal
//

import Foundation

enum ReportPeriod: String, Codable, CaseIterable, Identifiable {
    case week
    case month
    case program

    var id: String { rawValue }
}

enum ReportPeriodKind: Equatable {
    case current           // ongoing period, score can be given (thisWeek/thisMonth/active program)
    case previous          // completed prior period (lastWeek/lastMonth)
    case inProgress        // current, still filling up (Monday with entries, first days of month)
    case programNotStarted
    case programCompleted
}
