import AppIntents

enum CatCare: String, AppEnum {
    case feed, pet, play

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Уход за котом"
    static var caseDisplayRepresentations: [CatCare: DisplayRepresentation] = [
        .feed: "Покормить", .pet: "Погладить", .play: "Поиграть"
    ]
}

// LiveActivityIntent also runs widget button actions in the application process.
// The room, widgets and Island therefore share one writer for the pet's state.
struct CareForCatIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Позаботиться о коте"
    static var openAppWhenRun = false
    @Parameter(title: "Действие") var care: CatCare

    init() {}
    init(_ care: CatCare) { self.care = care }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !AICAT_WIDGET
        _ = TamagotchiManager.shared.care(care)
        await LiveActivityManager.shared.finishPendingUpdate()
        #endif
        return .result()
    }
}
