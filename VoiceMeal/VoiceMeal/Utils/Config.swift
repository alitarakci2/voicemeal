//
//  Config.swift
//  VoiceMeal
//

import Foundation

enum Config {
    static var groqAPIKey: String {
        Bundle.main.object(forInfoDictionaryKey: "GROQ_API_KEY") as? String ?? ""
    }
}
