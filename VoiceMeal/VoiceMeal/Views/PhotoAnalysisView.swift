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

    private let groqService = GroqService()

    enum AnalysisState {
        case analyzing
        case clarificationNeeded
        case confirmed
        case error(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Photo thumbnail
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    // State content
                    switch analysisState {
                    case .analyzing:
                        analyzingView
                    case .clarificationNeeded:
                        clarificationView
                    case .confirmed:
                        confirmedView
                    case .error(let message):
                        errorView(message)
                    }
                }
                .padding()
            }
            .navigationTitle("Foto\u{011F}raf Analizi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("\u{0130}ptal") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            await analyzePhoto()
        }
    }

    // MARK: - State Views

    private var analyzingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("\u{1F50D} Yemek analiz ediliyor...")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding()
    }

    private var clarificationView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\u{1F914} Foto\u{011F}raftan \u{015F}unlar\u{0131} g\u{00F6}rd\u{00FC}m:")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.textPrimary)

            if let desc = response?.description {
                Text(desc)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let question = response?.clarification_question {
                Text(question)
                    .font(Theme.bodyFont)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Detected meals preview
            if let meals = response?.meals, !meals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(meals) { meal in
                        HStack {
                            Text(meal.name)
                                .font(Theme.bodyFont)
                            Text(meal.amount)
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.textTertiary)
                            Spacer()
                            Text("\(Int(meal.calories)) kcal")
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .padding()
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Clarification buttons
            HStack(spacing: 12) {
                Button {
                    if speechService.isRecording {
                        speechService.stopListening()
                    } else {
                        try? speechService.startListening()
                    }
                } label: {
                    Label(
                        speechService.isRecording ? "Dinliyorum..." : "Sesle Cevapla",
                        systemImage: speechService.isRecording ? "mic.fill" : "mic"
                    )
                    .font(Theme.captionFont)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(speechService.isRecording ? Theme.red : Theme.accent)

                Button {
                    showTextField = true
                } label: {
                    Label("Yaz", systemImage: "pencil")
                        .font(Theme.captionFont)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
            }

            if showTextField {
                HStack {
                    TextField("Miktar veya a\u{00E7}\u{0131}klama...", text: $clarificationText)
                        .textFieldStyle(.roundedBorder)
                    Button("G\u{00F6}nder") {
                        Task { await sendClarification(clarificationText) }
                    }
                    .disabled(clarificationText.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                }
            }

            // Quick confirm button
            Button {
                analysisState = .confirmed
            } label: {
                Text("Bu do\u{011F}ru, kaydet")
                    .font(Theme.bodyFont)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.green)
        }
        .onChange(of: speechService.isRecording) { oldValue, newValue in
            if oldValue && !newValue && !speechService.transcript.isEmpty {
                Task { await sendClarification(speechService.transcript) }
            }
        }
    }

    private var confirmedView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\u{2705} Tespit edildi:")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.green)

            if let meals = response?.meals, !meals.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(meals) { meal in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(meal.name)
                                    .font(Theme.bodyFont)
                                    .fontWeight(.medium)
                                Text("\u{2014} \(meal.amount)")
                                    .font(Theme.captionFont)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Text("\(Int(meal.calories)) kcal | P:\(Int(meal.protein))g K:\(Int(meal.carbs))g Y:\(Int(meal.fat))g")
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .padding()
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 12) {
                    Button {
                        onSave(meals)
                        dismiss()
                    } label: {
                        Text("Kaydet")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.green)

                    Button {
                        analysisState = .clarificationNeeded
                    } label: {
                        Text("D\u{00FC}zenle")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                }
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\u{2753} Yeme\u{011F}i tan\u{0131}yamad\u{0131}m")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.red)

            Text(message)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onRetake()
                    }
                } label: {
                    Label("Tekrar \u{00C7}ek", systemImage: "camera")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)

                Button("\u{0130}ptal") { dismiss() }
                    .buttonStyle(.bordered)
                    .tint(Theme.textSecondary)
            }
        }
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
            analysisState = .error("Analiz s\u{0131}ras\u{0131}nda hata olu\u{015F}tu: \(error.localizedDescription)")
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
            analysisState = .error("A\u{00E7}\u{0131}klama i\u{015F}lenemedi: \(error.localizedDescription)")
        }
    }
}
