import Foundation
import SwiftUI
import UIKit

struct CatSnapshot: Codable {
    var date = Date()
    var satiety = 85
    var happiness = 90
    var energy = 95
    var sleeping = false
    var outfit: String? = nil
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
    var outfit: String? = nil

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            CatPortrait(scene: scene, outfit: outfit)
                .frame(width: side, height: side)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .accessibilityLabel("Кот AiCat. \(scene == "sleep" ? "Спит" : "Бодрствует")")
    }
}

private struct CatPortrait: View {
    let scene: String
    let outfit: String?
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                CatHeadShape()
                    .foregroundStyle(LinearGradient(colors: [Color(white: 0.72), Color(white: 0.36)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                HStack(spacing: size * 0.15) {
                    eye(size: size)
                    eye(size: size)
                }
                .offset(y: -size * 0.08)
                if let outfit, outfit.localizedCaseInsensitiveContains("очки") {
                    Capsule().fill(Color(white: 0.08))
                        .frame(width: size * 0.6, height: size * 0.18)
                        .overlay(Capsule().stroke(.mint.opacity(0.6), lineWidth: 1))
                        .offset(y: -size * 0.08)
                }
                Ellipse().fill(Color(red: 0.85, green: 0.57, blue: 0.6))
                    .frame(width: size * 0.07, height: size * 0.045)
                    .offset(y: size * 0.04)
                if scene == "sleep" {
                    Text("z").font(.system(size: size * 0.18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75)).offset(x: size * 0.35, y: -size * 0.3)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
    private func eye(size: CGFloat) -> some View {
        ZStack {
            Capsule().fill(Color(red: 0.55, green: 0.88, blue: 0.35))
            if scene != "sleep" {
                Capsule().fill(.black).frame(width: size * 0.025)
                Circle().fill(.white).frame(width: size * 0.025).offset(x: -size * 0.025, y: -size * 0.02)
            }
        }
        .frame(width: size * 0.15, height: size * (scene == "sleep" ? 0.018 : 0.12))
    }
}

private struct CatHeadShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        path.move(to: point(0.12, 0.45))
        path.addQuadCurve(to: point(0.12, 0.06), control: point(0.06, 0.12))
        path.addQuadCurve(to: point(0.33, 0.22), control: point(0.23, 0.06))
        path.addQuadCurve(to: point(0.67, 0.22), control: point(0.5, 0.13))
        path.addQuadCurve(to: point(0.88, 0.06), control: point(0.77, 0.06))
        path.addQuadCurve(to: point(0.88, 0.45), control: point(0.94, 0.12))
        path.addCurve(to: point(0.5, 0.92), control1: point(1.08, 0.79), control2: point(0.76, 0.94))
        path.addCurve(to: point(0.12, 0.45), control1: point(0.24, 0.94), control2: point(-0.08, 0.79))
        path.closeSubpath()
        return path
    }
}
