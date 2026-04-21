//
//  GroqService+NutritionReport.swift
//  VoiceMeal
//

import Foundation
import Sentry

struct NutritionReportPayload: Codable {
    let score: Int
    let summary: String
    let strengths: [String]
    let improvements: [String]
    let microInsights: String
    let weeklyPattern: String
}

private struct NutritionChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable { let content: String }
        let message: Message
    }
    let choices: [Choice]
}

private let nutritionEndpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
private let nutritionModel = "meta-llama/llama-4-scout-17b-16e-instruct"

extension GroqService {
    func generateNutritionReport(
        entriesPayload: String,
        daysOfData: Int,
        gapKind: CalorieGapKind,
        currentWeightKg: Double,
        goalWeightKg: Double,
        age: Int,
        gender: String,
        coachStyle: CoachStyle = .supportive,
        personalContext: String = ""
    ) async throws -> NutritionReportPayload {
        let startTime = Date()
        let apiKey = Config.groqAPIKey
        guard !apiKey.isEmpty else { throw GroqError.missingAPIKey }

        let lang = appLanguage
        let isEN = lang == "en"

        let modeHint = nutritionReportModeHint(gapKind: gapKind, isEN: isEN)
        let macroUncertainty = macroUncertaintyClause(isEN: isEN)
        let systemPrompt = nutritionReportSystemPrompt(
            isEN: isEN,
            modeHint: modeHint,
            macroUncertainty: macroUncertainty,
            coachStyle: coachStyle,
            personalContext: personalContext
        )

        let userPrompt: String
        if isEN {
            userPrompt = """
                Weekly meal data:
                Days with data: \(daysOfData)/7
                Current weight: \(String(format: "%.1f", currentWeightKg)) kg, Goal: \(String(format: "%.1f", goalWeightKg)) kg
                Age: \(age), Gender: \(gender)

                Meal entries (compact JSON, d=day index 0=Mon..6=Sun):
                \(entriesPayload)

                Return JSON with keys: score (1-10), summary (1 sentence), \
                strengths (array of 2-3 strings), improvements (array of 2-3 strings), \
                microInsights (1-2 sentences, use "likely/possibly/may"), \
                weeklyPattern (1-2 sentences).
                """
        } else {
            userPrompt = """
                Haftalık yemek verisi:
                Veri olan gün sayısı: \(daysOfData)/7
                Mevcut kilo: \(String(format: "%.1f", currentWeightKg)) kg, Hedef: \(String(format: "%.1f", goalWeightKg)) kg
                Yaş: \(age), Cinsiyet: \(gender)

                Yemek girişleri (kompakt JSON, d=gün indeksi 0=Pzt..6=Paz):
                \(entriesPayload)

                Şu anahtarlarla JSON döndür: score (1-10), summary (1 cümle), \
                strengths (2-3 madde dizi), improvements (2-3 madde dizi), \
                microInsights (1-2 cümle, "olabilir/muhtemelen/tahminen" kullan), \
                weeklyPattern (1-2 cümle).
                """
        }

        let body: [String: Any] = [
            "model": nutritionModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.4,
            "max_tokens": 500,
            "response_format": ["type": "json_object"]
        ]

        var request = URLRequest(url: nutritionEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            throw urlError.code == .timedOut ? GroqError.timeout : GroqError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            SentrySDK.capture(message: "Groq API error (nutrition): \(code)")
            throw GroqError.apiError(statusCode: code)
        }

        let chatResponse = try JSONDecoder().decode(NutritionChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw GroqError.emptyResponse
        }

        let parsed = try parseNutritionReportJSON(content)
        let elapsed = Date().timeIntervalSince(startTime)
        FeedbackService.shared.addLog("Groq nutritionReport: \(String(format: "%.1f", elapsed))s, score=\(parsed.score)")
        return parsed
    }

