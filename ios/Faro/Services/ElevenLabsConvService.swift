import Foundation
import AVFoundation
import Darwin

// MARK: - Guided form → synthetic transcript (Mert’s UI/UX flow)

/// Helpers for conversational intake. `signedUrl` from `/conv/start` can power a live WebSocket client;
/// the guided questionnaire also submits a structured transcript compatible with the backend extractor.
enum ElevenLabsConvService {
    /// Builds transcript turns from the same fields as the guided form so `/conv/complete` can run the pipeline.
    static func transcript(from intake: IntakeRequest) -> [ConvTranscriptTurn] {
        let revenue = Int(intake.annualRevenue.rounded())
        let userLine = """
        My business is called \(intake.businessName). \(intake.description) \
        We have \(intake.employeeCount) employees, we operate in \(intake.state), \
        and our annual revenue is about \(revenue) dollars.
        """
        return [
            ConvTranscriptTurn(role: "user", message: userLine),
            ConvTranscriptTurn(
                role: "assistant",
                message: "Thank you. I have enough detail to run your coverage analysis."
            ),
        ]
    }
}

// MARK: - Live WebSocket (ElevenLabs Conversational AI — protocol aligned with official Python SDK)

/// Bidirectional audio + events for ElevenLabs Conversational AI WebSocket.
@MainActor
final class ElevenLabsLiveConversationService: NSObject, ObservableObject, URLSessionWebSocketDelegate {

    enum ConnectionState: Equatable {
        case disconnected, connecting, connected, error(String)
    }

    @Published var state: ConnectionState = .disconnected
    @Published var transcript: [ConvTranscriptTurn] = []
    @Published var isAgentSpeaking: Bool = false
    @Published var isUserSpeaking: Bool = false
    @Published var userSpeechLevel: Double = 0
    private nonisolated(unsafe) var _agentSpeaking = false
    private nonisolated(unsafe) var _pendingBuffers: Int32 = 0

