import ActivityKit
import Foundation

public struct AiCatAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var statusMessage: String
        public var quoteDay: Int? = nil
        public var outfit: String? = nil
        public var moodEmoji: String
        public var currentAction: String
        public var isHanging: Bool
        public var isListening: Bool
        
        public init(statusMessage: String, moodEmoji: String, currentAction: String, isHanging: Bool, isListening: Bool) {
            self.statusMessage = statusMessage
            self.moodEmoji = moodEmoji
            self.currentAction = currentAction
            self.isHanging = isHanging
            self.isListening = isListening
        }
    }
    
    public var catName: String
    
    public init(catName: String = "AiCat") {
        self.catName = catName
    }
}

/// A civil-day index keeps a saying stable across app launches, including DST transitions.
enum DailySaying {
    typealias Saying = (text: String, source: String)
    static let sayings: [Saying] = [
        ("Путь в тысячу ли начинается под ногами.", "Лао-цзы · Дао дэ цзин, 64"),
        ("Глаза страшатся, а руки делают.", "Русская пословица"),
        ("Что преграждает путь, само становится путём.", "Марк Аврелий · Размышления, V.20"),
        ("Семь раз упади, восемь раз поднимись.", "Японская пословица"),
        ("Капля точит камень.", "Латинская пословица"),
        ("Утро вечера мудренее.", "Русская пословица"),
        ("Кто побеждает самого себя, тот силён.", "Лао-цзы · Дао дэ цзин, 33"),
        ("Даже дорога в тысячу ри начинается с одного шага.", "Корейская пословица"),
        ("Пока дышу — надеюсь.", "Латинское изречение"),
        ("Дело мастера боится.", "Русская пословица"),
        ("Дубы вырастают из маленьких желудей.", "Английская пословица"),
        ("Смелость города берёт.", "Русская пословица"),
        ("Хорошее начало — половина дела.", "Древнегреческая пословица"),
        ("Терпение и труд всё перетрут.", "Русская пословица")
    ]
    static func index(_ date: Date, zone: TimeZone = .current) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 1
        return (day - 1) % sayings.count
    }
    static func forDay(_ date: Date) -> Saying { sayings[index(date)] }
}
