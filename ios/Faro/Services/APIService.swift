import Foundation

/// Thrown for API failures where we have a message for the user (e.g. HTTP 500 `detail`).
struct APIError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

actor APIService {
    static let shared = APIService()

    /// Override via Info.plist key `API_BASE_URL` for local dev vs prod.
    private let baseURL: String = APIConfig.httpBaseURL

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    // MARK: - POST /intake

    func submitIntake(_ intake: IntakeRequest) async throws -> IntakeResponse {
        var request = URLRequest(url: URL(string: "\(baseURL)/intake")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(intake)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try decoder.decode(IntakeResponse.self, from: data)
    }

    // MARK: - Conversational AI

    func startConversation() async throws -> ConvStartResponse {
        var request = URLRequest(url: URL(string: "\(baseURL)/conv/start")!)
        request.httpMethod = "POST"

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try decoder.decode(ConvStartResponse.self, from: data)
    }

    func completeConversation(sessionId: String, transcript: [ConvTranscriptTurn]) async throws -> ConvCompleteResponse {
        var request = URLRequest(url: URL(string: "\(baseURL)/conv/complete")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ConvCompleteRequest(sessionId: sessionId, transcript: transcript)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try decoder.decode(ConvCompleteResponse.self, from: data)
    }

    // MARK: - GET /results/{session_id}

    /// Polls while the server returns **202** (pipeline finished in the UI but DB not finalized yet).
    func fetchResults(sessionId: String) async throws -> ResultsResponse {
        let url = URL(string: "\(baseURL)/results/\(sessionId)")!
        let maxAttempts = 60
        let delayNs: UInt64 = 1_000_000_000 // 1s

        for attempt in 0..<maxAttempts {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            switch http.statusCode {
            case 200:
                do {
                    return try decoder.decode(ResultsResponse.self, from: data)
                } catch {
                    throw APIError(
                        message: "Could not read results from server. \(error.localizedDescription)"
                    )
                }
            case 202:
                // Race: WebSocket shows all steps complete before `pipeline_status` is saved.
                if attempt == maxAttempts - 1 {
                    throw APIError(
                        message: "Results are still finishing on the server. Pull to retry or try again in a few seconds."
                    )
                }
                try await Task.sleep(nanoseconds: delayNs)
            case 404:
                throw APIError(message: "Session not found. Start a new analysis.")
            case 500:
                throw APIError(message: Self.parseFastAPIDetail(data) ?? "Analysis failed on the server.")
            default:
                throw URLError(.badServerResponse)
            }
        }

        throw APIError(message: "Timed out waiting for results.")
    }

    // MARK: - GET /status/{session_id}

    func fetchStatus(sessionId: String) async throws -> StatusResponse {
        let url = URL(string: "\(baseURL)/status/\(sessionId)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response)
        return try decoder.decode(StatusResponse.self, from: data)
    }

    // MARK: - Helpers

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private static func parseFastAPIDetail(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let detail = obj["detail"] as? String { return detail }
        return nil
    }
}
