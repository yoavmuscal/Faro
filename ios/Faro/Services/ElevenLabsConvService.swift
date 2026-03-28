import Foundation

/// Helpers for conversational intake. A future WebRTC client can use `signedUrl` from `/conv/start`
/// to stream audio; until then the app submits a structured transcript compatible with the backend extractor.
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
