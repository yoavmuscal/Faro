import Foundation

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

    // MARK: - GET /results/{session_id}

    func fetchResults(sessionId: String) async throws -> ResultsResponse {
        let url = URL(string: "\(baseURL)/results/\(sessionId)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response)
        return try decoder.decode(ResultsResponse.self, from: data)
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
}
