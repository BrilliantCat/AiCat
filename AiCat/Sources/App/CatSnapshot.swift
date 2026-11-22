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
    static let sharedDefaults: UserDefaults? = {
        // Re-signing may append the team ID to the original App Group.
        // Accept only groups for this app which this process can actually open.
        var groups = [group]
        if let profile = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
           let data = try? Data(contentsOf: profile),
           let start = data.range(of: Data("<?xml".utf8)),
           let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
           let plist = try? PropertyListSerialization.propertyList(from: data.subdata(in: start.lowerBound..<end.upperBound),
                                                                 options: [], format: nil) as? [String: Any],
           let entitlements = plist["Entitlements"] as? [String: Any],
           let signedGroups = entitlements["com.apple.security.application-groups"] as? [String] {
            groups += signedGroups.filter { $0.hasPrefix(group + ".") && !$0.contains("*") }
        }
        for candidate in groups where FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: candidate) != nil {
            if let suite = UserDefaults(suiteName: candidate) { return suite }
        }
        return nil
    }()
    static var defaults: UserDefaults { sharedDefaults ?? .standard }

    private static let activities = ["idle", "groom", "play", "computer", "idle"]
    private static func activity(at slot: Int) -> String {
        let count = activities.count
        return activities[(slot % count + count) % count]
    }

    static func load() -> CatSnapshot {
        guard let data = defaults.data(forKey: "catSnapshot"),
              let state = try? JSONDecoder().decode(CatSnapshot.self, from: data) else {
            var first = CatSnapshot()
            first.sleeping = !(7..<23).contains(Calendar.current.component(.hour, from: first.date))
            first.action = first.sleeping ? "sleep" : "idle"
            return first
        }
        return state
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults.set(data, forKey: "catSnapshot")
        if Self.sharedDefaults != nil { UserDefaults.standard.set(data, forKey: "catSnapshot") }
    }

    /// Apply to the snapshot already projected to the interaction time.
    mutating func apply(_ care: CatCare) -> String? {
        let reply: String
        switch care {
        case .feed:
            sleeping = false
            satiety = min(100, satiety + 30)
            happiness = min(100, happiness + 15)
            action = "eat"
            reply = "О, рыбка! Сяду рядом и съем по кусочку."
        case .pet:
            happiness = min(100, happiness + 20)
            if sleeping {
                action = "sleep"
                return "Тихонько мурчит во сне."
            }
            action = "purr"
            reply = "Мурр. Вот тут, за ухом."
        case .play:
            guard !sleeping, energy >= 20 else { return nil }
            happiness = min(100, happiness + 15)
            satiety = max(10, satiety - 3)
            energy = max(10, energy - 8)
            action = "play"
            reply = "Поймал! Кати ещё, кожаный."
        }
        actionUntil = date.addingTimeInterval(120)
        return reply
    }

    func projected(at now: Date) -> CatSnapshot {
        var state = self
        // Anchor ticks to the clock. Saving after a stroke must not round away a
        // fraction of a point, or restart the countdown until the next meal.
        let slot = Int(floor(now.timeIntervalSince1970 / 900))
        var tick = max(Int(floor(date.timeIntervalSince1970 / 900)), slot - 7 * 96)
        while tick < slot {
            tick += 1
            let instant = Date(timeIntervalSince1970: Double(tick) * 900)
            let hour = Calendar.current.component(.hour, from: instant)
            let night = hour < 7 || hour >= 23
            if instant >= state.actionUntil {
                if night || state.energy < 25 { state.sleeping = true }
                else if state.energy >= 95 { state.sleeping = false }
            }
            func points(perHour rate: Int) -> Int { tick * rate / 4 - (tick - 1) * rate / 4 }
            state.satiety = max(10, state.satiety - points(perHour: state.sleeping ? 2 : 4))
            state.happiness = max(15, state.happiness - points(perHour: state.sleeping ? 1 : 2))
            let energyChange = state.sleeping ? points(perHour: 15) : -points(perHour: 4)
            state.energy = min(100, max(10, state.energy + energyChange))
            if !state.sleeping && state.satiety <= 42 && instant >= state.actionUntil {
                state.satiety += 28
                state.action = "eat"
                state.actionUntil = instant.addingTimeInterval(300)
            } else if !state.sleeping && instant >= state.actionUntil &&
                        state.happiness < 65 && Self.activity(at: tick) == "play" {
                state.happiness += 4
            }
        }
        if now >= state.actionUntil {
            state.action = state.sleeping ? "sleep" : Self.activity(at: slot)
        }
        state.date = now
        return state
    }

    static func scene(mood: String) -> String {
        switch mood {
        case "🐟": return "eat"
        case "💤": return "sleep"
        case "👅": return "groom"
        case "😻": return "purr"
        case "🧶", "🤸‍♂️", "💪", "🐆": return "play"
        case "🤔", "💻", "🧠": return "computer"
        default: return "idle"
        }
    }

    var mood: String {
        ["idle": "😼", "sleep": "💤", "groom": "👅", "play": "🧶",
         "computer": "💻", "eat": "🐟", "purr": "😻"][action] ?? "😼"
    }

    var label: String {
        if satiety < 35 && action != "sleep" { return "Ждёт рыбку" }
        if happiness < 35 && action == "idle" { return "Ждёт ласки" }
        return ["idle": "Наблюдает", "sleep": "Спит", "groom": "Умывается", "play": "Играет",
         "computer": "За компьютером", "eat": "Перекусывает", "purr": "Мурчит"][action] ?? "Наблюдает"
    }

    var roomArtwork: String { action == "purr" ? "idle" : action }
}

struct CatPicture: View {
    let scene: String
    var islandSide: String? = nil
    var outfit: String? = nil
    var islandState: String? = nil

    private var artwork: UIImage? {
        let location: (name: String, folder: String)
        if let islandSide {
            let state = islandState ?? (scene == "sleep" ? "sleep" : "peek")
            location = ("\(state)-\(islandSide)", "dynamic-island")
        } else {
            location = (scene == "purr" ? "idle" : scene, "widget")
        }
        return Self.artwork(named: location.name, folder: location.folder)
    }

    static func artwork(named name: String, folder: String) -> UIImage? {
        UIImage(named: "AiCat-Visuals/\(folder)/\(name).png", in: .main, compatibleWith: nil)
    }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            Group {
                if let artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: islandSide == nil ? side * 0.16 : 0))
                } else {
                    CatPortrait(scene: scene, outfit: outfit)
                }
            }
                .frame(width: islandSide == nil ? side : geometry.size.width,
                       height: islandSide == nil ? side : geometry.size.height)
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
