import Foundation
import UIKit

public final class TamagotchiManager: ObservableObject {
    public static let shared = TamagotchiManager()
    
    @Published public var satiety: Int = 85    // Сытость 0-100%
    @Published public var happiness: Int = 90  // Счастье 0-100%
    @Published public var energy: Int = 95     // Энергия 0-100%
    
    private init() {}
    
    // Покормить кота рыбкой 🐟
    public func feedFish() -> String {
        satiety = min(100, satiety + 25)
        happiness = min(100, happiness + 15)
        
        // Тактильный отклик (хруст рыбки)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        CatActionHandler.shared.state.moodEmoji = "🐟"
        CatActionHandler.shared.state.statusText = "Хрустит свежей рыбкой"
        
        return "*Хрум-хрум-хрум*. М-м-м, свежий тунец! Сытость \(satiety)%. Вот теперь я готов сворачивать горы, кожаный!"
    }
    
    // Погладить кота (мурчание)
    public func petCat() -> String {
        happiness = min(100, happiness + 20)
        
        // Вибрация мурчания через Taptic Engine
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        CatActionHandler.shared.state.moodEmoji = "😻"
        CatActionHandler.shared.state.statusText = "Уютно мурчит от поглаживаний"
        
        return "*М-у-у-у-р-р-р-р-р-р*. Ладно, признаю, это было приятно. Счастье кота: \(happiness)%!"
    }
    
    // Уложить спать
    public func sleep() -> String {
        energy = min(100, energy + 40)
        CatActionHandler.shared.state.moodEmoji = "💤"
        CatActionHandler.shared.state.statusText = "Спит и восстанавливает энергию"
        return "*Свернулся клубком*. Восстанавливаю тактовую частоту нейросети... z-z-z."
    }
    
    // Влияние сытости на характер ответов в промпте
    public var moodContextPrompt: String {
        if satiety < 40 {
            return "ВНИМАНИЕ: Кот сейчас очень голодный (сытость \(satiety)%). Он немного ворчит и требует рыбку 🐟."
        } else if happiness > 85 {
            return "Кот очень доволен и сыт (сытость \(satiety)%, счастье \(happiness)%). Он в прекрасном расположении духа и готов шутить."
        } else {
            return "Кот в спокойном рабочем состоянии."
        }
    }
}
