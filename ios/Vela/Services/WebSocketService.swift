import Foundation

@MainActor
final class WebSocketService: NSObject, ObservableObject {
    @Published var stepUpdates: [StepUpdate] = []
    @Published var isConnected = false

    private var task: URLSessionWebSocketTask?
    private let sessionId: String
    private let baseURL: String

    init(sessionId: String, baseURL: String = "ws://localhost:8000") {
        self.sessionId = sessionId
        self.baseURL = baseURL
    }

    func connect() {
        let url = URL(string: "\(baseURL)/ws/\(sessionId)")!
        task = URLSession.shared.webSocketTask(with: url)
        task?.resume()
        isConnected = true
        receiveNext()
    }

    func disconnect() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        isConnected = false
    }

    private func receiveNext() {
        task?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let message):
                    if case .string(let text) = message, let data = text.data(using: .utf8) {
                        if let update = try? JSONDecoder().decode(StepUpdate.self, from: data) {
                            self.apply(update)
                        }
                    }
                    self.receiveNext()
                case .failure:
                    self.isConnected = false
                }
            }
        }
    }

    private func apply(_ update: StepUpdate) {
        if let idx = stepUpdates.firstIndex(where: { $0.step == update.step }) {
            stepUpdates[idx] = update
        } else {
            stepUpdates.append(update)
        }
    }
}
