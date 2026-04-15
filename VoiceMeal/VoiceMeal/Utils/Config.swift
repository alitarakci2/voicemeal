//
//  Config.swift
//  VoiceMeal
//

import Foundation

enum Config {
    static var groqAPIKey: String {
        Bundle.main.object(forInfoDictionaryKey: "GROQ_API_KEY") as? String ?? ""
    }

    static var emailJSServiceID: String {
        Bundle.main.object(forInfoDictionaryKey: "EMAILJS_SERVICE_ID") as? String ?? ""
    }

    static var emailJSTemplateID: String {
        Bundle.main.object(forInfoDictionaryKey: "EMAILJS_TEMPLATE_ID") as? String ?? ""
    }

    static var emailJSPublicKey: String {
        Bundle.main.object(forInfoDictionaryKey: "EMAILJS_PUBLIC_KEY") as? String ?? ""
    }

    static var emailJSPrivateKey: String {
        Bundle.main.object(forInfoDictionaryKey: "EMAILJS_PRIVATE_KEY") as? String ?? ""
    }

    static var sentryDSN: String {
        Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String ?? ""
    }
}
