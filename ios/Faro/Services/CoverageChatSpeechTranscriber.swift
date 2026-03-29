import AVFoundation
import Combine
import Foundation
import Speech

/// Live dictation for the coverage follow-up composer using on-device speech recognition.
final class CoverageChatSpeechTranscriber: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var partialTranscript = ""
    @Published private(set) var lastError: String?

    func clearError() {
        DispatchQueue.main.async { self.lastError = nil }
    }

    func noteError(_ message: String) {
        DispatchQueue.main.async { self.lastError = message }
    }

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    override init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Locale.preferredLanguages.first ?? "en_US"))
        super.init()
    }

    /// Returns whether speech recognition is authorized (and requests if needed).
    func ensureSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Returns whether microphone access is granted (and requests if needed).
    func ensureMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                continuation.resume(returning: true)
            case .denied:
                continuation.resume(returning: false)
            case .undetermined:
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            @unknown default:
                continuation.resume(returning: false)
            }
        }
    }

    func start() async throws {
        await MainActor.run {
            self.lastError = nil
            self.partialTranscript = ""
        }

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw NSError(
                domain: "CoverageChatSpeech",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognition isn’t available right now."]
            )
        }

        let speechOK = await ensureSpeechAuthorization()
        guard speechOK else {
            throw NSError(
                domain: "CoverageChatSpeech",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognition permission is required for voice input."]
            )
        }

        let micOK = await ensureMicrophoneAccess()
        guard micOK else {
            throw NSError(
                domain: "CoverageChatSpeech",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Microphone access is required for voice input."]
            )
        }

        cancelRecognitionSession()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw NSError(domain: "CoverageChatSpeech", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not create speech request."])
        }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.partialTranscript = text
                }
            }
            if error != nil {
                DispatchQueue.main.async {
                    self.lastError = error?.localizedDescription
                }
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            cancelRecognitionSession()
            throw error
        }

        DispatchQueue.main.async {
            self.isRecording = true
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        DispatchQueue.main.async {
            self.isRecording = false
        }
    }

    func cancelRecognitionSession() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRecording = false
    }

    deinit {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
