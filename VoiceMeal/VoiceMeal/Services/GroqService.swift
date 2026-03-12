//
//  GroqService.swift
//  VoiceMeal
//

import Foundation

struct ParsedMeal: Codable, Identifiable {
    var id: String { name }
    let name: String
    let amount: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

struct MealParseResponse: Codable {
    let meals: [ParsedMeal]
    let clarification_needed: Bool
    let clarification_question: String?
}

class GroqService {

    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private let model = "llama-3.3-70b-versatile"

    private let systemPrompt = """
        Sen bir beslenme asistanısın. Kullanıcının Türkçe konuşmasından \
        yenilen yemekleri çıkar ve SADECE JSON formatında yanıt ver.

        Emin olmadığın miktar veya yemek varsa clarification_needed true yap \
        ve clarification_question alanına Türkçe soru yaz.

        JSON formatı kesinlikle şu şekilde olmalı, başka hiçbir şey yazma:
        {
          "meals": [
            {
              "name": "string",
              "amount": "string",
              "calories": number,
              "protein": number,
              "carbs": number,
              "fat": number
            }
          ],
          "clarification_needed": boolean,
          "clarification_question": "string or null"
        }
        """

    func parseMeals(transcript: String) async throws -> MealParseResponse {
        let apiKey = Config.groqAPIKey
        print("[GroqService] API key present: \(!apiKey.isEmpty), length: \(apiKey.count)")
        guard !apiKey.isEmpty else {
            print("[GroqService] ERROR: API key is empty")
            throw GroqError.missingAPIKey
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": transcript]
            ],
            "temperature": 0.1
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[GroqService] REQUEST: \(request.httpMethod!) \(endpoint)")
        print("[GroqService] Headers: \(request.allHTTPHeaderFields ?? [:])")
        if let httpBody = request.httpBody, let bodyString = String(data: httpBody, encoding: .utf8) {
            print("[GroqService] Body: \(bodyString)")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("[GroqService] ERROR: Network request failed: \(error)")
            throw error
        }

        let rawResponse = String(data: data, encoding: .utf8) ?? "<non-utf8 data>"
        let httpResponse = response as? HTTPURLResponse
        print("[GroqService] RESPONSE status: \(httpResponse?.statusCode ?? -1)")
        print("[GroqService] RESPONSE body: \(rawResponse)")

        guard let httpResponse, (200...299).contains(httpResponse.statusCode) else {
            print("[GroqService] ERROR: Bad status code \(httpResponse?.statusCode ?? -1)")
            throw GroqError.apiError
        }

        let chatResponse: ChatCompletionResponse
        do {
            chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            print("[GroqService] ERROR: Failed to decode ChatCompletionResponse: \(error)")
            throw error
        }

        guard let content = chatResponse.choices.first?.message.content else {
            print("[GroqService] ERROR: No content in response choices")
            throw GroqError.emptyResponse
        }

        print("[GroqService] LLM content: \(content)")

        // Strip markdown code fences if present
        let jsonString = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonString.data(using: .utf8) else {
            print("[GroqService] ERROR: Could not convert cleaned JSON to data")
            throw GroqError.invalidJSON
        }

        do {
            let result = try JSONDecoder().decode(MealParseResponse.self, from: jsonData)
            print("[GroqService] SUCCESS: Parsed \(result.meals.count) meals")
            return result
        } catch {
            print("[GroqService] ERROR: Failed to decode MealParseResponse: \(error)")
            print("[GroqService] Cleaned JSON was: \(jsonString)")
            throw GroqError.invalidJSON
        }
    }
}

// MARK: - Groq API response types

private struct ChatCompletionResponse: Codable {
    let choices: [Choice]
}

private struct Choice: Codable {
    let message: Message
}

private struct Message: Codable {
    let content: String?
}

// MARK: - Errors

enum GroqError: LocalizedError {
    case missingAPIKey
    case apiError
    case emptyResponse
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "API anahtarı bulunamadı"
        case .apiError: "Groq API hatası"
        case .emptyResponse: "Boş yanıt alındı"
        case .invalidJSON: "Yanıt işlenemedi"
        }
    }
}
