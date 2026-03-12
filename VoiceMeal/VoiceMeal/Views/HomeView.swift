//
//  HomeView.swift
//  VoiceMeal
//

import SwiftUI

struct HomeView: View {
    @StateObject private var speechService = SpeechService()
    @State private var permissionGranted = false
    @State private var isAnalyzing = false
    @State private var parsedMeals: [ParsedMeal] = []
    @State private var clarificationQuestion: String?
    @State private var errorMessage: String?
    @State private var fullTranscript = ""

    private let groqService = GroqService()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

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

            // Results
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

            Spacer()
        }
        .padding()
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
                }
            } catch {
                errorMessage = "Bir hata oluştu, tekrar deneyin"
            }
            isAnalyzing = false
        }
    }
}

#Preview {
    HomeView()
}
