//
//  SpeechService.swift
//  VoiceMeal
//

import AVFoundation
import Combine
import Speech

class SpeechService: ObservableObject {
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var lastError: String?

    private nonisolated(unsafe) var audioEngine = AVAudioEngine()
    private nonisolated(unsafe) var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private nonisolated(unsafe) var recognitionTask: SFSpeechRecognitionTask?
    private nonisolated(unsafe) var speechRecognizer: SFSpeechRecognizer? = {
        let appLang = UserDefaults(suiteName: "group.indio.VoiceMeal")?
            .string(forKey: "appLanguage")
            ?? UserDefaults.standard.string(forKey: "appLanguage")

        if let lang = appLang {
            return SFSpeechRecognizer(locale: lang == "en"
                ? Locale(identifier: "en-US")
                : Locale(identifier: "tr-TR"))
        }

        let systemLang = UserDefaults.standard
            .stringArray(forKey: "AppleLanguages")?.first ?? "tr"
        return SFSpeechRecognizer(locale: systemLang.hasPrefix("en")
            ? Locale(identifier: "en-US")
            : Locale(identifier: "tr-TR"))
    }()

    func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            lastError = "Mikrofon izni gerekli. Ayarlardan izin verin."
            #if DEBUG
            print("❌ [SpeechService] Speech recognition not authorized: \(speechStatus.rawValue)")
            #endif
            return false
        }
        let micGranted = await AVAudioApplication.requestRecordPermission()
        if !micGranted {
            lastError = "Mikrofon izni gerekli. Ayarlardan izin verin."
            #if DEBUG
            print("❌ [SpeechService] Microphone permission denied")
            #endif
        }
        return micGranted
    }

    func startListening() throws {
        lastError = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        guard speechRecognizer?.isAvailable == true else {
            lastError = "Ses tanıma şu an kullanılamıyor."
            #if DEBUG
            print("❌ [SpeechService] Speech recognizer not available")
            #endif
            throw SpeechError.recognitionUnavailable
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            lastError = "Ses kaydı başlatılamadı."
            #if DEBUG
            print("❌ [SpeechService] Audio session error: \(error)")
            #endif
            throw error
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        transcript = ""

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if let error {
                    let nsError = error as NSError
                    #if DEBUG
                    print("❌ [SpeechService] Recognition error: \(nsError.domain) \(nsError.code) - \(error.localizedDescription)")
                    #endif
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                        self.lastError = "Ses algılanamadı. Tekrar deneyin."
                    } else if nsError.domain == NSURLErrorDomain {
                        self.lastError = "İnternet bağlantısı gerekli."
                    } else {
                        self.lastError = "Ses tanıma hatası: \(error.localizedDescription)"
                    }
                    self.stopListening()
                } else if result?.isFinal ?? false {
                    self.stopListening()
                }
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
    }
}

enum SpeechError: LocalizedError {
    case recognitionUnavailable

    var errorDescription: String? {
        switch self {
        case .recognitionUnavailable: "Ses tanıma şu an kullanılamıyor."
        }
    }
}
