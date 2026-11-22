import Foundation
import SwiftUI
import UIKit

struct CatSnapshot: Codable {
    var date = Date()
    var satiety = 85
    var happiness = 90
    var energy = 95
    var sleeping = false
    var action = "idle"
    var actionUntil = Date.distantPast

    static let group = "group.com.brilliantcat.aicat"
    static var defaults: UserDefaults {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil else {
            return .standard
        }
        return UserDefaults(suiteName: group) ?? .standard
    }

    static func load() -> CatSnapshot {
        guard let data = defaults.data(forKey: "catSnapshot"),
              let state = try? JSONDecoder().decode(CatSnapshot.self, from: data) else { return CatSnapshot() }
        return state
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { Self.defaults.set(data, forKey: "catSnapshot") }
    }

    func projected(at now: Date) -> CatSnapshot {
        var state = self
        // Simulate bounded intervals so a closed app follows the same daily rhythm.
        var cursor = max(date, now.addingTimeInterval(-7 * 86400))
        var food = Double(satiety)
        var joy = Double(happiness)
        var stamina = Double(energy)
        var asleep = sleeping
        while cursor < now {
            let next = min(now, cursor.addingTimeInterval(900))
            let hours = next.timeIntervalSince(cursor) / 3600
            let hour = Calendar.current.component(.hour, from: cursor)
            let night = hour < 7 || hour >= 23
            if stamina < 25 || (night && cursor >= actionUntil) { asleep = true }
            if asleep && stamina >= 95 && !night { asleep = false }
            food = max(10, food - hours * (asleep ? 2 : 4))
            joy = max(15, joy - hours * (asleep ? 1 : 2))
            stamina = min(100, max(10, stamina + hours * (asleep ? 15 : -4)))
            cursor = next
        }
        state.satiety = Int(food)
        state.happiness = Int(joy)
        state.energy = Int(stamina)
        state.sleeping = asleep
        if now >= actionUntil {
            let scenes = ["idle", "groom", "play", "computer", "idle"]
            let slot = Int(now.timeIntervalSince1970 / 900)
            let index = ((slot % scenes.count) + scenes.count) % scenes.count
            state.action = asleep ? "sleep" : (state.satiety < 35 ? "idle" : scenes[index])
        }
        state.date = now
        return state
    }

    static func scene(mood: String) -> String {
        switch mood {
        case "🐟": return "eat"
        case "💤": return "sleep"
        case "👅", "😻": return "groom"
        case "🧶", "🤸‍♂️", "💪", "🐆": return "play"
        case "🤔", "💻", "🧠": return "computer"
        default: return "idle"
        }
    }

    var mood: String {
        ["idle": "😼", "sleep": "💤", "groom": "👅", "play": "🧶",
         "computer": "💻", "eat": "🐟"][action] ?? "😼"
    }

    var label: String {
        if satiety < 35 && action != "sleep" { return "Ждёт рыбку" }
        if happiness < 35 && action == "idle" { return "Ждёт ласки" }
        return ["idle": "Наблюдает", "sleep": "Спит", "groom": "Умывается", "play": "Играет",
         "computer": "За компьютером", "eat": "Перекусывает"][action] ?? "Наблюдает"
    }
}

struct CatPicture: View {
    let scene: String
    var islandSide: String? = nil

    var body: some View {
        let pose = scene == "sleep" ? "sleep" : (scene == "computer" ? "think" : "peek")
        let resource = islandSide.map { "dynamic-island/\(pose)-\($0)" } ?? "widget/\(scene)"
        if let url = Bundle.main.url(forResource: resource, withExtension: "png", subdirectory: "AiCat-Visuals"),
           let picture = UIImage(contentsOfFile: url.path) {
            Image(uiImage: picture).resizable().scaledToFit().accessibilityLabel("Кот AiCat")
        }
    }
}
