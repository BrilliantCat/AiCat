import Foundation
import UIKit

@MainActor
public final class TamagotchiManager: ObservableObject {
    public static let shared = TamagotchiManager()
    
    @Published public var satiety: Int = 85    // Сытость 0-100%
    @Published public var happiness: Int = 90  // Счастье 0-100%
    @Published public var energy: Int = 95     // Энергия 0-100%
    @Published public var isSleeping: Bool = false
    
    private let defaults = UserDefaults.standard
    private let keySatiety = "aicat_tamagotchi_satiety"
    private let keyHappiness = "aicat_tamagotchi_happiness"
    private let keyEnergy = "aicat_tamagotchi_energy"
    private let keyIsSleeping = "aicat_tamagotchi_sleeping"
    private let keyLastUpdate = "aicat_tamagotchi_last_update"
    
    private init() {
        loadStateAndApplyDecay()
    }
    
    // Загрузка состояния и расчет естественного убывания параметров со временем (по Date)
    public func loadStateAndApplyDecay() {
        if defaults.object(forKey: keySatiety) != nil {
            satiety = defaults.integer(forKey: keySatiety)
            happiness = defaults.integer(forKey: keyHappiness)
            energy = defaults.integer(forKey: keyEnergy)
            isSleeping = defaults.bool(forKey: keyIsSleeping)
        }
        
        let lastDate = (defaults.object(forKey: keyLastUpdate) as? Date) ?? Date()
        let elapsedHours = Date().timeIntervalSince(lastDate) / 3600.0
        
        if elapsedHours > 0.05 {
            // Сытость убывает примерно на 4% в час
            let satietyDecay = Int(elapsedHours * 4.0)
            satiety = max(10, satiety - satietyDecay)
            
            // Счастье убывает на 3% в час без внимания
            let happinessDecay = Int(elapsedHours * 3.0)
            happiness = max(15, happiness - happinessDecay)
            
            // Если кот спал — энергия восстановилась, если бодрствовал — устал
            if isSleeping {
                let energyRecovery = Int(elapsedHours * 15.0)
                energy = min(100, energy + energyRecovery)
                if energy >= 95 { isSleeping = false }
            } else {
                let energyDecay = Int(elapsedHours * 4.0)
                energy = max(10, energy - energyDecay)
            }
        }
        
        saveState()
    }
    
    public func saveState() {
        defaults.set(satiety, forKey: keySatiety)
        defaults.set(happiness, forKey: keyHappiness)
        defaults.set(energy, forKey: keyEnergy)
        defaults.set(isSleeping, forKey: keyIsSleeping)
        defaults.set(Date(), forKey: keyLastUpdate)
    }
    
    // Покормить кота рыбкой 🐟
    public func feedFish() -> String {
        satiety = min(100, satiety + 30)
        happiness = min(100, happiness + 15)
        saveState()
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        CatActionHandler.shared.state.moodEmoji = "🐟"
        CatActionHandler.shared.state.statusText = "Хрустит тунцом (\(satiety)%)"
        LiveActivityManager.shared.update(status: "Сытость: \(satiety)%", mood: "🐟", action: "Ест рыбку")
        
        return "*Хрум-хрум-хрум*. М-м-м, свежий тунец! Сытость \(satiety)%. Вот теперь процессор A17 Pro мурчит на полную мощность, кожаный!"
    }
    
    // Погладить кота (ласка и мурчание)
    public func petCat() -> String {
        happiness = min(100, happiness + 20)
        saveState()
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        CatActionHandler.shared.state.moodEmoji = "😻"
        CatActionHandler.shared.state.statusText = "Мурчит от ласки (\(happiness)%)"
        LiveActivityManager.shared.update(status: "Счастье: \(happiness)%", mood: "😻", action: "Мурчит")
        
        return "*М-у-у-у-р-р-р-р-р-р*. Ладно, признаю, это было приятно. Счастье кота: \(happiness)%!"
    }
    
    // Уложить спать
    public func sleep() -> String {
        isSleeping = true
        saveState()
        
        CatActionHandler.shared.state.moodEmoji = "💤"
        CatActionHandler.shared.state.statusText = "Спит и восстанавливает энергию"
        LiveActivityManager.shared.update(status: "Спит...", mood: "💤", action: "Сон")
        
        return "*Свернулся клубком*. Восстанавливаю тактовую частоту нейросети... z-z-z."
    }
    
    // Разбудить
    public func wake() -> String {
        isSleeping = false
        energy = min(100, energy + 25)
        saveState()
        
        CatActionHandler.shared.state.moodEmoji = "😼"
        CatActionHandler.shared.state.statusText = "Бодр и готов к делам"
        LiveActivityManager.shared.update(status: "Бодр и готов", mood: "😼", action: "На связи")
        
        return "*Потянулся, зевнул и поправил черные очки*. Я проснулся, кожаный! Что за задачи на повестке?"
    }
    
    // Формирование системного контекста настроения кота для LLM-промпта
    public func moodContextPrompt() -> String {
        var status = "САМОЧУВСТВИЕ КОТА (ТАМАГОЧИ): Сытость: \(satiety)%, Счастье: \(happiness)%, Энергия: \(energy)%."
        if satiety < 35 {
            status += " Кот ОЧЕНЬ голоден! Он раздражен, саркастично намекает на миску с рыбой и ворчит."
        } else if happiness < 35 {
            status += " Кот чувствует себя одиноким и заброшенным. Жалуется на нехватку внимания и поглаживаний."
        } else if energy < 30 {
            status += " Кот сонный и усталый. Зевает, отвечает лениво и мечтает поспать."
        } else {
            status += " Кот сыт, весел, в темных очках и полон энтузиазма! Остроумен, грациозен и готов помочь."
        }
        return status
    }
}
