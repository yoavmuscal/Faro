import SwiftUI

/// Entry point for the Analyze tab: structured form vs voice-backed conversational flow.
struct IntakeChoiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FaroSpacing.lg) {
                Text("How would you like to start?")
                    .font(FaroType.title2())
                    .foregroundStyle(FaroPalette.ink)

                Text("Share a few details about your business so we can map coverage, premiums, and submission-ready documents.")
                    .font(FaroType.subheadline())
                    .foregroundStyle(FaroPalette.ink.opacity(0.55))

                VStack(spacing: FaroSpacing.md) {
                    NavigationLink {
                        OnboardingView()
                    } label: {
                        choiceRow(
                            title: "Guided questionnaire",
                            subtitle: "Step-by-step — best when you want to type at your own pace.",
                            systemImage: "list.bullet.rectangle"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        VoiceIntakeView()
                    } label: {
                        choiceRow(
                            title: "Conversational intake",
                            subtitle: "Same information through the voice pipeline when your server supports it.",
                            systemImage: "waveform"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, FaroSpacing.sm)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FaroSpacing.md)
        }
        .faroCanvasBackground()
        .navigationTitle("Analyze")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func choiceRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: FaroSpacing.md) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(FaroPalette.purpleDeep)
                .frame(width: 36, alignment: .center)

            VStack(alignment: .leading, spacing: FaroSpacing.xs) {
                Text(title)
                    .font(FaroType.headline())
                    .foregroundStyle(FaroPalette.ink)
                Text(subtitle)
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FaroPalette.ink.opacity(0.35))
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.md, material: .thinMaterial)
    }
}

#Preview {
    NavigationStack {
        IntakeChoiceView()
    }
    .environmentObject(FaroAppState())
}
