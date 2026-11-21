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
        isDressed: true,
        currentOutfit: "Черные кибер-очки",
        isHanging: false,
        moodEmoji: "😼",
        statusText: "Наблюдаю за тобой из островка",
        executionToken: UUID().uuidString
    )
}

public final class CatActionHandler: ObservableObject {
    public static let shared = CatActionHandler()
    
    @Published public var state: CatActionState = .default
    
    private init() {}
    
    public func execute(action: String, item: String? = nil) -> String {
        guard let actionType = CatActionType(rawValue: action) else {
            return "Кот с недоумением посмотрел на тебя: 'Такую команду я пока не выучил'."
        }
        
        let token = UUID().uuidString
        
        switch actionType {
        case .hangOnIsland:
            state.currentAction = .hangOnIsland
            state.isHanging = true
            state.moodEmoji = "🐾"
            state.statusText = "Повис на лапках под Dynamic Island!"
            state.executionToken = token
            return "Ухватился когтями за нижнюю грань островка. Вишу, любуюсь твоими обоями!"
            
        case .wash:
            state.currentAction = .wash
            state.moodEmoji = "👅"
            state.statusText = "Умывается лапкой"
            state.executionToken = token
            return "*Вылизывает переднюю лапку и аккуратно протирает ушко*. Чистота — залог идеального ИИ."
            
        case .somersault:
            state.currentAction = .somersault
            state.moodEmoji = "🤸‍♂️"
            state.statusText = "Крутит сальто в невесомости"
            state.executionToken = token
            return "*Сделал грациозное сальто назад и приземлился на все четыре лапы*. Десять из десяти!"
            
        case .play:
            state.currentAction = .play
            state.moodEmoji = "🧶"
            state.statusText = "Гоняет цифровой клубок"
            state.executionToken = token
            return "*Поймал виртуальный лазерный луч лапой*. Ладно, признаю, это было весело."
            
        case .dressUp:
            let outfit = item ?? "Стильный черный худи и темные очки"
            state.isDressed = true
            state.currentOutfit = outfit
            state.currentAction = .dressUp
            state.moodEmoji = "🕶️"
            state.statusText = "Одет с иголочки (\(outfit))"
            state.executionToken = token
            return "Приоделся! \(outfit) сидит идеально. Теперь я самый стильный агент в твоем телефоне."
            
        case .takeOff:
            state.isDressed = false
            state.currentOutfit = nil
            state.currentAction = .takeOff
            state.moodEmoji = "😸"
            state.statusText = "Натуральная шерсть"
            state.executionToken = token
            return "Скинул гардероб, остался в естественной шубке. Так дышится свободнее."
            
        case .sleep:
            state.currentAction = .sleep
            state.moodEmoji = "💤"
            state.statusText = "Спит и сладко посапывает"
            state.executionToken = token
            return "*Свернулся калачиком на Dynamic Island и тихо замурлыкал*. Разбуди меня стуком по экрану."
            
        case .wake:
            state.currentAction = .idle
            state.moodEmoji = "😼"
            state.statusText = "Бодр и готов к задачам"
            state.executionToken = token
            return "*Потянулся, зевнул и поправил очки*. Я на связи, кожаный. Что делаем?"
            
        case .idle:
            state.currentAction = .idle
            state.executionToken = token
            return "Мяу! Жду твоих команд."
        }
    }
}
