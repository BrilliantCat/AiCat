import UIKit
import UserNotifications

@MainActor
public final class PhoneControlTool: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = PhoneControlTool()
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    public nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    public func execute(command: String, value: String = "") async -> String {
        switch command {
        case "battery":
            UIDevice.current.isBatteryMonitoringEnabled = true
            let level = UIDevice.current.batteryLevel
            return level < 0 ? "Заряд батареи недоступен." : "Заряд iPhone: \(Int(level * 100))%."
        case "brightness":
            guard let percent = Double(value), percent.isFinite, (0...100).contains(percent) else {
                return "Укажи яркость от 0 до 100."
            }
            UIScreen.main.brightness = CGFloat(percent / 100)
            return "Яркость: \(Int(percent))%."
        case "copy_text":
            UIPasteboard.general.string = value
            return "Скопировал текст."
        case "open_url":
            guard let url = URL(string: value), ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
                return "Нужен адрес сайта, начинающийся с https:// или http://."
            }
            return await open(url)
        case "maps":
            return await openComponents(scheme: "https", host: "maps.apple.com", path: "/", items: [URLQueryItem(name: "q", value: value)])
        case "run_shortcut":
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "Укажи название команды из приложения Команды." }
            return await openComponents(scheme: "shortcuts", host: "run-shortcut", path: "", items: [URLQueryItem(name: "name", value: value)])
        case "settings": return await open(URL(string: UIApplication.openSettingsURLString)!)
        case "camera":
            NotificationCenter.default.post(name: NSNotification.Name("OpenMediaStudio"), object: nil)
            return "Открыл мастерскую. Нажми «Посмотреть через камеру»."
        case "timer_start":
            guard let seconds = Double(value), seconds.isFinite, (1...86400).contains(seconds) else {
                return "Укажи длительность таймера в секундах от 1 до 86400."
            }
            let center = UNUserNotificationCenter.current()
            do {
                guard try await center.requestAuthorization(options: [.alert, .sound]) else { return "Разреши уведомления AiCat для таймера." }
                let content = UNMutableNotificationContent()
                content.title = "AiCat"
                content.body = "Кожаный, время вышло!"
                content.sound = .default
                try await center.add(UNNotificationRequest(identifier: "aicat.timer", content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)))
                UserDefaults.standard.set(Date().addingTimeInterval(seconds), forKey: "aicat.timer.end")
                return "Таймер установлен на \(Int(seconds)) с."
            } catch { return "Не удалось поставить таймер: \(error.localizedDescription)" }
        case "timer_cancel":
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["aicat.timer"])
            UserDefaults.standard.removeObject(forKey: "aicat.timer.end")
            return "Таймер отменён."
        default: return "Команда телефона не поддерживается."
        }
    }

    private func openComponents(scheme: String, host: String, path: String, items: [URLQueryItem]) async -> String {
        var parts = URLComponents()
        parts.scheme = scheme
        parts.host = host
        parts.path = path
        parts.queryItems = items
        guard let url = parts.url else { return "Не удалось сформировать ссылку." }
        return await open(url)
    }
    private func open(_ url: URL) async -> String {
        let result = await UIApplication.shared.open(url, options: [:])
        return result ? "Передал запрос приложению." : "iOS не смогла открыть ссылку."
    }
}
