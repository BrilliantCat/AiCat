import AppIntents
import Foundation

// Intent для Back Tap (Тройное касание задней панели iPhone)
public struct WakeAiCatVoiceIntent: AppIntent {
    public static var title: LocalizedStringResource = "AiCat: Голос"
    public static var description = IntentDescription("Активирует AiCat и мгновенно запускает голосовой ввод")
    
    public static var openAppWhenRun: Bool = true
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "startListeningOnLaunch")
        NotificationCenter.default.post(name: NSNotification.Name("WakeAiCatTriggered"), object: nil)
        return .result()
    }
}

// Intent для кнопок в Dynamic Island (LiveActivityIntent)
public struct PetCatLiveIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Погладить кота"
    public static var description = IntentDescription("Погладить котика AiCat на Dynamic Island")
    
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult {
        _ = TamagotchiManager.shared.petCat()
        _ = CatActionHandler.shared.pet()
        return .result()
    }
}

// Shortcut Provider для автоматического появления в Командах и Back Tap
public struct AiCatShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WakeAiCatVoiceIntent(),
            phrases: [
                "Голос \(.applicationName)",
                "Разбуди \(.applicationName)"
            ],
            shortTitle: "AiCat: Голос",
            systemImageName: "mic.fill"
        )
    }
}
