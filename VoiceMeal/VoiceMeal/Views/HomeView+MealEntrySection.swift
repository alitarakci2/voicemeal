//
//  HomeView+MealEntrySection.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

extension HomeView {

    var mealEntrySection: some View {
        VStack(spacing: 24) {
            Text(L.whatDidYouEat.localized)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)

            HStack {
                Spacer()

                Button {
                    handleMicTap()
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: speechService.isRecording ? "mic.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(speechService.isRecording ? Theme.red : Theme.accent)
                            .padding(28)
                            .background(
                                (speechService.isRecording ? Theme.red : Theme.accent).opacity(0.1)
                            )
                            .clipShape(Circle())

                        Text(speechService.isRecording
                             ? "listening".localized
                             : "voice_record".localized)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isAnalyzing)
                .sensoryFeedback(.impact, trigger: speechService.isRecording)

                Spacer()
            }

            if isAnalyzing {
                ProgressView(L.analyzing.localized)
            } else if showCorrected {
                Text("corrected_confirmation".localized)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.blue)
            } else if showSavedConfirmation {
                Text("saved_confirmation".localized)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.green)
            } else {
                Text(speechService.isRecording ? "listening".localized : L.ready.localized)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(speechService.isRecording ? Theme.red : Theme.textSecondary)
            }

            if !correctionQuestion.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Text("\u{270F}\u{FE0F}")
                    Text(correctionQuestion)
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    var errorSection: some View {
        Group {
            if let error = errorMessage {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(L.error.localized)
                            .font(.subheadline.bold())
                            .foregroundColor(.orange)
                    }
                    Text(error.isEmpty
                         ? L.couldNotProcess.localized
                         : error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Text(L.tapMicRetry.localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Meal Review Card

    var mealReviewCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L.reviewMeals.localized)
                    .font(Theme.bodyFont)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button { resetVoiceState() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.textTertiary)
                        .opacity(isListening ? 0.4 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(isListening)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().overlay(Theme.cardBorder.opacity(0.3)).padding(.horizontal)

            ForEach(Array(reviewMeals.enumerated()), id: \.offset) { index, meal in
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 10) {
                        Text(mealEmoji(for: meal.name))
                            .font(.title3)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(meal.name.capitalized)
                                .font(Theme.bodyFont)
                                .fontWeight(.medium)
                                .foregroundStyle(Theme.textPrimary)

                            if !meal.amount.isEmpty {
                                Text(meal.amount)
                                    .font(Theme.captionFont)
                                    .foregroundStyle(Theme.textSecondary)
                            }

                            HStack(spacing: 6) {
                                Text("\(Int(meal.calories ?? 0)) kcal")
                                    .font(Theme.captionFont)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                Text("P:\(Int(meal.protein ?? 0))g")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Theme.blue.opacity(0.8))
                                Text("K:\(Int(meal.carbs ?? 0))g")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Theme.orange.opacity(0.8))
                                Text("Y:\(Int(meal.fat ?? 0))g")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Theme.green.opacity(0.8))
                            }
                        }

                        Spacer()

                        Button { startFixingReviewMeal(meal) } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 10))
                                Text(L.fixMeal.localized)
                                    .font(.caption)
                            }
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .opacity(isListening ? 0.4 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .disabled(isListening)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    if index < reviewMeals.count - 1 {
                        Divider().overlay(Theme.cardBorder.opacity(0.2)).padding(.horizontal, 16)
                    }
                }
            }

            if !clarificationQuestion.isEmpty {
                Divider().overlay(Theme.cardBorder.opacity(0.3)).padding(.horizontal)
                HStack(alignment: .top, spacing: 8) {
                    Text("\u{1F916}")
                    Text(clarificationQuestion)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Text(L.tapMicAnswer.localized)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }

            if let fixing = fixingMealName {
                Divider().overlay(Theme.cardBorder.opacity(0.3)).padding(.horizontal)
                HStack(alignment: .top, spacing: 8) {
                    Text("\u{270F}\u{FE0F}")
                    Text(String(format: L.tellAboutFormat.localized, fixing))
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            if isListening {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Theme.red)
                        .frame(width: 8, height: 8)
                    Text(L.listening.localized)
                        .font(.caption)
                        .foregroundStyle(Theme.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }

            Divider().overlay(Theme.cardBorder.opacity(0.3)).padding(.horizontal)

            VStack(spacing: 8) {
                HStack {
                    Text(L.total.localized)
                        .font(Theme.bodyFont)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(reviewMeals.reduce(0) { $0 + Int($1.calories ?? 0) }) kcal")
                        .font(Theme.bodyFont)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.accent)
                }

                Button {
                    saveEntries(from: reviewMeals)
                    resetVoiceState()
                } label: {
                    Label(L.saveAll.localized, systemImage: "checkmark")
                        .font(Theme.bodyFont)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isListening ? Theme.accent.opacity(0.4) : Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isListening)
            }
            .padding(16)
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Voice Actions

    func startVoiceCorrection(for entry: FoodEntry) {
        resetVoiceState()
        entryToCorrect = entry
        correctionQuestion = String(format: "what_to_change".localized, entry.name)
        errorMessage = nil
        showSavedConfirmation = false
        do {
            try speechService.startListening()
        } catch {
            errorMessage = speechService.lastError ?? "mic_error".localized
        }
    }

    func startFixingReviewMeal(_ meal: ParsedMeal) {
        fixingMealName = meal.name
        errorMessage = nil
        do {
            try speechService.startListening()
        } catch {
            errorMessage = speechService.lastError ?? "mic_error".localized
            fixingMealName = nil
        }
    }

    func resetVoiceState() {
        clarificationQuestion = ""
        correctionQuestion = ""
        entryToCorrect = nil
        fixingMealName = nil
        reviewMeals = []
        showReviewCard = false
        originalSpeechText = ""
    }

    func handleMicTap() {
        voiceScrollTrigger.toggle()
        if speechService.isRecording {
            speechService.stopListening()
        } else {
            guard permissionGranted else { return }
            errorMessage = nil
            showSavedConfirmation = false
            let preserveState = !clarificationQuestion.isEmpty
                || !correctionQuestion.isEmpty
                || fixingMealName != nil
            if !preserveState {
                resetVoiceState()
            }
            do {
                try speechService.startListening()
                FeedbackService.shared.addLog("Voice recording started")
                FeedbackService.shared.lastAction = "Meal entry"
            } catch {
                errorMessage = speechService.lastError ?? "mic_error".localized
                print("❌ [HomeView] Mic start error: \(error)")
            }
        }
    }

    // MARK: - Groq Processing

    func sendToGroq() {
        let newText = speechService.transcript

        if let mealName = fixingMealName,
           let mealIndex = reviewMeals.firstIndex(where: { $0.name == mealName }) {
            let meal = reviewMeals[mealIndex]
            let lang = groqService.appLanguage
            let fixTranscript: String
            if lang == "en" {
                fixTranscript = """
                Current meal: \(meal.name), \(meal.amount), \(Int(meal.calories ?? 0)) kcal, \
                P:\(Int(meal.protein ?? 0))g C:\(Int(meal.carbs ?? 0))g F:\(Int(meal.fat ?? 0))g. \
                User correction: "\(newText)". \
                Update values based on what user said. Verify consistency: \
                protein×4 + carbs×4 + fat×9 ≈ calories (adjust carbs if needed). \
                Return updated meal in meals array. clarification_needed: false. \
                Keep the food name ('\(meal.name)') as-is \
                UNLESS the user explicitly mentioned a different food. \
                If name changes, it must be in English.
                """
            } else {
                fixTranscript = """
                Mevcut yemek: \(meal.name), \(meal.amount), \(Int(meal.calories ?? 0)) kcal, \
                P:\(Int(meal.protein ?? 0))g K:\(Int(meal.carbs ?? 0))g Y:\(Int(meal.fat ?? 0))g. \
                Kullanıcı düzeltmesi: "\(newText)". \
                Söylenene göre değerleri güncelle. Tutarlılık kontrolü: \
                protein×4 + karb×4 + yağ×9 ≈ kalori (gerekirse karbı ayarla). \
                Güncel yemeği meals dizisinde döndür. clarification_needed: false. \
                Yemek adını ('\(meal.name)') aynen koru \
                SADECE kullanıcı farklı bir yemek adı söylemedikçe. \
                Ad değiştirilecekse Türkçe olmalı.
                """
            }

            isAnalyzing = true
            errorMessage = nil

            Task {
                do {
                    let response = try await groqService.parseMeals(transcript: fixTranscript, personalContext: profiles.first?.fullAIContext ?? "")
                    if let updatedMeal = response.meals.first {
                        reviewMeals[mealIndex] = updatedMeal
                    }
                } catch {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? "mic_error".localized
                }
                fixingMealName = nil
                isAnalyzing = false
            }
            return
        }

        if let entry = entryToCorrect {
            let lang = groqService.appLanguage
            let correctionTranscript: String
            if lang == "en" {
                correctionTranscript = """
                Previously saved: \(entry.name), \(entry.amount), \(entry.calories) kcal, \
                P:\(Int(entry.protein))g C:\(Int(entry.carbs))g F:\(Int(entry.fat))g. \
                User wants to change: "\(newText)". \
                Update only the changed fields. Set isCorrection: true, targetFoodName: "\(entry.name)". \
                Keep the food name ('\(entry.name)') as-is \
                UNLESS the user explicitly mentioned a different food. \
                If name changes, it must be in English.
                """
            } else {
                correctionTranscript = """
                Daha önce kaydedilen: \(entry.name), \(entry.amount), \(entry.calories) kcal, \
                P:\(Int(entry.protein))g K:\(Int(entry.carbs))g Y:\(Int(entry.fat))g. \
                Kullanıcı düzeltmek istiyor: "\(newText)". \
                Sadece değişen alanları güncelle. isCorrection: true, targetFoodName: "\(entry.name)" yap. \
                Yemek adını ('\(entry.name)') aynen koru \
                SADECE kullanıcı farklı bir yemek adı söylemedikçe. \
                Ad değiştirilecekse Türkçe olmalı.
                """
            }

            isAnalyzing = true
            errorMessage = nil
            correctionQuestion = ""

            Task {
                do {
                    let response = try await groqService.parseMeals(transcript: correctionTranscript, personalContext: profiles.first?.fullAIContext ?? "")
                    applyCorrection(to: entry, from: response)
                    entryToCorrect = nil
                } catch {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? "mic_error".localized
                    entryToCorrect = nil
                }
                isAnalyzing = false
            }
            return
        }

        let transcript: String
        if !clarificationQuestion.isEmpty && !originalSpeechText.isEmpty {
            transcript = originalSpeechText + ". " + newText
            clarificationQuestion = ""
        } else {
            originalSpeechText = newText
            transcript = newText
        }

        isAnalyzing = true
        errorMessage = nil

        Task {
            do {
                let response = try await groqService.parseMeals(transcript: transcript, personalContext: profiles.first?.fullAIContext ?? "")

                if isWaterTrackingEnabled, let waterMl = response.waterMl, waterMl > 0 {
                    addWater(ml: waterMl, source: "voice")
                }

                if response.isCorrection == true {
                    handleCorrection(response)
                } else if response.clarification_needed {
                    reviewMeals = response.meals
                    clarificationQuestion = response.clarification_question ?? ""
                    showReviewCard = true
                    FeedbackService.shared.addLog("Clarification needed: \(clarificationQuestion)")
                } else if !response.meals.isEmpty {
                    reviewMeals = response.meals
                    showReviewCard = true
                } else if response.waterMl != nil {
                    showSavedConfirmation = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        showSavedConfirmation = false
                    }
                }
            } catch {
                print("❌ [HomeView] Groq error: \(error)")
                FeedbackService.shared.addErrorLog(error.localizedDescription)
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Bir hata olu\u{015F}tu, tekrar deneyin"
                clarificationQuestion = ""
                reviewMeals = []
                showReviewCard = false
                originalSpeechText = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    errorMessage = nil
                }
            }
            isAnalyzing = false
        }
    }

    func handleCorrection(_ response: MealParseResponse) {
        guard let targetName = response.targetFoodName else {
            errorMessage = "D\u{00FC}zeltilecek yemek belirlenemedi"
            return
        }

        let matches = todayEntries.filter {
            $0.name.localizedCaseInsensitiveContains(targetName)
        }

        if matches.count == 1, let entry = matches.first {
            applyCorrection(to: entry, from: response)
        } else if matches.count > 1 {
            correctionPickerEntries = matches
        } else {
            correctionPickerEntries = todayEntries
        }
    }

    func applyCorrection(to entry: FoodEntry, from response: MealParseResponse) {
        if let newAmount = response.correctedAmount,
           response.correctedCalories == nil {
            let ratio = parseAmountRatio(old: entry.amount, new: newAmount)
            if let ratio, ratio > 0, ratio != 1.0 {
                entry.calories = Int(Double(entry.calories) * ratio)
                entry.protein = entry.protein * ratio
                entry.carbs = entry.carbs * ratio
                entry.fat = entry.fat * ratio
                entry.amount = newAmount
            } else {
                entry.amount = newAmount
            }
        } else {
            if let cal = response.correctedCalories { entry.calories = cal }
            if let pro = response.correctedProtein { entry.protein = pro }
            if let carb = response.correctedCarbs { entry.carbs = carb }
            if let fat = response.correctedFat { entry.fat = fat }
            if let amount = response.correctedAmount { entry.amount = amount }
        }
        try? modelContext.save()
        saveTodaySnapshot()

        showCorrected = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showCorrected = false
        }
    }

    func parseAmountRatio(old: String, new: String) -> Double? {
        func extractNumber(_ s: String) -> Double? {
            let digits = s.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            return Double(digits)
        }
        guard let oldNum = extractNumber(old), oldNum > 0,
              let newNum = extractNumber(new) else {
            return nil
        }
        return newNum / oldNum
    }

    func saveEntries(from meals: [ParsedMeal]) {
        for meal in meals {
            let entry = FoodEntry(
                name: meal.name,
                amount: meal.amount,
                calories: Int(meal.calories ?? 0),
                protein: meal.protein ?? 0,
                carbs: meal.carbs ?? 0,
                fat: meal.fat ?? 0
            )
            modelContext.insert(entry)
            FeedbackService.shared.addLog("Meal saved: \(meal.name) - \(Int(meal.calories ?? 0))kcal")
        }
        try? modelContext.save()
        let totalCal = meals.reduce(0) { $0 + Int($1.calories ?? 0) }
        FeedbackService.shared.addLog("Meal confirmed: \(meals.count) items, \(totalCal)kcal total")
        saveTodaySnapshot()
        showSavedConfirmation = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showSavedConfirmation = false
        }
    }
}
