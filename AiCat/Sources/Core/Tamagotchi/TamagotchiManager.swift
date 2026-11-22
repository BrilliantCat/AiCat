import Combine
import Foundation
import UIKit
import WidgetKit

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
        var snapshot = CatSnapshot.load()
        if CatSnapshot.defaults.data(forKey: "catSnapshot") == nil,
           defaults.object(forKey: keySatiety) != nil {
            snapshot.satiety = defaults.integer(forKey: keySatiety)
            snapshot.happiness = defaults.integer(forKey: keyHappiness)
            snapshot.energy = defaults.integer(forKey: keyEnergy)
            snapshot.sleeping = defaults.bool(forKey: keyIsSleeping)
            snapshot.date = defaults.object(forKey: keyLastUpdate) as? Date ?? Date()
            snapshot.save()
        }
        if CatSnapshot.defaults.data(forKey: "catSnapshot") == nil { snapshot.save() }
        let current = snapshot.projected(at: Date())
        satiety = current.satiety
        happiness = current.happiness
        energy = current.energy
        isSleeping = current.sleeping
    }

    public func saveState() {
        var snapshot = CatSnapshot.load()
        snapshot.date = Date()
        snapshot.satiety = satiety
        snapshot.happiness = happiness
        snapshot.energy = energy
        snapshot.sleeping = isSleeping
        snapshot.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "AiCatHomeScreenWidget")
    }

    // Покормить кота рыбкой 🐟
    public func feedFish() -> String {
        loadStateAndApplyDecay()
        satiety = min(100, satiety + 30)
        happiness = min(100, happiness + 15)
        saveState()
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        CatActionHandler.shared.state.moodEmoji = "🐟"
        CatActionHandler.shared.state.statusText = "Хрустит тунцом (\(satiety)%)"
        LiveActivityManager.shared.update(status: "Сытость: \(satiety)%", mood: "🐟", action: "Ест рыбку")
        
        return "*Хрум-хрум-хрум*. М-м-м, свежий тунец! Сытость \(satiety)%. Вот теперь я сыт, доволен и мурчу на полную громкость, кожаный!"
    }
    
    // Погладить кота (ласка и мурчание)
    public func petCat() -> String {
        loadStateAndApplyDecay()
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
        loadStateAndApplyDecay()
        isSleeping = true
        CatActionHandler.shared.state.currentAction = .sleep
        CatActionHandler.shared.state.executionToken = UUID().uuidString
        saveState()
        
        CatActionHandler.shared.state.moodEmoji = "💤"
        CatActionHandler.shared.state.statusText = "Спит и восстанавливает энергию"
        LiveActivityManager.shared.update(status: "Спит...", mood: "💤", action: "Сон")
        
        return "*Свернулся клубком*. Восстанавливаю тактовую частоту нейросети... z-z-z."
    }
    
    // Разбудить
    public func wake() -> String {
        loadStateAndApplyDecay()
        isSleeping = false
        CatActionHandler.shared.state.currentAction = .idle
        CatActionHandler.shared.state.executionToken = UUID().uuidString
        saveState()
        
        CatActionHandler.shared.state.moodEmoji = "😼"
        CatActionHandler.shared.state.statusText = "Бодр и готов к делам"
        LiveActivityManager.shared.update(status: "Бодр и готов", mood: "😼", action: "На связи")
        
        return "*Потянулся, зевнул и поправил черные очки*. Я проснулся, кожаный! Что за задачи на повестке?"
    }
    
    public func play() -> String {
        loadStateAndApplyDecay()
        guard energy >= 20, !isSleeping else { return "Кожаный, сначала дай мне выспаться." }
        happiness = min(100, happiness + 15)
        energy = max(10, energy - 8)
        satiety = max(10, satiety - 3)
        saveState()
        _ = CatActionHandler.shared.execute(action: "somersault")
        LiveActivityManager.shared.update(status: "Играет с клубком", mood: "🧶", action: "Игра")
        return "Поймал клубок! Ещё раунд, кожаный?"
    }

    public func refreshAutonomousLife() {
        loadStateAndApplyDecay()
        let cat = CatSnapshot.load().projected(at: Date())
        CatActionHandler.shared.state.moodEmoji = cat.mood
        CatActionHandler.shared.state.statusText = cat.label
        LiveActivityManager.shared.startOrUpdateActivity(status: cat.label, mood: cat.mood,
                                                         action: cat.label, recordAction: false)
    }

    // Формирование системного контекста настроения кота для LLM-промпта
    public func moodContextPrompt() -> String {
        loadStateAndApplyDecay()
        let cat = CatSnapshot.load().projected(at: Date())
        var status = "САМОЧУВСТВИЕ КОТА (ТАМАГОЧИ): Сытость: \(satiety)%, Счастье: \(happiness)%, Энергия: \(energy)%."
        status += " Сейчас кот: \(cat.label). Завершено занятий: \(UserDefaults.standard.integer(forKey: "aicat.completedLessons")); тренировок: \(UserDefaults.standard.integer(forKey: "aicat.completedWorkouts"))."
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
