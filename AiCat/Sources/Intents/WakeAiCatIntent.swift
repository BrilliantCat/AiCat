import AppIntents
import Foundation

// Intent для Back Tap (Тройное касание задней панели)
public struct WakeAiCatVoiceIntent: AppIntent {
    public static var title: LocalizedStringResource = "Разбудить AiCat и слушать голос"
    public static var description = IntentDescription("Активирует AiCat и запускает офлайн распознавание речи")
    
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult {
        // Уведомляем систему и активируем кота в Dynamic Island
        NotificationCenter.default.post(name: NSNotification.Name("WakeAiCatTriggered"), object: nil)
        return .result()
    }
}

// Intent для команды "Повисни на лапках" из шорткатов или кнопок
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
