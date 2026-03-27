//
//  PhotoAnalysisView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct PhotoAnalysisView: View {
    let image: UIImage
    let imageData: Data
    let onSave: ([ParsedMeal]) -> Void
    let onRetake: () -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var speechService = SpeechService()

    @State private var analysisState: AnalysisState = .analyzing
    @State private var response: PhotoAnalysisResponse?
    @State private var showTextField = false
    @State private var clarificationText = ""
    @State private var analysisTask: Task<Void, Never>?

    @Environment(GroqService.self) private var groqService

    enum AnalysisState {
        case analyzing
        case clarificationNeeded
        case confirmed
        case error(String)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        photoSection

                        switch analysisState {
                        case .analyzing:
                            EmptyView()
                        case .clarificationNeeded:
                            clarificationCard
                        case .confirmed:
                            confirmedCard
                        case .error(let message):
                            errorCard(message)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 120)
                }

                bottomActions
            }
            .background(Theme.background)
            .navigationTitle(L.photoAnalysis.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.cancel.localized) { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            guard analysisTask == nil else { return }
            analysisTask = Task {
                await analyzePhoto()
            }
        }
        .onDisappear {
            analysisTask?.cancel()
            analysisTask = nil
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 6)

            if analysisState.isAnalyzing {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)

                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    Text(L.analyzing.localized)
                        .font(Theme.bodyFont)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                    Text("analyzing_subtitle".localized)
                        .font(Theme.captionFont)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Confirmed Card

    private var confirmedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.green)
                Text(L.detected.localized)
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.textPrimary)
            }

            if let meals = response?.meals, !meals.isEmpty {
                ForEach(meals) { meal in
                    mealRow(meal)
                }

                Divider()
                    .overlay(Theme.cardBorder)

                if let meals = response?.meals {
                    let totalP = meals.reduce(0.0) { $0 + ($1.protein ?? 0) }
                    let totalC = meals.reduce(0.0) { $0 + ($1.carbs ?? 0) }
                    let totalF = meals.reduce(0.0) { $0 + ($1.fat ?? 0) }

                    HStack(spacing: 16) {
                        macroItem(icon: "\u{1F969}", label: L.protein.localized, value: "\(Int(totalP))g")
                        macroItem(icon: "\u{1F33E}", label: L.carbs.localized, value: "\(Int(totalC))g")
                        macroItem(icon: "\u{1FAD2}", label: L.fat.localized, value: "\(Int(totalF))g")
                    }
                }
            }
        }
        .padding()
        .modifier(ThemeCard())
    }

    private func mealRow(_ meal: ParsedMeal) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(Theme.bodyFont)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textPrimary)
                Text(meal.amount)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text("\(Int(meal.calories ?? 0)) kcal")
                .font(Theme.bodyFont)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.accent)
        }
    }

    private func macroItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(icon)
                .font(Theme.captionFont)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(Theme.microFont)
                    .foregroundStyle(Theme.textTertiary)
                Text(value)
                    .font(Theme.captionFont)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Clarification Card

    private var clarificationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.orange)
                Text(L.notSure.localized)
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.textPrimary)
            }

            if let desc = response?.description {
                Text(desc)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let question = response?.clarification_question {
                Text("\"\(question)\"")
                    .font(Theme.bodyFont)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if let meals = response?.meals, !meals.isEmpty {
                ForEach(meals) { meal in
                    mealRow(meal)
                }
            }

            HStack(spacing: 10) {
                Button {
                    if speechService.isRecording {
                        speechService.stopListening()
                    } else {
                        try? speechService.startListening()
                    }
                } label: {
                    Label(
                        speechService.isRecording ? "listening".localized : L.voice.localized,
                        systemImage: speechService.isRecording ? "mic.fill" : "mic"
                    )
                    .font(Theme.captionFont)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(speechService.isRecording ? Theme.red.opacity(0.12) : Theme.accent.opacity(0.1))
                    .foregroundStyle(speechService.isRecording ? Theme.red : Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(speechService.isRecording ? Theme.red.opacity(0.3) : Theme.accent.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showTextField = true
                } label: {
                    Label(L.typeText.localized, systemImage: "pencil")
                        .font(Theme.captionFont)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if showTextField {
                HStack(spacing: 8) {
                    TextField(L.amountOrDescription.localized, text: $clarificationText)
                        .font(Theme.bodyFont)
                        .padding(10)
                        .background(Theme.cardBorder.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(Theme.textPrimary)
                    Button {
                        Task { await sendClarification(clarificationText) }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(clarificationText.isEmpty ? Theme.textTertiary : Theme.accent)
                    }
                    .disabled(clarificationText.isEmpty)
                }
            }

            Button {
                analysisState = .confirmed
            } label: {
                HStack {
                    Image(systemName: "checkmark")
                    Text(L.confirmContinue.localized)
                }
                .font(Theme.captionFont)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.green)
        }
        .padding()
        .modifier(ThemeCard())
        .onChange(of: speechService.isRecording) { oldValue, newValue in
            if oldValue && !newValue && !speechService.transcript.isEmpty {
                Task { await sendClarification(speechService.transcript) }
            }
        }
    }

    // MARK: - Error Card

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.red)

            Text("not_detected".localized)
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.textPrimary)

            Text(message)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .modifier(ThemeCard())
    }

    // MARK: - Bottom Actions

    @ViewBuilder
    private var bottomActions: some View {
        VStack(spacing: 10) {
            switch analysisState {
            case .analyzing:
                EmptyView()

            case .confirmed:
                if let meals = response?.meals, !meals.isEmpty {
                    Button {
                        onSave(meals)
                        dismiss()
                    } label: {
                        Text(L.save.localized)
                            .font(Theme.bodyFont)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button {
                        analysisState = .clarificationNeeded
                    } label: {
                        Text(L.edit.localized)
                            .font(Theme.bodyFont)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

            case .error:
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onRetake()
                    }
                } label: {
                    Label(L.retakePhoto.localized, systemImage: "camera")
                        .font(Theme.bodyFont)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    dismiss()
                } label: {
                    Text(L.cancel.localized)
                        .font(Theme.bodyFont)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.textSecondary)
                }

            case .clarificationNeeded:
                EmptyView()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .opacity(analysisState.isAnalyzing || analysisState.isClarification ? 0 : 1)
    }

    // MARK: - Actions

    private func analyzePhoto() async {
        analysisState = .analyzing

        do {
            let result = try await groqService.analyzeFood(imageData: imageData)
            response = result

            if !result.detected {
                analysisState = .error(result.description)
            } else if result.clarification_needed {
                analysisState = .clarificationNeeded
            } else if result.confidence == "high" {
                analysisState = .confirmed
            } else {
                analysisState = .clarificationNeeded
            }
        } catch {
            if Task.isCancelled { return }
            print("\u{1F4F7} [ERROR] \(type(of: error)): \(error)")
            analysisState = .error("\(L.analysisError.localized) \(error.localizedDescription)")
        }
    }

    private func sendClarification(_ text: String) async {
        guard let original = response else { return }
        analysisState = .analyzing

        do {
            let result = try await groqService.clarifyFoodAnalysis(
                originalResponse: original,
                clarification: text,
                imageData: imageData
            )
            response = result

            if !result.detected {
                analysisState = .error(result.description)
            } else {
                analysisState = .confirmed
            }
        } catch {
            print("\u{1F4F7} [ERROR] Clarification failed: \(type(of: error)): \(error)")
            analysisState = .error("\(L.clarificationError.localized) \(error.localizedDescription)")
        }
    }
}

// MARK: - AnalysisState helpers

extension PhotoAnalysisView.AnalysisState {
    var isAnalyzing: Bool {
        if case .analyzing = self { return true }
        return false
    }

    var isClarification: Bool {
        if case .clarificationNeeded = self { return true }
        return false
    }
}
