import Foundation

/// Device commands use the original text for addresses, message bodies and shortcut names.
struct PhoneCommand: Equatable {
    let command: String
    var value = ""
    var detail = ""

    static let toolCommands = "open_application, agenda_today, agenda_tomorrow, reminders_today, reminders_tomorrow, battery, device_status, brightness_read, brightness, flashlight_on, flashlight_off, timer_start, timer_status, timer_cancel, call, facetime, sms_draft, mail_draft, copy_text, open_url, web_search, maps, route_walk, route_drive, route_transit, music_resume, music_pause, music_next, music_previous, music_now, run_shortcut, shortcuts_app, settings, camera"

    static let shortcutsKey = "aicat.phone.shortcutPhrases"
    static var savedShortcuts: [String: String] {
        UserDefaults.standard.dictionary(forKey: shortcutsKey) as? [String: String] ?? [:]
    }

    static func phraseKey(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "ё", with: "е")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".!?")))
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static func parse(_ raw: String, shortcuts: [String: String] = [:]) -> Self? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"(?i)^(?:(?:кот(?:ик)?|aicat)[,\s]+)?(?:пожалуйста[,\s]+)?"#, with: "", options: .regularExpression)
        let key = phraseKey(text)
        if let shortcut = shortcuts[key] { return Self(command: "run_shortcut", value: shortcut) }
        let simple: [String: String] = [
            "включи фонарик": "flashlight_on", "выключи фонарик": "flashlight_off", "погаси фонарик": "flashlight_off",
            "заряд батареи": "battery", "сколько заряда": "battery", "какой заряд": "battery", "сколько осталось заряда": "battery",
            "какая яркость": "brightness_read", "узнай яркость": "brightness_read", "яркость экрана": "brightness_read",
            "планы на сегодня": "agenda_today", "планы на завтра": "agenda_tomorrow", "какие планы на сегодня": "agenda_today",
            "напоминания на сегодня": "reminders_today", "напоминания на завтра": "reminders_tomorrow",
            "открой телеграм": "app_telegram", "открой ютуб": "app_youtube", "открой ватсап": "app_whatsapp",
            "открой карты": "app_maps", "открой музыку": "app_music",
            "статус телефона": "device_status", "состояние телефона": "device_status",
            "сколько осталось на таймере": "timer_status", "проверь таймер": "timer_status", "отмени таймер": "timer_cancel",
            "останови таймер": "timer_cancel", "открой настройки": "settings", "открой настройки aicat": "settings",
            "посмотри в камеру": "camera", "открой камеру": "camera", "открой команды": "shortcuts_app",
            "продолжи музыку": "music_resume", "приостанови музыку": "music_pause", "поставь музыку на паузу": "music_pause",
            "следующий трек": "music_next", "предыдущий трек": "music_previous", "что играет": "music_now",
            "что ты умеешь с телефоном": "phone_help", "команды телефона": "phone_help"
        ]
        if let command = simple[key] {
            if command.hasPrefix("app_") { return Self(command: "open_application", value: String(command.dropFirst(4))) }
            return Self(command: command)
        }

        func fields(_ pattern: String) -> [String]? {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
            return (1..<match.numberOfRanges).map { i in
                Range(match.range(at: i), in: text).map { String(text[$0]).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
            }
        }
        if let args = fields(#"^(?:установи |поставь |сделай )?яркость(?: экрана)?\s+(?:на\s+)?(\d{1,3})\s*(?:%|процент(?:а|ов)?)?[.!]?$"#) {
            return Self(command: "brightness", value: args[0])
        }
        if let args = fields(#"^(?:поставь |установи |заведи |запусти )?таймер\s+(?:на\s+)?(.+)$"#) {
            return Self(command: "timer_start", value: duration(args[0]).map { String($0) } ?? "")
        }
        if let args = fields(#"^(?:напиши|подготовь|отправь)\s+(?:смс|sms|сообщение)\s+(.+?)(?:\s*:\s*|\s+с текстом\s+)(.+)$"#) {
            return Self(command: "sms_draft", value: args[0], detail: args[1])
        }
        if let args = fields(#"^(?:напиши|подготовь|отправь)\s+(?:письмо|email)\s+([^\s:]+)(?:\s*:\s*|\s+с текстом\s+)(.+)$"#) {
            return Self(command: "mail_draft", value: args[0], detail: args[1])
        }
        let actions = [
            (#"^(?:позвони по (?:facetime|фейстайм)|видеозвонок)\s+(.+)$"#, "facetime"),
            (#"^(?:позвони|набери номер)\s+(?:пожалуйста[,\s]+)?(?:по номеру\s+)?(.+)$"#, "call"),
            (#"^(?:напиши|подготовь|отправь)\s+(?:смс|sms|сообщение)\s+(.+)$"#, "sms_draft"),
            (#"^(?:напиши|подготовь|отправь)\s+(?:письмо|email)\s+(.+)$"#, "mail_draft"),
            (#"^(?:построй\s+)?маршрут пешком (?:до|в|к)\s+(.+)$"#, "route_walk"),
            (#"^(?:построй\s+)?маршрут на транспорте (?:до|в|к)\s+(.+)$"#, "route_transit"),
            (#"^(?:построй\s+)?маршрут(?: на машине)? (?:до|в|к)\s+(.+)$"#, "route_drive"),
            (#"^открой приложение\s+(.+)$"#, "open_application"),
            (#"^(?:найди|покажи) на карте\s+(.+)$"#, "maps"),
            (#"^открой сайт\s+(.+)$"#, "open_url"),
            (#"^(?:поищи|найди) в интернете\s+(.+)$"#, "web_search"),
            (#"^скопируй\s+(.+)$"#, "copy_text"),
            (#"^запусти команду\s+(.+?)(?:\s+с текстом\s+(.+))?$"#, "run_shortcut")
        ]
        for (pattern, action) in actions {
            if let args = fields(pattern) {
                return Self(command: action, value: args[0], detail: args.count > 1 ? args[1] : "")
            }
        }
        if key.range(of: #"^(включи|выключи|отключи|поставь|установи|измени) (wi-?fi|вай[ -]?фай|bluetooth|блюту[зс]|авиарежим|режим полета|фокусирование|режим не беспокоить|громкость|энергосбережение)( |$)"#, options: .regularExpression) != nil {
            return Self(command: "shortcut_setup", value: key)
        }
        return nil
    }

    private static func duration(_ input: String) -> Double? {
        let value = phraseKey(input).replacingOccurrences(of: ",", with: ".")
        if let seconds = Double(value) { return seconds }
        if ["минуту", "секунду", "час"].contains(value) { return value == "час" ? 3600 : (value == "минуту" ? 60 : 1) }
        let numbers = ["один":1, "одну":1, "два":2, "две":2, "три":3, "четыре":4, "пять":5, "десять":10, "пятнадцать":15, "тридцать":30]
        let numberPattern = #"(\d+(?:\.\d+)?|"# + numbers.keys.sorted().joined(separator: "|") + ")"
        guard let regex = try? NSRegularExpression(pattern: #"^\s*(?:и\s+)?"# + numberPattern + #"\s*(час(?:а|ов)?|ч|минут(?:ы|у|а)?|мин|м|секунд(?:у|ы|а)?|сек|с)(?=\s|\d|$)"#) else { return nil }
        var rest = value
        var total = 0.0
        while !rest.isEmpty {
            let ns = rest as NSString
            guard let match = regex.firstMatch(in: rest, range: NSRange(location: 0, length: ns.length)) else { return nil }
            let token = ns.substring(with: match.range(at: 1))
            guard let number = Double(token) ?? numbers[token].map({ Double($0) }) else { return nil }
            let unit = ns.substring(with: match.range(at: 2))
            total += number * (unit.hasPrefix("ч") ? 3600 : unit.hasPrefix("м") ? 60 : 1)
            rest = ns.substring(from: NSMaxRange(match.range))
        }
        return total
    }
}
