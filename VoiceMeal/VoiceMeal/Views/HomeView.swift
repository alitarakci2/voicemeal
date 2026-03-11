//
//  HomeView.swift
//  VoiceMeal
//

import SwiftUI

struct HomeView: View {
    @StateObject private var speechService = SpeechService()
    @State private var permissionGranted = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

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

            Text(speechService.isRecording ? "Dinliyorum..." : "Hazır")
                .font(.headline)
                .foregroundStyle(speechService.isRecording ? .red : .secondary)

            if !speechService.transcript.isEmpty {
                Text(speechService.transcript)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer()
        }
        .padding()
        .task {
            permissionGranted = await speechService.requestPermissions()
        }
    }

    private func handleMicTap() {
        if speechService.isRecording {
            speechService.stopListening()
        } else {
            guard permissionGranted else { return }
            do {
                try speechService.startListening()
            } catch {
                print("Failed to start listening: \(error)")
            }
        }
    }
}

#Preview {
    HomeView()
}
