//
//  WaterEntry.swift
//  VoiceMeal
//

import Foundation
import SwiftData

@Model
final class WaterEntry {
    var id: UUID
    var amountMl: Int
    var date: Date
    var source: String // "manual", "voice", "quick"

    init(amountMl: Int, date: Date = .now, source: String = "manual") {
        self.id = UUID()
        self.amountMl = amountMl
        self.date = date
        self.source = source
    }
}