    private nonisolated(unsafe) var webSocketTask: URLSessionWebSocketTask?
    private nonisolated(unsafe) var urlSession: URLSession?        // strong ref — prevents ARC dealloc killing the socket
    private nonisolated(unsafe) var connectionContinuation: CheckedContinuation<Void, Error>?
    private nonisolated(unsafe) var micConverter: AVAudioConverter?
    private nonisolated(unsafe) var uplinkPCMFormat: AVAudioFormat?
    private nonisolated(unsafe) var playbackPCMFormat: AVAudioFormat?
    private nonisolated(unsafe) var lastInterruptEventId: Int = 0
    private nonisolated(unsafe) var captureStarted = false
    private nonisolated(unsafe) var tapInstalled = false

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    private static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    override init() {
        // Default to 16 kHz Int16 PCM immediately so the agent's first-message audio
        // (which can arrive before conversation_initiation_metadata is processed) is never dropped.
        playbackPCMFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: true
        )
        super.init()
        audioEngine.attach(playerNode)
        if let fmt = playbackPCMFormat {
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: fmt)
        }
    }

    func connect(signedUrl: String) async throws {
        state = .connecting
        transcript.removeAll()
        resetSessionAudioState()

        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try audioSession.setActive(true)
        #endif

        guard let url = URL(string: signedUrl) else {
            state = .error("Invalid URL")
            throw URLError(.badURL)
        }

        // Keep a strong reference to the session — URLSessionWebSocketTask does not
        // reliably retain its parent session on all iOS versions, so a local variable
        // would get ARC-deallocated after connect() returns, killing the socket.
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        urlSession = session
        webSocketTask = session.webSocketTask(with: url)

        // Suspend until didOpenWithProtocol fires (real TCP+TLS+HTTP-upgrade success).
        // This prevents the race where send() buffers optimistically but receive() then
        // fails because the handshake hasn't completed yet.
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connectionContinuation = cont
            webSocketTask?.resume()
        }

        // Start the receive loop first so we never miss the server's metadata response,
        // then send the initiation message that kicks off the conversation.
        listenForMessages()
        try await sendConversationInitiationClientData()

        state = .connected

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            self.ensureCaptureStarted()
        }
    }

    /// Tears down the audio engine and WebSocket without touching `state`.
    /// Call this from any terminal state handler, then set `state` explicitly.
    private func cleanupAudioAndSocket() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil

        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        if audioEngine.isRunning { audioEngine.stop() }
        playerNode.stop()

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif

        micConverter = nil
        resetSessionAudioState()
    }

    func disconnect() {
        cleanupAudioAndSocket()
        state = .disconnected
    }

    private func sendConversationInitiationClientData() async throws {
        // Only the "type" field is required per the ElevenLabs WebSocket API spec.
        // Sending empty dicts for optional fields (custom_llm_extra_body, etc.)
        // causes the server to close the connection with 1008 "Invalid message received".
        let json = "{\"type\":\"conversation_initiation_client_data\"}"
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            webSocketTask?.send(.string(json)) { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }
    }

    private nonisolated func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let jsonString) = message {
                    self.handleWebSocketMessage(jsonString)
                }
                self.listenForMessages()
            case .failure(let error):
                Task { @MainActor in
                    // Clean up resources but preserve .error state so the user sees the message.
                    // (Calling disconnect() here would immediately overwrite .error with .disconnected.)
                    self.cleanupAudioAndSocket()
                    self.state = .error("WebSocket error: \(error.localizedDescription)")
                }
            }
        }
    }

    private nonisolated func handleWebSocketMessage(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else { return }

        switch type {
        case "conversation_initiation_metadata":
            if let ev = obj["conversation_initiation_metadata_event"] as? [String: Any] {
                let rate = ElevenLabsLiveConversationService.parsePCMSampleRate(ev["agent_output_audio_format"] as? String) ?? 16_000
                Task { @MainActor in
                    self.applyAgentOutputSampleRate(rate)
                    self.ensureCaptureStarted()
                }
            }

        case "ping":
            if let ev = obj["ping_event"] as? [String: Any], let eid = ev["event_id"] {
                sendPong(eventId: eid)
            }

        case "audio":
            guard let audioEvent = obj["audio_event"] as? [String: Any],
                  let b64 = audioEvent["audio_base_64"] as? String,
                  let raw = Data(base64Encoded: b64) else { return }
            let eid = audioEvent["event_id"]
            let eventId = eid.flatMap { Int("\($0)") } ?? 0
            if eventId <= lastInterruptEventId { return }
            self._agentSpeaking = true
            OSAtomicIncrement32(&self._pendingBuffers)
            Task { @MainActor in
                self.isAgentSpeaking = true
                self.playIncomingAudio(data: raw)
            }

        case "agent_response":
            guard let ev = obj["agent_response_event"] as? [String: Any],
                  let text = (ev["agent_response"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else { return }
            self._agentSpeaking = true
            Task { @MainActor in
                self.isAgentSpeaking = true
                // ElevenLabs sends incremental agent_response events (one per phrase).
                // Consolidate into a single transcript entry per agent turn.
                if let lastIdx = self.transcript.indices.last,
                   self.transcript[lastIdx].role == "agent" {
                    self.transcript[lastIdx] = ConvTranscriptTurn(
                        role: "agent",
                        message: self.transcript[lastIdx].message + " " + text
                    )
                } else {
                    self.transcript.append(ConvTranscriptTurn(role: "agent", message: text))
                }
            }

        case "user_transcript":
            guard let ev = obj["user_transcription_event"] as? [String: Any],
                  let text = (ev["user_transcript"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else { return }
            self._agentSpeaking = false
            Task { @MainActor in
                self.isAgentSpeaking = false
                self.isUserSpeaking = false
                self.userSpeechLevel = 0
                self.transcript.append(ConvTranscriptTurn(role: "user", message: text))
            }

        case "agent_response_correction":
            guard let ev = obj["agent_response_correction_event"] as? [String: Any],
                  let corrected = (ev["corrected_agent_response"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            Task { @MainActor in
                if let idx = self.transcript.lastIndex(where: { $0.role == "agent" }) {
                    self.transcript[idx] = ConvTranscriptTurn(role: "agent", message: corrected)
                }
            }

        case "interruption":
            if let ev = obj["interruption_event"] as? [String: Any],
               let eid = ev["event_id"],
               let n = Int("\(eid)") {
                lastInterruptEventId = n
            }
            self._agentSpeaking = false
            self._pendingBuffers = 0
            Task { @MainActor in
                self.isAgentSpeaking = false
                self.isUserSpeaking = false
                self.userSpeechLevel = 0
                self.playerNode.stop()
                self.playerNode.play()
            }

        default:
            break
        }
    }

    private nonisolated func sendPong(eventId: Any) {
        let payload: [String: Any] = ["type": "pong", "event_id": eventId]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(json)) { _ in }
    }

    private nonisolated static func parsePCMSampleRate(_ format: String?) -> Double? {
        guard let format else { return nil }
        if format.hasPrefix("pcm_"), let hz = Double(format.dropFirst(4)) {
            return hz
        }
        return nil
    }

    @MainActor
    private func applyAgentOutputSampleRate(_ sampleRate: Double) {
        guard sampleRate > 0 else { return }
        guard let fmt = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        ) else { return }
        playbackPCMFormat = fmt
        let wasRunning = audioEngine.isRunning
        if wasRunning {
            audioEngine.stop()
        }
        reconnectPlayerToMixer(format: fmt)
        if wasRunning {
            try? audioEngine.start()
            playerNode.play()
        }
    }

    @MainActor
    private func reconnectPlayerToMixer(format: AVAudioFormat) {
        audioEngine.disconnectNodeInput(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
    }

    @MainActor
    private func ensureCaptureStarted() {
        guard captureStarted == false else { return }
        captureStarted = true

        if playbackPCMFormat == nil {
            playbackPCMFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: 16_000,
                channels: 1,
                interleaved: true
            )
        }
        if let fmt = playbackPCMFormat {
            reconnectPlayerToMixer(format: fmt)
        }

        let inputNode = audioEngine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)

        guard let uplink = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: true
        ) else { return }

        uplinkPCMFormat = uplink
        guard let converter = AVAudioConverter(from: hwFormat, to: uplink) else { return }
        micConverter = converter

        if tapInstalled == false {
            tapInstalled = true
            inputNode.installTap(onBus: 0, bufferSize: 4_096, format: hwFormat) { [weak self] buffer, _ in
                self?.processMicInput(buffer: buffer)
            }
        }

        do {
            try audioEngine.start()
            playerNode.play()
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    @MainActor
    private func resetSessionAudioState() {
        lastInterruptEventId = 0
        captureStarted = false
        micConverter = nil
        uplinkPCMFormat = nil
        playbackPCMFormat = nil
        isAgentSpeaking = false
        isUserSpeaking = false
        userSpeechLevel = 0
    }

    private nonisolated func processMicInput(buffer: AVAudioPCMBuffer) {
        // Suppress echo: don't send mic audio while the agent is speaking.
        // The speaker output bleeds into the mic and ElevenLabs interprets it
        // as user speech, causing the agent to interrupt itself.
        if _agentSpeaking {
            Task { @MainActor in
                self.isUserSpeaking = false
                self.userSpeechLevel = 0
            }
            return
        }

        guard let converter = micConverter,
              let outFormat = uplinkPCMFormat,
              let task = webSocketTask else { return }

        let speechLevel = Self.normalizedSpeechLevel(from: buffer)
        Task { @MainActor in
            self.updateUserSpeechActivity(level: speechLevel)
        }

        let ratio = outFormat.sampleRate / buffer.format.sampleRate
        let outCapacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio)) + 32
        guard let outBuf = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: outCapacity) else { return }

        final class InputBox: @unchecked Sendable {
            var pcm: AVAudioPCMBuffer?
            init(_ pcm: AVAudioPCMBuffer) { self.pcm = pcm }
        }
        let box = InputBox(buffer)
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            guard let b = box.pcm else {
                outStatus.pointee = .noDataNow
                return nil
            }
            box.pcm = nil
            outStatus.pointee = .haveData
            return b
        }

        var err: NSError?
        let status = converter.convert(to: outBuf, error: &err, withInputFrom: inputBlock)
        guard err == nil, status != .error, outBuf.frameLength > 0 else { return }

        guard let ch0 = outBuf.int16ChannelData else { return }
        let byteCount = Int(outBuf.frameLength) * MemoryLayout<Int16>.size
        let pcm = Data(bytes: ch0[0], count: byteCount)
        let base64 = pcm.base64EncodedString()
        let chunk = "{\"user_audio_chunk\":\"\(base64)\"}"

        task.send(.string(chunk)) { _ in }
    }

    @MainActor
    private func updateUserSpeechActivity(level: Double) {
        let normalized = min(max(level, 0), 1)
        let smoothed = max(normalized, userSpeechLevel * 0.68)
        userSpeechLevel = smoothed < 0.02 ? 0 : smoothed
        isUserSpeaking = userSpeechLevel > 0.08
    }

    private nonisolated static func normalizedSpeechLevel(from buffer: AVAudioPCMBuffer) -> Double {
        let sampleCount = Int(buffer.frameLength)
        guard sampleCount > 0 else { return 0 }

        if let channelData = buffer.floatChannelData {
            let samples = UnsafeBufferPointer(start: channelData[0], count: sampleCount)
            var energy = 0.0
            for sample in samples {
                let value = Double(sample)
                energy += value * value
            }
            let rms = sqrt(energy / Double(sampleCount))
            return min(max(rms * 10.0, 0), 1)
        }

        if let channelData = buffer.int16ChannelData {
            let samples = UnsafeBufferPointer(start: channelData[0], count: sampleCount)
            var energy = 0.0
            for sample in samples {
                let value = Double(sample) / Double(Int16.max)
                energy += value * value
            }
            let rms = sqrt(energy / Double(sampleCount))
            return min(max(rms * 10.0, 0), 1)
        }

        return 0
    }

    private func playIncomingAudio(data: Data) {
        guard let format = playbackPCMFormat else { return }
        let bytesPerFrame = Int(format.streamDescription.pointee.mBytesPerFrame)
        guard bytesPerFrame > 0, data.count % bytesPerFrame == 0 else { return }
        let frameCount = UInt32(data.count / bytesPerFrame)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress,
                  let dst = buffer.int16ChannelData else { return }
            memcpy(dst[0], base, data.count)
        }

        playerNode.scheduleBuffer(buffer) { [weak self] in
            guard let self else { return }
            let remaining = OSAtomicDecrement32(&self._pendingBuffers)
            if remaining <= 0 {
                self._agentSpeaking = false
                Task { @MainActor in self.isAgentSpeaking = false }
            }
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    /// Fires once the TCP+TLS+HTTP-upgrade handshake completes successfully.
    /// This is the real "connected" signal — we resume the connection continuation here.
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Task { @MainActor in
            connectionContinuation?.resume()
            connectionContinuation = nil
        }
    }

    /// Captures explicit close codes/reasons sent by ElevenLabs so the error is human-readable.
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "none"
        let msg = "Server closed connection (code \(closeCode.rawValue), reason: \(reasonStr))"
        Task { @MainActor in
            // If we're still waiting for the handshake, fail the connection continuation.
            if connectionContinuation != nil {
                connectionContinuation?.resume(throwing: URLError(.cannotConnectToHost,
                    userInfo: [NSLocalizedDescriptionKey: msg]))
                connectionContinuation = nil
                return
            }
            switch self.state {
            case .connected, .connecting:
                self.cleanupAudioAndSocket()
                self.state = .error(msg)
            default:
                break
            }
        }
    }

    /// Catches transport-level failures (DNS, TLS, network unreachable, etc.).
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        Task { @MainActor in
            if connectionContinuation != nil {
                connectionContinuation?.resume(throwing: error)
                connectionContinuation = nil
                return
            }
            switch self.state {
            case .connected, .connecting:
                self.cleanupAudioAndSocket()
                self.state = .error("Transport error: \(error.localizedDescription)")
            default:
                break
            }
        }
    }
}
