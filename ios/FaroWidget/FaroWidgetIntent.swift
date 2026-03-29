import AppIntents

/// User-configurable tap target for the Faro home screen widget.
enum FaroWidgetTapDestination: String, AppEnum {
    case matchSnapshot
    case analyze
    case coverage
    case submission

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Open destination"

    static var caseDisplayRepresentations: [FaroWidgetTapDestination: DisplayRepresentation] = [
        .matchSnapshot: "Match snapshot",
        .analyze: "Profile / Analyze",
        .coverage: "Coverage",
        .submission: "Submission"
    ]
}

struct FaroWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Faro Coverage"
    static var description = IntentDescription("Choose where the widget opens when tapped. Match snapshot uses your latest analysis recommendation.")

    @Parameter(title: "When tapped, open")
    var tapDestination: FaroWidgetTapDestination?

    init() {
        self.tapDestination = .matchSnapshot
    }
}
