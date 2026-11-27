import UIKit
import UserNotifications
import AVFoundation
import MediaPlayer

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

    public func execute(command: String, value: String = "", detail: String = "") async -> String {
        switch command {
        case "open_application":
            return await AppLauncherTool.shared.openApp(named: value)
        case "agenda_today", "agenda_tomorrow", "reminders_today", "reminders_tomorrow":
            let date = command.hasSuffix("tomorrow") ? "tomorrow" : "today"
            let tool = command.hasPrefix("agenda") ? "get_calendar_events" : "get_reminders"
            let result = await ToolRegistry.shared.executeTool(name: tool, parameters: ["date": date])
            return result.result
        case "phone_help":
            return "Например: «поставь таймер на пять минут», «яркость 40%», «позвони маме», «напиши СМС маме: я дома», «маршрут пешком до вокзала», «следующий трек». Свои фразы можно задать в меню «Телефон»."
        case "call", "facetime", "sms_draft", "mail_draft":
            return await PhoneCommunication.shared.perform(command, recipient: value, text: detail)
        case "flashlight_on", "flashlight_off":
            let mode: AVCaptureDevice.TorchMode = command == "flashlight_on" ? .on : .off
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  device.hasTorch, device.isTorchModeSupported(mode) else { return "Фонарик недоступен." }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                guard mode == .off || device.isTorchAvailable else { return "Фонарик сейчас занят или недоступен." }
                device.torchMode = mode
                return mode == .on ? "Включил фонарик." : "Выключил фонарик."
            } catch { return "Не удалось переключить фонарик." }
        case "device_status":
            let battery = await execute(command: "battery")
            let brightness = await execute(command: "brightness_read")
            let power = ProcessInfo.processInfo.isLowPowerModeEnabled ? "включено" : "выключено"
            let charging: String
            switch UIDevice.current.batteryState {
            case .charging: charging = "Идёт зарядка."
            case .full: charging = "Батарея заряжена."
            default: charging = ""
            }
            return [battery, charging, brightness, "Энергосбережение: \(power)."].filter { !$0.isEmpty }.joined(separator: " ")
        case "music_resume", "music_pause", "music_next", "music_previous", "music_now":
            return await controlMusic(command)
        case "battery":
            UIDevice.current.isBatteryMonitoringEnabled = true
            let level = UIDevice.current.batteryLevel
            return level < 0 ? "Заряд батареи недоступен." : "Заряд iPhone: \(Int(level * 100))%."
        case "brightness_read": return "Яркость экрана: \(Int((UIScreen.main.brightness * 100).rounded()))%."
        case "brightness":
            guard let percent = Double(value), percent.isFinite, (0...100).contains(percent) else {
                return "Укажи яркость от 0 до 100."
            }
            UIScreen.main.brightness = CGFloat(percent / 100)
            return "Яркость: \(Int(percent))%."
        case "copy_text":
            guard !value.isEmpty else { return "Какой текст скопировать?" }
            UIPasteboard.general.string = value
            return "Скопировал текст."
        case "open_url":
            let address = value.contains("://") ? value : "https://" + value
            guard let url = URL(string: address), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                  let host = url.host, !host.isEmpty, !value.contains(where: { $0.isWhitespace }) else {
                return "Нужен адрес сайта, начинающийся с https:// или http://."
            }
            return await open(url)
        case "route_walk", "route_transit", "route_drive":
            guard !value.isEmpty else { return "Куда проложить маршрут?" }
            let mode = command == "route_walk" ? "w" : command == "route_transit" ? "r" : "d"
            return await openComponents(scheme: "https", host: "maps.apple.com", path: "/", items: [
                URLQueryItem(name: "daddr", value: value), URLQueryItem(name: "dirflg", value: mode)])
        case "web_search":
            guard !value.isEmpty else { return "Что найти в интернете?" }
            return await openComponents(scheme: "https", host: "duckduckgo.com", path: "/", items: [URLQueryItem(name: "q", value: value)])
        case "maps":
            guard !value.isEmpty else { return "Укажи место или адрес." }
            return await openComponents(scheme: "https", host: "maps.apple.com", path: "/", items: [URLQueryItem(name: "q", value: value)])
        case "shortcut_setup":
            return "В приложении «Команды» создай сценарий с нужным действием. В AiCat → Телефон → Команды iOS привяжи фразу «\(value)» к его точному названию."
        case "shortcuts_app":
            return await openComponents(scheme: "shortcuts", host: "", path: "", items: [])
        case "run_shortcut":
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "Укажи название команды из приложения Команды." }
            var items = [URLQueryItem(name: "name", value: value)]
            if !detail.isEmpty {
                items += [URLQueryItem(name: "input", value: "text"), URLQueryItem(name: "text", value: detail)]
            }
            return await openComponents(scheme: "shortcuts", host: "run-shortcut", path: "", items: items)
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
        case "timer_status":
            let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
            guard let timer = pending.first(where: { $0.identifier == "aicat.timer" }),
                  let trigger = timer.trigger as? UNTimeIntervalNotificationTrigger,
                  let end = (UserDefaults.standard.object(forKey: "aicat.timer.end") as? Date) ?? trigger.nextTriggerDate(),
                  end > Date() else { return "У AiCat нет активного таймера." }
            let seconds = Int(ceil(end.timeIntervalSinceNow))
            return "Таймер AiCat: осталось \(seconds / 60) мин \(seconds % 60) с."
        case "timer_cancel":
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["aicat.timer"])
            UserDefaults.standard.removeObject(forKey: "aicat.timer.end")
            return "Таймер отменён."
        default: return "Команда телефона не поддерживается."
        }
    }

    private func controlMusic(_ command: String) async -> String {
        let authorization = await withCheckedContinuation { (continuation: CheckedContinuation<MPMediaLibraryAuthorizationStatus, Never>) in
            MPMediaLibrary.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard authorization == .authorized else { return "Для управления приложением «Музыка» разреши AiCat доступ к медиатеке." }
        let player = MPMusicPlayerController.systemMusicPlayer
        if command == "music_now" {
            guard let item = player.nowPlayingItem else { return "В приложении «Музыка» нет выбранного трека." }
            return [item.title, item.artist].compactMap { $0 }.joined(separator: " — ")
        }
        guard player.nowPlayingItem != nil else { return "Сначала выбери трек в приложении «Музыка»." }
        switch command {
        case "music_pause": player.pause()
        case "music_resume": player.play()
        case "music_next": player.skipToNextItem()
        default: player.skipToPreviousItem()
        }
        return "Передал команду приложению «Музыка»."
    }

    private func openComponents(scheme: String, host: String, path: String, items: [URLQueryItem]) async -> String {
        var parts = URLComponents()
        parts.scheme = scheme
        parts.host = host
        parts.path = path
        if !items.isEmpty { parts.queryItems = items }
        guard let url = parts.url else { return "Не удалось сформировать ссылку." }
        return await open(url)
    }
    private func open(_ url: URL) async -> String {
        let result = await UIApplication.shared.open(url, options: [:])
        return result ? "Передал запрос приложению." : "iOS не смогла открыть ссылку."
    }
}
