import Combine
import Foundation

public enum CatActionType: String, Codable {
    case hangOnIsland = "hang_on_island"
    case wash = "wash"
    case somersault = "somersault"
    case play = "play"
    case dressUp = "dress_up"
    case takeOff = "take_off"
    case sleep = "sleep"
    case wake = "wake"
    case idle = "idle"
}

public struct CatActionState: Codable, Equatable {
    public var currentAction: CatActionType
    public var isDressed: Bool
    public var currentOutfit: String?
    public var isHanging: Bool
    public var moodEmoji: String
    public var statusText: String
    public var executionToken: String
    
    public static let `default` = CatActionState(
        currentAction: .idle,
        isDressed: false,
        currentOutfit: nil,
        isHanging: false,
        moodEmoji: "😼",
        statusText: "Наблюдаю за тобой",
        executionToken: UUID().uuidString
    )
}

@MainActor
public final class CatActionHandler: ObservableObject {
    public static let shared = CatActionHandler()
    
    @Published public var state: CatActionState = .default {
        didSet {
            if oldValue.isDressed != state.isDressed || oldValue.currentOutfit != state.currentOutfit {
                UserDefaults.standard.set(state.isDressed, forKey: "aicat.dressed")
                UserDefaults.standard.set(state.currentOutfit, forKey: "aicat.outfit")
                var snapshot = CatSnapshot.load().projected(at: Date())
                snapshot.outfit = state.isDressed ? state.currentOutfit : nil
                snapshot.save()
            }
        }
    }

    private init() {
        if UserDefaults.standard.object(forKey: "aicat.dressed") != nil {
            var restored = CatActionState.default
            restored.isDressed = UserDefaults.standard.bool(forKey: "aicat.dressed")
            restored.currentOutfit = UserDefaults.standard.string(forKey: "aicat.outfit")
            state = restored
        }
    }
    
    public func execute(action: String, item: String? = nil) -> String {
        switch action {
        case "play": return TamagotchiManager.shared.play()
        case "feed": return TamagotchiManager.shared.feedFish()
        case "pet": return TamagotchiManager.shared.petCat()
        case "sleep": return TamagotchiManager.shared.sleep()
        case "wake": return TamagotchiManager.shared.wake()
        default: break
        }
        guard let actionType = CatActionType(rawValue: action) else {
            return "Кот с недоумением посмотрел на тебя: 'Такую команду я пока не выучил'."
        }
        
        let token = UUID().uuidString
        
        // Если это не повисание — сбрасываем флаг повисания
        if actionType != .hangOnIsland {
            state.isHanging = false
        }
        
        var response = ""
        
        switch actionType {
        case .hangOnIsland:
            state.currentAction = .hangOnIsland
            state.isHanging = true
            state.moodEmoji = "🐾"
            state.statusText = "Повис на Dynamic Island!"
            state.executionToken = token
            response = "Ухватился когтями за верхний край! Вишу, любуюсь твоими обоями."
            
        case .wash:
            state.currentAction = .wash
            state.moodEmoji = "👅"
            state.statusText = "Умывается лапкой"
            state.executionToken = token
            response = "*Вылизывает переднюю лапку и аккуратно протирает ушко*. Чистота — залог идеального ИИ."
            
        case .somersault:
            state.currentAction = .somersault
            state.moodEmoji = "🤸‍♂️"
            state.statusText = "Крутит сальто назад"
            state.executionToken = token
            response = "*Сделал грациозное сальто назад и приземлился на все четыре лапы*. Десять из десяти!"
            
        case .play:
            state.currentAction = .play
            state.moodEmoji = "🧶"
            state.statusText = "Играет с лазером"
            state.executionToken = token
            response = "*Поймал виртуальный лазерный луч лапой*. Ладно, признаю, это было весело!"
            
        case .dressUp:
            let outfit = item ?? "Стильный черный худи и темные очки"
            state.isDressed = true
            state.currentOutfit = outfit
            state.currentAction = .dressUp
            state.moodEmoji = "🕶️"
            state.statusText = "Одет: \(outfit)"
            state.executionToken = token
            response = "Приоделся! \(outfit) сидит идеально. Самый стильный агент в твоем телефоне."
            
        case .takeOff:
            state.isDressed = false
            state.currentOutfit = nil
            state.currentAction = .takeOff
            state.moodEmoji = "😸"
            state.statusText = "Натуральная шерсть"
            state.executionToken = token
            response = "Скинул гардероб, остался в естественной шубке. Так дышится свободнее."
            
        case .sleep:
            state.currentAction = .sleep
            state.moodEmoji = "💤"
            state.statusText = "Спит и мурчит"
            state.executionToken = token
            response = "*Свернулся калачиком и сладко посапывает*. Мур-мяу..."
            
        case .wake:
            state.currentAction = .idle
            state.moodEmoji = "😼"
            state.statusText = "Бодр и готов к делам"
            state.executionToken = token
            response = "*Потянулся, зевнул и поправил очки*. Я на связи, кожаный. Что делаем?"
            
        case .idle:
            state.currentAction = .idle
            state.executionToken = token
            response = "Мяу! Жду твоих команд."
        }
        
        // Синхронизируем состояние с Dynamic Island
        LiveActivityManager.shared.update(status: state.statusText, mood: state.moodEmoji, action: state.statusText)
        
        return response
    }
    
    // Интерактивное поглаживание кота по тапу
    public func pet() -> String {
        return TamagotchiManager.shared.petCat()
    }
}