    private func parseNutritionReportJSON(_ raw: String) throws -> NutritionReportPayload {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let payload = try? JSONDecoder().decode(NutritionReportPayload.self, from: data) {
            return payload
        }
        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}"),
           start < end {
            let slice = String(trimmed[start...end])
            if let data = slice.data(using: .utf8),
               let payload = try? JSONDecoder().decode(NutritionReportPayload.self, from: data) {
                return payload
            }
        }
        throw GroqError.emptyResponse
    }

    private func nutritionReportModeHint(gapKind: CalorieGapKind, isEN: Bool) -> String {
        if isEN {
            switch gapKind {
            case .deficit:
                return "User is in a CUTTING phase (calorie deficit, weight loss). Frame feedback around sustainable deficit, adequate protein for muscle retention, satiety."
            case .surplus:
                return "User is in a BULKING phase (calorie surplus, weight/muscle gain). Never suggest eating less. Never use the word 'deficit'. Frame around eating enough, quality of surplus sources, protein for muscle building."
            case .maintain:
                return "User is in a MAINTENANCE phase (calorie balance). Frame around consistency, avoiding big swings, balanced macros."
            }
        } else {
            switch gapKind {
            case .deficit:
                return "Kullanıcı KİLO VERME (kalori açığı) modunda. Sürdürülebilir açık, kas koruma için yeterli protein, doygunluk üzerine yorum yap."
            case .surplus:
                return "Kullanıcı KİLO/KAS ALMA (kalori fazlası) modunda. Asla daha az yemeyi önerme. 'Açık' kelimesini kullanma. Yeterli yemek, fazla kalorinin kalitesi, kas için protein üzerine yorum yap."
            case .maintain:
                return "Kullanıcı KİLO KORUMA (kalori dengesi) modunda. İstikrar, büyük sapmalardan kaçınma, dengeli makro üzerine yorum yap."
            }
        }
    }

    private func macroUncertaintyClause(isEN: Bool) -> String {
        if isEN {
            return "IMPORTANT: The per-meal macro values (protein/carbs/fat) were estimated by another AI and may deviate by ±15-20%. Analyze with this uncertainty in mind — comment on general trends and distribution rather than targeting exact numbers."
        } else {
            return "ÖNEMLİ: Yemek makro değerleri (protein/karbonhidrat/yağ) başka bir AI tarafından tahmin edilmiştir, ±%15-20 sapma olabilir. Analizini bu belirsizlik farkındalığıyla yap — kesin rakam hedefleme yerine genel trend ve dağılım yorumla."
        }
    }

    private func nutritionReportSystemPrompt(
        isEN: Bool,
        modeHint: String,
        macroUncertainty: String,
        coachStyle: CoachStyle,
        personalContext: String
    ) -> String {
        let expertBase = buildNutritionExpertPrompt(
            language: isEN ? "English" : "Turkish",
            locale: userLocale,
            personalContext: personalContext
        )
        let coach = coachPersonalityPrompt(for: coachStyle)
        let langRule = isEN
            ? "CRITICAL RULE: Respond in English ONLY."
            : "KRİTİK KURAL: YALNIZCA Türkçe yanıt ver."

        let disclaimerEN = "Micronutrient assessments are ESTIMATES (no nutrition database used). Use soft language: 'likely', 'possibly', 'may be'. Never make medical claims."
        let disclaimerTR = "Mikrobesin değerlendirmeleri TAHMİNDİR (nutrition database kullanılmadı). 'Olabilir', 'muhtemelen', 'tahminen' gibi yumuşak dil kullan. Medikal iddia yapma."
        let disclaimer = isEN ? disclaimerEN : disclaimerTR

        let jsonRule = isEN
            ? "Return ONLY a JSON object. No prose before or after. No markdown fences."
            : "YALNIZCA JSON objesi döndür. Önce veya sonra metin yazma. Markdown çiti kullanma."

        return """
        \(langRule)

        \(expertBase)

        \(coach)

        You are analyzing a weekly nutrition report card.

        \(modeHint)

        \(macroUncertainty)

        \(disclaimer)

        \(jsonRule)
        """
    }
}
