//
//  HomeView+MealEntrySection.swift
//  VoiceMeal
//

import Sentry
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

                VStack(spacing: 12) {
                    ZStack {
                        // Layer 1: Outer glow halo
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        (speechService.isRecording ? Theme.danger : Theme.accent).opacity(0.40),
                                        (speechService.isRecording ? Theme.danger : Theme.accent).opacity(0.0)
                                    ],
                                    center: .center,
                                    startRadius: 40,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)
                            .blur(radius: 14)
                            .opacity(speechService.isRecording ? 1.0 : 0.55)
                            .animation(Motion.pulse, value: speechService.isRecording)
                            .allowsHitTesting(false)

                        // Layer 2 + 3: Button surface + icon
                        Button {
                            handleMicTap()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: speechService.isRecording
                                                ? [Theme.danger, Color(hex: "#CC2A20")]
                                                : [Theme.accent, Theme.accentDim],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Circle().stroke(Color.white.opacity(0.10), lineWidth: 1)
                                    )
                                    .shadow(
                                        color: (speechService.isRecording ? Theme.danger : Theme.accent).opacity(0.45),
                                        radius: 24, x: 0, y: 8
                                    )

                                Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 44, weight: .medium))
                                    .foregroundStyle(.white)
                                    .symbolEffect(.pulse, options: .repeating, isActive: speechService.isRecording)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isAnalyzing)
                        .sensoryFeedback(.impact, trigger: speechService.isRecording)
                        .scaleEffect(isMicPressed ? 0.96 : 1.0)
                        .animation(Motion.snappy, value: isMicPressed)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in isMicPressed = true }
                                .onEnded { _ in isMicPressed = false }
                        )

                        // Cancel button (top-right of the 200×200 frame)
                        if speechService.isRecording {
                            Button {
                                BrandHaptics.warning()
                                speechService.cancelListening()
                                originalSpeechText = ""
                                errorMessage = nil
                                showRetryButton = false
                                let crumb = Breadcrumb()
                                crumb.level = .info
                                crumb.category = "voice.cancelled"
                                crumb.message = "User cancelled recording"
                                SentrySDK.addBreadcrumb(crumb)
                                FeedbackService.shared.addLog("Voice recording cancelled by user")
                                FeedbackService.shared.logVoiceEvent(icon: "❌", message: "User cancelled recording")
                                FeedbackService.shared.endVoiceSession(reason: .cancelled)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(Spacing.s)
                                    .background(Theme.danger)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .transition(.scale.combined(with: .opacity))
                            .accessibilityLabel(L.cancel.localized)
                        }
                    }
                    .frame(width: 200, height: 200)

                    Text(speechService.isRecording
                         ? "listening".localized
                         : "voice_record".localized)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }

                Spacer()
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: speechService.isRecording)

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

            if (speechService.isRecording || isAnalyzing) && !speechService.transcript.isEmpty {
                Text(speechService.transcript)
                    .font(.system(size: 14))
                    .italic()
                    .foregroundStyle(Theme.textSecondary.opacity(0.7))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 24)
                    .animation(nil, value: speechService.transcript)
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

            Text(groqService.appLanguage == "en"
                 ? "Said \"2 eggs\" but got \"3\"? Hard to correct?\nWe're in beta — shake your phone to report 🤝"
                 : "\"2 yumurta\" dedim, \"3 yumurta\" mı yazdı? Düzeltmek zor mu oluyor?\nBeta sürümdeyiz — telefonu salla, bize bildir 🤝")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 4)
        }
    }

    var errorSection: some View {
        VStack(spacing: 10) {
            if let error = errorMessage {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Theme.warning)
                        Text(L.error.localized)
                            .font(.subheadline.bold())
                            .foregroundColor(Theme.warning)
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
                .background(BrandColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.l))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.l)
                        .stroke(Theme.warning.opacity(0.30), lineWidth: 0.5)
                )
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if showRetryButton && !originalSpeechText.isEmpty && !isAnalyzing {
                Button {
                    FeedbackService.shared.addLog("Try Again tapped, transcript: \(originalSpeechText.prefix(50))")
                    FeedbackService.shared.logVoiceEvent(icon: "🔄", message: "Try Again tapped")
                    FeedbackService.shared.trackVoiceMetric(.tryAgain)
                    showRetryButton = false
                    runNormalMealParse(finalTranscript: originalSpeechText)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                        Text(L.tryAgain.localized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Theme.accent)
                    .clipShape(Capsule())
                    .shadow(color: Theme.accent.opacity(0.3), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
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
                Button {
                    FeedbackService.shared.logVoiceEvent(icon: "❌", message: "User closed review card")
                    FeedbackService.shared.endVoiceSession(reason: .cancelled)
                    resetVoiceState()
                } label: {
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
                    MealReviewRow(
                        meal: meal,
                        emoji: mealEmoji(for: meal.name),
                        isListening: isListening,
                        onAmountCommit: { newNumericString in
                            commitAmountEdit(at: index, newNumericString: newNumericString)
                        },
                        onCaloriesCommit: { newCalories in
                            commitCaloriesEdit(at: index, newCalories: newCalories)
                        },
                        onFix: { startFixingReviewMeal(meal) },
                        onDelete: { deleteReviewMeal(at: index) }
                    )

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

                Button {
                    if let current = FeedbackService.shared.currentVoiceSession {
                        voiceReportSession = current
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("🐛")
                        Text(groqService.appLanguage == "en"
                             ? "Report issue with this session"
                             : "Bu kayıtla ilgili sorun bildir")
                            .font(.caption2)
                    }
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .disabled(isListening || FeedbackService.shared.currentVoiceSession == nil)
                .accessibilityLabel(groqService.appLanguage == "en"
                                    ? "Report issue, action button"
                                    : "Sorun bildir, aksiyon butonu")
            }
            .padding(16)
        }
        .background(BrandColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl)
                .stroke(BrandColors.border, lineWidth: 0.5)
        )
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
            FeedbackService.shared.startVoiceSession()
            FeedbackService.shared.logVoiceEvent(
                icon: "🔧",
                message: "Post-save correction started",
                data: ["target_entry": entry.name]
            )
        } catch {
            errorMessage = speechService.lastError ?? "mic_error".localized
        }
    }

    func startFixingReviewMeal(_ meal: ParsedMeal) {
        fixingMealName = meal.name
        errorMessage = nil
        do {
            try speechService.startListening()
            FeedbackService.shared.logVoiceEvent(
                icon: "🔧",
                message: "Fix meal: \(meal.name)",
                data: ["target_meal": meal.name]
            )
            FeedbackService.shared.trackVoiceMetric(.correction)
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
        showRetryButton = false
        manuallyEditedMealNames = []
    }

    // MARK: - Inline edit helpers

    static func numericPrefix(of s: String) -> String {
        var result = ""
        for ch in s {
            if ch.isNumber || ch == "." || ch == "," {
                result.append(ch)
            } else if !result.isEmpty {
                break
            }
        }
        return result
    }

    static func amountUnit(of s: String) -> String {
        let numeric = numericPrefix(of: s)
        guard let range = s.range(of: numeric) else { return s }
        return String(s[range.upperBound...])
    }

    func commitAmountEdit(at index: Int, newNumericString: String) {
        var meals = reviewMeals
        guard meals.indices.contains(index) else { return }
        let oldMeal = meals[index]
        let oldNumeric = Self.numericPrefix(of: oldMeal.amount)
        let unit = Self.amountUnit(of: oldMeal.amount)
        let sanitizedNew = newNumericString.replacingOccurrences(of: ",", with: ".")
        let sanitizedOld = oldNumeric.replacingOccurrences(of: ",", with: ".")

        guard let newVal = Double(sanitizedNew), newVal > 0,
              let oldVal = Double(sanitizedOld), oldVal > 0 else { return }
        if newVal == oldVal { return }

        let ratio = newVal / oldVal
        meals[index].amount = "\(newNumericString)\(unit)"
        if let cal = oldMeal.calories { meals[index].calories = cal * ratio }
        if let p = oldMeal.protein { meals[index].protein = p * ratio }
        if let c = oldMeal.carbs { meals[index].carbs = c * ratio }
        if let f = oldMeal.fat { meals[index].fat = f * ratio }
        reviewMeals = meals
        manuallyEditedMealNames.insert(oldMeal.name)
        FeedbackService.shared.addLog("Inline amount edit: \(oldMeal.name) \(oldNumeric)→\(newNumericString), ratio \(String(format: "%.2f", ratio))")
        FeedbackService.shared.logVoiceEvent(
            icon: "✏️",
            message: "Amount: \(oldMeal.name) \(oldNumeric)→\(newNumericString)",
            data: ["ratio": String(format: "%.2f", ratio)]
        )
        FeedbackService.shared.trackVoiceMetric(.inlineEdit)
    }

    func commitCaloriesEdit(at index: Int, newCalories: Double) {
        var meals = reviewMeals
        guard meals.indices.contains(index) else { return }
        let oldMeal = meals[index]
        guard newCalories >= 0 else { return }
        if let existing = oldMeal.calories, abs(existing - newCalories) < 0.5 { return }
        meals[index].calories = newCalories
        reviewMeals = meals
        manuallyEditedMealNames.insert(oldMeal.name)
        FeedbackService.shared.addLog("Inline calories edit: \(oldMeal.name) → \(Int(newCalories))kcal (macros unchanged)")
        FeedbackService.shared.logVoiceEvent(
            icon: "✏️",
            message: "Calories: \(oldMeal.name) → \(Int(newCalories))kcal"
        )
        FeedbackService.shared.trackVoiceMetric(.inlineEdit)
    }

    func deleteReviewMeal(at index: Int) {
        var meals = reviewMeals
        guard meals.indices.contains(index) else { return }
        let removed = meals.remove(at: index)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            reviewMeals = meals
            if meals.isEmpty {
                showReviewCard = false
                clarificationQuestion = ""
            }
        }
        manuallyEditedMealNames.remove(removed.name)
        let crumb = Breadcrumb()
        crumb.level = .info
        crumb.category = "voice.review.meal_removed"
        crumb.message = "User removed meal from review card"
        crumb.data = ["meal_name": removed.name, "remaining_count": meals.count]
        SentrySDK.addBreadcrumb(crumb)
        FeedbackService.shared.addLog("Meal removed from review: \(removed.name)")
        FeedbackService.shared.logVoiceEvent(
            icon: "🗑",
            message: "Removed: \(removed.name)",
            data: ["remaining": "\(meals.count)"]
        )
        FeedbackService.shared.trackVoiceMetric(.mealRemoved)
    }

    func handleMicTap() {
        voiceScrollTrigger.toggle()
        if speechService.isRecording {
            speechService.stopListening()
        } else {
            guard permissionGranted else {
                showPermissionAlert = true
                return
            }
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
                if !preserveState {
                    FeedbackService.shared.startVoiceSession()
                }
                FeedbackService.shared.logVoiceEvent(
                    icon: "🎤",
                    message: preserveState ? "Record started (continue)" : "Record started",
                    data: ["preserve_state": "\(preserveState)"]
                )
            } catch {
                errorMessage = speechService.lastError ?? "mic_error".localized
                print("❌ [HomeView] Mic start error: \(error)")
                FeedbackService.shared.logVoiceEvent(icon: "❌", message: "Mic start error: \(error.localizedDescription)")
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

            FeedbackService.shared.logVoiceEvent(
                icon: "📝",
                message: "Fix transcript: \(newText.prefix(80))",
                data: ["target_meal": meal.name]
            )
            FeedbackService.shared.logVoiceEvent(icon: "📤", message: "Groq request (fix)")
            FeedbackService.shared.trackVoiceMetric(.groqCall)

            Task {
                do {
                    let response = try await groqService.parseMeals(transcript: fixTranscript, personalContext: profiles.first?.fullAIContext ?? "")
                    if let updatedMeal = response.meals.first {
                        reviewMeals[mealIndex] = updatedMeal
                        FeedbackService.shared.logVoiceEvent(
                            icon: "📥",
                            message: "Groq fixed: \(updatedMeal.name) \(updatedMeal.amount) \(Int(updatedMeal.calories ?? 0))kcal"
                        )
                    } else {
                        FeedbackService.shared.logVoiceEvent(icon: "📥", message: "Groq fix: no meal returned")
                    }
                } catch {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? "mic_error".localized
                    FeedbackService.shared.logVoiceEvent(icon: "❌", message: "Groq fix error: \(error.localizedDescription)")
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

            FeedbackService.shared.logVoiceEvent(
                icon: "📝",
                message: "Correction transcript: \(newText.prefix(80))",
                data: ["target_entry": entry.name]
            )
            FeedbackService.shared.logVoiceEvent(icon: "📤", message: "Groq request (correction)")
            FeedbackService.shared.trackVoiceMetric(.groqCall)
            FeedbackService.shared.trackVoiceMetric(.correction)

            Task {
                do {
                    let response = try await groqService.parseMeals(transcript: correctionTranscript, personalContext: profiles.first?.fullAIContext ?? "")
                    FeedbackService.shared.logVoiceEvent(icon: "📥", message: "Groq correction applied")
                    applyCorrection(to: entry, from: response)
                    entryToCorrect = nil
                } catch {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? "mic_error".localized
                    FeedbackService.shared.logVoiceEvent(icon: "❌", message: "Groq correction error: \(error.localizedDescription)")
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
            FeedbackService.shared.logVoiceEvent(
                icon: "📝",
                message: "Clarification answer: \(newText.prefix(80))"
            )
            FeedbackService.shared.trackVoiceMetric(.clarification)
        } else {
            originalSpeechText = newText
            transcript = newText
            FeedbackService.shared.logVoiceEvent(
                icon: "📝",
                message: "Transcript: \(newText.prefix(120))"
            )
        }

        runNormalMealParse(finalTranscript: transcript)
    }

    func runNormalMealParse(finalTranscript: String) {
        isAnalyzing = true
        errorMessage = nil
        showRetryButton = false

        FeedbackService.shared.logVoiceEvent(
            icon: "📤",
            message: "Groq request",
            data: ["chars": "\(finalTranscript.count)"]
        )
        FeedbackService.shared.trackVoiceMetric(.groqCall)

        Task {
            do {
                let response = try await groqService.parseMeals(transcript: finalTranscript, personalContext: profiles.first?.fullAIContext ?? "")

                if isWaterTrackingEnabled, let waterMl = response.waterMl, waterMl > 0 {
                    addWater(ml: waterMl, source: "voice")
                    FeedbackService.shared.logVoiceEvent(icon: "💧", message: "Water: \(waterMl)ml")
                }

                if response.isCorrection == true {
                    FeedbackService.shared.logVoiceEvent(
                        icon: "📥",
                        message: "Groq: isCorrection → \(response.targetFoodName ?? "?")"
                    )
                    handleCorrection(response)
                } else if response.clarification_needed {
                    reviewMeals = response.meals
                    clarificationQuestion = response.clarification_question ?? ""
                    showReviewCard = true
                    FeedbackService.shared.addLog("Clarification needed: \(clarificationQuestion)")
                    FeedbackService.shared.logVoiceEvent(
                        icon: "🤔",
                        message: "Clarification: \(clarificationQuestion.prefix(100))"
                    )
                } else if !response.meals.isEmpty {
                    reviewMeals = response.meals
                    showReviewCard = true
                    let totalCal = response.meals.reduce(0) { $0 + Int($1.calories ?? 0) }
                    FeedbackService.shared.logVoiceEvent(
                        icon: "🖼",
                        message: "Review card: \(response.meals.count) yemek, \(totalCal)kcal",
                        data: ["meals": response.meals.map { $0.name }.joined(separator: ",")]
                    )
                } else if response.waterMl != nil {
                    showSavedConfirmation = true
                    FeedbackService.shared.logVoiceEvent(icon: "✅", message: "Water-only saved")
                    FeedbackService.shared.endVoiceSession(reason: .saved)
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        showSavedConfirmation = false
                    }
                } else {
                    errorMessage = L.mealNotDetected.localized
                    originalSpeechText = ""
                    let crumb = Breadcrumb()
                    crumb.level = .info
                    crumb.category = "voice.parse.no_meal_detected"
                    crumb.message = "Transcript parsed but no meal or water detected"
                    crumb.data = ["transcript_chars": finalTranscript.count]
                    SentrySDK.addBreadcrumb(crumb)
                    FeedbackService.shared.addLog("voice.parse.no_meal_detected: \(finalTranscript.count) chars")
                    FeedbackService.shared.logVoiceEvent(
                        icon: "❌",
                        message: "No meal detected",
                        data: ["chars": "\(finalTranscript.count)"]
                    )
                }
            } catch {
                print("❌ [HomeView] Groq error: \(error)")
                FeedbackService.shared.addErrorLog(error.localizedDescription)
                FeedbackService.shared.logVoiceEvent(
                    icon: "❌",
                    message: "Groq error: \(error.localizedDescription)"
                )
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Bir hata olu\u{015F}tu, tekrar deneyin"
                clarificationQuestion = ""
                reviewMeals = []
                showReviewCard = false
                if !originalSpeechText.isEmpty {
                    showRetryButton = true
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

        FeedbackService.shared.logVoiceEvent(
            icon: "✅",
            message: "Correction applied: \(entry.name) → \(entry.calories)kcal"
        )
        FeedbackService.shared.endVoiceSession(reason: .saved)

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
        do {
            try modelContext.save()
        } catch {
            errorMessage = L.saveFailed.localized
            SentrySDK.capture(error: error)
            FeedbackService.shared.addErrorLog("Meal save failed: \(error.localizedDescription)")
            return
        }
        let totalCal = meals.reduce(0) { $0 + Int($1.calories ?? 0) }
        FeedbackService.shared.addLog("Meal confirmed: \(meals.count) items, \(totalCal)kcal total")
        FeedbackService.shared.logVoiceEvent(
            icon: "✅",
            message: "Saved: \(meals.count) items, \(totalCal)kcal",
            data: ["edited_count": "\(manuallyEditedMealNames.count)"]
        )
        FeedbackService.shared.endVoiceSession(reason: .saved)

        // One-tap problematic-session prompt (spec thresholds)
        if let session = FeedbackService.shared.currentVoiceSession, session.isProblematic {
            problematicSessionToReport = session
            showProblematicPrompt = true
        }

        if !manuallyEditedMealNames.isEmpty {
            let crumb = Breadcrumb()
            crumb.level = .info
            crumb.category = "voice.review.manual_edit"
            crumb.message = "Meals saved with inline edits"
            crumb.data = [
                "edited_count": manuallyEditedMealNames.count,
                "total_count": meals.count
            ]
            SentrySDK.addBreadcrumb(crumb)
        }
        saveTodaySnapshot()
        NotificationCenter.default.post(name: .foodEntrySaved, object: nil)
        showSavedConfirmation = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showSavedConfirmation = false
        }
    }
}

// MARK: - MealReviewRow

private struct MealReviewRow: View {
    let meal: ParsedMeal
    let emoji: String
    let isListening: Bool
    let onAmountCommit: (String) -> Void
    let onCaloriesCommit: (Double) -> Void
    let onFix: () -> Void
    let onDelete: () -> Void

    @State private var amountText: String = ""
    @State private var caloriesText: String = ""
    @FocusState private var focusedField: Field?

    private enum Field { case amount, calories }

    private var unitDisplay: String {
        HomeView.amountUnit(of: meal.amount).trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(emoji)
                .font(.title3)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name.capitalized)
                    .font(Theme.bodyFont)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 6) {
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                        .frame(width: 54)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Theme.cardBackground.opacity(0.6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.cardBorder.opacity(0.4), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textPrimary)
                        .onSubmit { commitAmount() }
                    if !unitDisplay.isEmpty {
                        Text(unitDisplay)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                HStack(spacing: 6) {
                    TextField("0", text: $caloriesText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .calories)
                        .frame(width: 54)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Theme.cardBackground.opacity(0.6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.cardBorder.opacity(0.4), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .font(Theme.captionFont.bold())
                        .foregroundStyle(.white)
                        .onSubmit { commitCalories() }
                    Text("kcal")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                    Text("P:\(Int(meal.protein ?? 0))g")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.blue.opacity(0.8))
                    Text("K:\(Int(meal.carbs ?? 0))g")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.macroCarb.opacity(0.8))
                    Text("Y:\(Int(meal.fat ?? 0))g")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.green.opacity(0.8))
                }
            }

            Spacer()

            VStack(spacing: 6) {
                Button(action: onFix) {
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

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.red.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .opacity(isListening ? 0.4 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(isListening)
                .accessibilityLabel(L.delete.localized)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L.done.localized) {
                    if focusedField == .amount { commitAmount() }
                    if focusedField == .calories { commitCalories() }
                    focusedField = nil
                }
            }
        }
        .onAppear {
            amountText = HomeView.numericPrefix(of: meal.amount)
            caloriesText = "\(Int(meal.calories ?? 0))"
        }
        .onChange(of: meal.amount) { _, newValue in
            if focusedField != .amount {
                amountText = HomeView.numericPrefix(of: newValue)
            }
        }
        .onChange(of: meal.calories) { _, newValue in
            if focusedField != .calories {
                caloriesText = "\(Int(newValue ?? 0))"
            }
        }
    }

    private func commitAmount() {
        let trimmed = amountText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            amountText = HomeView.numericPrefix(of: meal.amount)
            return
        }
        onAmountCommit(trimmed)
    }

    private func commitCalories() {
        let trimmed = caloriesText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let val = Double(trimmed), val >= 0 else {
            caloriesText = "\(Int(meal.calories ?? 0))"
            return
        }
        onCaloriesCommit(val)
    }
}
