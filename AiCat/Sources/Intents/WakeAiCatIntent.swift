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

// Intent для команды "Повисни на лапках" из шорткатов
public struct HangCatIntent: AppIntent {
    public static var title: LocalizedStringResource = "AiCat: Повисни на лапках"
    public static var description = IntentDescription("Кот свешивается с Dynamic Island на лапках")
    
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult {
        _ = CatActionHandler.shared.execute(action: "hang_on_island")
        return .result()
    }
}
