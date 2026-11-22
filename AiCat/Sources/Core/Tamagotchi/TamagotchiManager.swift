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
    @Published private(set) var isRoaming = true
    
    private let defaults = UserDefaults.standard
    private let keySatiety = "aicat_tamagotchi_satiety"
    private let keyHappiness = "aicat_tamagotchi_happiness"
    private let keyEnergy = "aicat_tamagotchi_energy"
    private let keyIsSleeping = "aicat_tamagotchi_sleeping"
    private let keyLastUpdate = "aicat_tamagotchi_last_update"
    
    private init() {
        // SideStore may restore the original group after a period of local-only care.
        if let shared = CatSnapshot.sharedDefaults, let local = defaults.data(forKey: "catSnapshot"),
           let lastLocal = try? JSONDecoder().decode(CatSnapshot.self, from: local) {
            let stored = shared.data(forKey: "catSnapshot").flatMap { try? JSONDecoder().decode(CatSnapshot.self, from: $0) }
            if lastLocal.date > (stored?.date ?? .distantPast) { shared.set(local, forKey: "catSnapshot") }
        }
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
        isRoaming = false
        var snapshot = CatSnapshot.load()
        snapshot.date = Date()
        snapshot.satiety = satiety
        snapshot.happiness = happiness
        snapshot.energy = energy
        snapshot.sleeping = isSleeping
        snapshot.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "AiCatHomeScreenWidget")
    }

    func care(_ care: CatCare) -> String {
        var cat = CatSnapshot.load().projected(at: Date())
        guard let reply = cat.apply(care) else {
            CatActionHandler.shared.state.statusText = cat.sleeping ? "Спит. Поиграем после сна" : "Устал и хочет отдохнуть"
            return "Кожаный, сначала дай мне выспаться."
        }
        commit(cat)
        if UIApplication.shared.applicationState == .active {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        return reply
    }

    public func feedFish() -> String { care(.feed) }
    public func petCat() -> String { care(.pet) }
    public func play() -> String { care(.play) }

    public func sleep() -> String {
        var cat = CatSnapshot.load().projected(at: Date())
        cat.sleeping = true
        cat.action = "sleep"
        cat.actionUntil = cat.date.addingTimeInterval(3600)
        commit(cat)
        return "Свернусь клубком. Если понадоблюсь — разбуди."
    }

    public func wake() -> String {
        var cat = CatSnapshot.load().projected(at: Date())
        cat.sleeping = false
        cat.action = "idle"
        cat.actionUntil = cat.date.addingTimeInterval(120)
        commit(cat)
        return "Потянулся. Я здесь, кожаный."
    }

    private func commit(_ cat: CatSnapshot, caption: String? = nil) {
        cat.save()
        satiety = cat.satiety
        happiness = cat.happiness
        energy = cat.energy
        isSleeping = cat.sleeping
        isRoaming = false
        var state = CatActionHandler.shared.state
        state.currentAction = cat.sleeping ? .sleep : .idle
        state.isHanging = false
        state.executionToken = UUID().uuidString
        state.moodEmoji = cat.mood
        state.statusText = caption ?? cat.label
        CatActionHandler.shared.state = state
        WidgetCenter.shared.reloadTimelines(ofKind: "AiCatHomeScreenWidget")
        LiveActivityManager.shared.startOrUpdateActivity(status: state.statusText, mood: cat.mood,
                                                         action: cat.label, recordAction: false)
    }

    public func refreshAutonomousLife() {
        loadStateAndApplyDecay()
        let cat = CatSnapshot.load().projected(at: Date())
        isRoaming = Date() >= cat.actionUntil
        CatActionHandler.shared.state.moodEmoji = cat.mood
        CatActionHandler.shared.state.statusText = cat.label
        let oldAction = CatActionHandler.shared.state.currentAction
        let performingTrick = [.somersault, .hangOnIsland, .dressUp].contains(oldAction) && Date() < cat.actionUntil
        let next: CatActionType = cat.action == "sleep" ? .sleep : .idle
        if !performingTrick && oldAction != next {
            CatActionHandler.shared.state.currentAction = next
            CatActionHandler.shared.state.executionToken = UUID().uuidString
        }
        LiveActivityManager.shared.startOrUpdateActivity(status: cat.label, mood: cat.mood,
                                                         action: cat.label, recordAction: false)
    }

    func didBecomeActive() {
        let lastVisit = defaults.object(forKey: "aicat.lastDeparture") as? Date
        defaults.removeObject(forKey: "aicat.lastDeparture")
        var cat = CatSnapshot.load().projected(at: Date())
        if let lastVisit, Date().timeIntervalSince(lastVisit) >= 1800,
           !cat.sleeping, Date() >= cat.actionUntil {
            cat.happiness = min(100, cat.happiness + 4)
            cat.action = "purr"
            cat.actionUntil = cat.date.addingTimeInterval(120)
            commit(cat, caption: "Встречает тебя и мурчит")
        } else {
            refreshAutonomousLife()
        }
    }

    // Формирование системного контекста настроения кота для LLM-промпта
    public func moodContextPrompt() -> String {
        loadStateAndApplyDecay()
        let cat = CatSnapshot.load().projected(at: Date())
        var status = "САМОЧУВСТВИЕ КОТА (ТАМАГОЧИ): Сытость: \(satiety)%, Счастье: \(happiness)%, Энергия: \(energy)%."
        status += " Сейчас кот: \(cat.label). Завершено занятий: \(UserDefaults.standard.integer(forKey: "aicat.completedLessons")); тренировок: \(UserDefaults.standard.integer(forKey: "aicat.completedWorkouts"))."
        status += " Учитывай состояние в тоне ответа, но не требуй ухода в каждом сообщении. Если пользователь задаёт вопрос, сначала ответь на него."
        return status
    }
}
