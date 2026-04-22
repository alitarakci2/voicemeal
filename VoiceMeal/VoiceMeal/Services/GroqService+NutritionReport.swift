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
        period: ReportPeriod,
        daysOfData: Int,
        totalDaysInPeriod: Int,
        programDay: Int,
        programTotalDays: Int,
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
        let periodHint = nutritionReportPeriodHint(
            period: period,
            programDay: programDay,
            programTotalDays: programTotalDays,
            isEN: isEN
        )
        let earlyCaution = nutritionReportEarlyCautionClause(
            period: period,
            daysOfData: daysOfData,
            programDay: programDay,
            isEN: isEN
        )
        let systemPrompt = nutritionReportSystemPrompt(
            isEN: isEN,
            periodHint: periodHint,
            modeHint: modeHint,
            macroUncertainty: macroUncertainty,
            earlyCaution: earlyCaution,
            coachStyle: coachStyle,
            personalContext: personalContext
        )

        let userPrompt = nutritionReportUserPrompt(
            period: period,
            entriesPayload: entriesPayload,
            daysOfData: daysOfData,
            totalDaysInPeriod: totalDaysInPeriod,
            programDay: programDay,
            programTotalDays: programTotalDays,
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg,
            age: age,
            gender: gender,
            isEN: isEN
        )

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
        request.timeoutInterval = 25
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
            SentrySDK.capture(message: "Groq API error (nutrition \(period.rawValue)): \(code)")
            throw GroqError.apiError(statusCode: code)
        }

        let chatResponse = try JSONDecoder().decode(NutritionChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw GroqError.emptyResponse
        }

        let parsed = try parseNutritionReportJSON(content)
        let elapsed = Date().timeIntervalSince(startTime)
        FeedbackService.shared.addLog(
            "Groq nutritionReport: period=\(period.rawValue) \(String(format: "%.1f", elapsed))s score=\(parsed.score)"
        )
        logNutritionReportLengths(payload: parsed, period: period, language: lang, gapKind: gapKind)
        return parsed
    }

    private func logNutritionReportLengths(
        payload: NutritionReportPayload,
        period: ReportPeriod,
        language: String,
        gapKind: CalorieGapKind
    ) {
        let mode = modeTag(for: gapKind)
        let insightPrefix = "nutrition_report_\(period.rawValue)"
        logInsightLength(insightType: "\(insightPrefix).summary", text: payload.summary, targetMin: 90, targetMax: 130, language: language, mode: mode)
        logInsightLength(insightType: "\(insightPrefix).microInsights", text: payload.microInsights, targetMin: 180, targetMax: 260, language: language, mode: mode)
        logInsightLength(insightType: "\(insightPrefix).weeklyPattern", text: payload.weeklyPattern, targetMin: 120, targetMax: 170, language: language, mode: mode)
        for (idx, s) in payload.strengths.enumerated() {
            logInsightLength(insightType: "\(insightPrefix).strength[\(idx)]", text: s, targetMin: 60, targetMax: 100, language: language, mode: mode)
        }
        for (idx, s) in payload.improvements.enumerated() {
            logInsightLength(insightType: "\(insightPrefix).improvement[\(idx)]", text: s, targetMin: 60, targetMax: 100, language: language, mode: mode)
        }
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

    // MARK: - Prompt builders

    private func nutritionReportPeriodHint(
        period: ReportPeriod,
        programDay: Int,
        programTotalDays: Int,
        isEN: Bool
    ) -> String {
        switch period {
        case .week:
            return isEN
                ? "You are analyzing the last 7 days (calendar week). Comment on day-to-day patterns and weekly trends."
                : "Son 7 günlük (takvim haftası) veriye bakıyorsun. Günlük örüntüler ve haftalık trend üzerinden yorum yap."
        case .month:
            return isEN
                ? "You are analyzing a calendar month (~30 days). Focus on the overall trend — ignore day-to-day swings, look at weekly averages and consistency across the month."
                : "Takvim ayı (~30 gün) verisine bakıyorsun. Günlük dalgalanmaları yok say — haftalık ortalamalara, ay boyunca süregelen tutarlılığa odaklan."
        case .program:
            if isEN {
                return "You are analyzing a goal program. User is on day \(programDay) of \(programTotalDays). Frame feedback around progress toward the program goal — how the nutrition pattern so far supports or works against the end state."
            } else {
                return "Kullanıcı bir hedef programı içinde, \(programTotalDays) günlük programın \(programDay). gününde. Yorumu programın hedefine doğru ilerleme açısından yap — mevcut beslenme örüntüsü programın sonuna doğru hedefi destekliyor mu, aksatıyor mu."
            }
        }
    }

    private func nutritionReportEarlyCautionClause(
        period: ReportPeriod,
        daysOfData: Int,
        programDay: Int,
        isEN: Bool
    ) -> String {
        // Early-program or sparse-data caution: soften claims, avoid definitive statements.
        let earlyProgram = period == .program && programDay <= 3
        let sparseData = daysOfData <= 2
        guard earlyProgram || sparseData else { return "" }

        if isEN {
            return "CAUTION: Very limited data so far (days logged: \(daysOfData), program day: \(programDay)). Avoid giving a firm score — use 'too early to tell' framing. Replace definitive claims like 'iron is low' with cautious wording like 'a few more days of logs will make this clearer'. Soft language throughout."
        } else {
            return "DİKKAT: Henüz çok sınırlı veri (kayıtlı gün: \(daysOfData), program günü: \(programDay)). Kesin skor vermekten kaçın — 'henüz erken' tonuyla ver. 'Demir düşük' gibi kesin iddialar yerine 'birkaç gün daha kayıt tutarsan net görünür' gibi temkinli dil kullan. Genel olarak yumuşak dil."
        }
    }

    private func nutritionReportUserPrompt(
        period: ReportPeriod,
        entriesPayload: String,
        daysOfData: Int,
        totalDaysInPeriod: Int,
        programDay: Int,
        programTotalDays: Int,
        currentWeightKg: Double,
        goalWeightKg: Double,
        age: Int,
        gender: String,
        isEN: Bool
    ) -> String {
        let header: String
        let payloadFormatHint: String
        switch period {
        case .week:
            header = isEN ? "Weekly meal data:" : "Haftalık yemek verisi:"
            payloadFormatHint = isEN
                ? "Meal entries (compact JSON, d=day index 0=Mon..6=Sun):"
                : "Yemek girişleri (kompakt JSON, d=gün indeksi 0=Pzt..6=Paz):"
        case .month:
            header = isEN ? "Monthly meal data (calendar month):" : "Aylık yemek verisi (takvim ayı):"
            payloadFormatHint = isEN
                ? "Daily aggregates (compact JSON, d=day index 0-based from month start, m=meal count):"
                : "Günlük toplamlar (kompakt JSON, d=ay başından 0 tabanlı gün indeksi, m=öğün sayısı):"
        case .program:
            header = isEN ? "Program meal data:" : "Program yemek verisi:"
            payloadFormatHint = isEN
                ? "Daily aggregates (compact JSON, d=day index 0-based from program start, m=meal count):"
                : "Günlük toplamlar (kompakt JSON, d=program başından 0 tabanlı gün indeksi, m=öğün sayısı):"
        }

        let daysLine: String
        switch period {
        case .week:
            daysLine = isEN
                ? "Days with data: \(daysOfData)/7"
                : "Veri olan gün sayısı: \(daysOfData)/7"
        case .month:
            daysLine = isEN
                ? "Days with data: \(daysOfData) / \(totalDaysInPeriod) in month"
                : "Veri olan gün sayısı: \(daysOfData) / \(totalDaysInPeriod) (ay boyunca)"
        case .program:
            daysLine = isEN
                ? "Days with data: \(daysOfData). Program day: \(programDay)/\(programTotalDays)."
                : "Veri olan gün sayısı: \(daysOfData). Program günü: \(programDay)/\(programTotalDays)."
        }

        let metrics = isEN
            ? "Current weight: \(String(format: "%.1f", currentWeightKg)) kg, Goal: \(String(format: "%.1f", goalWeightKg)) kg\nAge: \(age), Gender: \(gender)"
            : "Mevcut kilo: \(String(format: "%.1f", currentWeightKg)) kg, Hedef: \(String(format: "%.1f", goalWeightKg)) kg\nYaş: \(age), Cinsiyet: \(gender)"

        let returnRule = isEN
            ? """
            LENGTH CONSTRAINT (all fields): Every string must be a complete sentence. No single-word entries, no filler.
            Return JSON with keys:
            - score (integer 1-10)
            - summary (EXACTLY 1 sentence, 15-20 words, 90-130 characters)
            - strengths (array of EXACTLY 2 strings, each 10-15 words, 60-100 characters)
            - improvements (array of EXACTLY 2 strings, each 10-15 words, 60-100 characters)
            - microInsights (1-2 sentences, 30-40 words total, 180-260 characters; use \"likely/possibly/may\")
            - weeklyPattern (1-2 sentences, 20-25 words total, 120-170 characters; describes the overall pattern across the period)
            """
            : """
            UZUNLUK KURALI (tüm alanlar): Her dize tam bir cümle olmalı. Tek kelimelik giriş veya dolgu yok.
            Şu anahtarlarla JSON döndür:
            - score (tam sayı 1-10)
            - summary (TAM OLARAK 1 cümle, 12-18 kelime, 90-130 karakter)
            - strengths (TAM OLARAK 2 dizeli dizi, her biri 8-13 kelime, 60-100 karakter)
            - improvements (TAM OLARAK 2 dizeli dizi, her biri 8-13 kelime, 60-100 karakter)
            - microInsights (1-2 cümle, toplam 25-35 kelime, 180-260 karakter; \"olabilir/muhtemelen/tahminen\" kullan)
            - weeklyPattern (1-2 cümle, toplam 18-22 kelime, 120-170 karakter; dönem boyunca genel örüntüyü anlat)
            """

        return """
        \(header)
        \(daysLine)
        \(metrics)

        \(payloadFormatHint)
        \(entriesPayload)

        \(returnRule)
        """
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
            case .observe:
                return "User is in OBSERVE mode — no weight goal, just logging. Do NOT use words like 'deficit', 'surplus', 'target', 'goal', 'cutting', 'bulking'. Frame feedback around awareness, patterns, nutritional quality, balance — no judgment about calorie totals."
            }
        } else {
            switch gapKind {
            case .deficit:
                return "Kullanıcı KİLO VERME (kalori açığı) modunda. Sürdürülebilir açık, kas koruma için yeterli protein, doygunluk üzerine yorum yap."
            case .surplus:
                return "Kullanıcı KİLO/KAS ALMA (kalori fazlası) modunda. Asla daha az yemeyi önerme. 'Açık' kelimesini kullanma. Yeterli yemek, fazla kalorinin kalitesi, kas için protein üzerine yorum yap."
            case .maintain:
                return "Kullanıcı KİLO KORUMA (kalori dengesi) modunda. İstikrar, büyük sapmalardan kaçınma, dengeli makro üzerine yorum yap."
            case .observe:
                return "Kullanıcı SADECE GÖZLEM modunda — kilo hedefi yok, sadece kayıt tutuyor. 'Açık', 'fazla', 'hedef', 'kilo verme', 'kilo alma' gibi kelimeleri KULLANMA. Farkındalık, örüntüler, besin kalitesi, denge üzerine yorum yap — kalori toplamı için yargı yapma."
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
        periodHint: String,
        modeHint: String,
        macroUncertainty: String,
        earlyCaution: String,
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

        var sections: [String] = [
            langRule,
            expertBase,
            coach,
            "You are generating a nutrition report card.",
            periodHint,
            modeHint,
            macroUncertainty,
            disclaimer
        ]
        if !earlyCaution.isEmpty { sections.append(earlyCaution) }
        sections.append(jsonRule)
        return sections.joined(separator: "\n\n")
    }
}
