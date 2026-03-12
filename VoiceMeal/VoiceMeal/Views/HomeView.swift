//
//  HomeView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var speechService = SpeechService()
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @State private var permissionGranted = false
    @State private var isAnalyzing = false
    @State private var parsedMeals: [ParsedMeal] = []
    @State private var clarificationQuestion: String?
    @State private var errorMessage: String?
    @State private var fullTranscript = ""
    @State private var showSavedConfirmation = false

    private let groqService = GroqService()

    private var todayEntries: [FoodEntry] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return allEntries.filter { $0.date >= startOfDay }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                // Mic button
                Button {
                    handleMicTap()
                } label: {
                    Image(systemName: speechService.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                        .frame(width: 120, height: 120)
                        .background(speechService.isRecording ? Color.red : Color.gray)
                        .clipShape(Circle())
                        .shadow(color: speechService.isRecording ? .red.opacity(0.4) : .clear, radius: 16)
                }
                .disabled(isAnalyzing)

                // Status label
                if isAnalyzing {
                    ProgressView("Analiz ediliyor...")
                } else if showSavedConfirmation {
                    Text("Kaydedildi \u{2713}")
                        .font(.headline)
                        .foregroundStyle(.green)
                } else {
                    Text(speechService.isRecording ? "Dinliyorum..." : "Hazır")
                        .font(.headline)
                        .foregroundStyle(speechService.isRecording ? .red : .secondary)
                }

                // Transcript
                if !speechService.transcript.isEmpty {
                    Text(speechService.transcript)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Parsed results
                if !parsedMeals.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(parsedMeals) { meal in
                            HStack {
                                Text(meal.name)
                                Spacer()
                                Text("\(Int(meal.calories)) kcal")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Divider()
                        HStack {
                            Text("Toplam")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(Int(parsedMeals.reduce(0) { $0 + $1.calories })) kcal")
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Clarification question
                if let question = clarificationQuestion {
                    Text(question)
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Error
                if let error = errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                // Today's summary
                if !todayEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bugünkü Özet")
                            .font(.headline)

                        ForEach(todayEntries, id: \.id) { entry in
                            HStack {
                                Text(entry.name)
                                Spacer()
                                Text("\(entry.calories) kcal")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }

                        Divider()

                        let totalCal = todayEntries.reduce(0) { $0 + $1.calories }
                        let totalP = todayEntries.reduce(0.0) { $0 + $1.protein }
                        let totalC = todayEntries.reduce(0.0) { $0 + $1.carbs }
                        let totalF = todayEntries.reduce(0.0) { $0 + $1.fat }

                        Text("Toplam: \(totalCal) kcal | Protein: \(Int(totalP))g | Karb: \(Int(totalC))g | Yağ: \(Int(totalF))g")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer(minLength: 20)
            }
            .padding()
        }
        .task {
            permissionGranted = await speechService.requestPermissions()
        }
        .onChange(of: speechService.isRecording) { oldValue, newValue in
            if oldValue && !newValue && !speechService.transcript.isEmpty {
                sendToGroq()
            }
        }
    }

    private func handleMicTap() {
        if speechService.isRecording {
            speechService.stopListening()
        } else {
            guard permissionGranted else { return }
            errorMessage = nil
            showSavedConfirmation = false
            if clarificationQuestion == nil {
                parsedMeals = []
                fullTranscript = ""
            }
            clarificationQuestion = nil
            do {
                try speechService.startListening()
            } catch {
                errorMessage = "Mikrofon başlatılamadı"
            }
        }
    }

    private func sendToGroq() {
        let newText = speechService.transcript
        if fullTranscript.isEmpty {
            fullTranscript = newText
        } else {
            fullTranscript += " " + newText
        }

        isAnalyzing = true
        errorMessage = nil

        Task {
            do {
                let response = try await groqService.parseMeals(transcript: fullTranscript)
                parsedMeals = response.meals
                if response.clarification_needed {
                    clarificationQuestion = response.clarification_question
                } else {
                    clarificationQuestion = nil
                    saveEntries(from: response.meals)
                }
            } catch {
                errorMessage = "Bir hata oluştu, tekrar deneyin"
            }
            isAnalyzing = false
        }
    }

    private func saveEntries(from meals: [ParsedMeal]) {
        for meal in meals {
            let entry = FoodEntry(
                name: meal.name,
                amount: meal.amount,
                calories: Int(meal.calories),
                protein: meal.protein,
                carbs: meal.carbs,
                fat: meal.fat
            )
            modelContext.insert(entry)
        }
        showSavedConfirmation = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showSavedConfirmation = false
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: FoodEntry.self, inMemory: true)
}
