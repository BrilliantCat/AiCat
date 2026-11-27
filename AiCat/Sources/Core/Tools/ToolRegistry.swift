import Foundation
import UIKit

public struct ToolCallPayload: Codable {
    public let thought: String?
    public let tool: String
    public let parameters: [String: String]?
    public let reply_text: String?
}

public struct ToolDefinition {
    public let name: String
    public let description: String
    public let parametersSchema: [String: String]
    public let requiresConfirmation: Bool
}

public final class ToolRegistry {
    public static let shared = ToolRegistry()
    
    public let definitions: [ToolDefinition] = [
        ToolDefinition(name: "control_workout", description: "Управление текущим занятием",
                       parametersSchema: ["action": "pause | resume | next | rep | stop"], requiresConfirmation: false),
        ToolDefinition(
            name: "cat_action",
            description: "Управление физическими действиями кота (трюки, анимации, гардероб)",
            parametersSchema: ["action": "hang_on_island | feed | wash | somersault | play | dress_up | take_off | sleep | wake | pet", "item": "кепка, берет, черные или янтарные очки, кулон, бабочка, худи, жилетка, джинсовые штаны. take_off без item снимает всё."],
            requiresConfirmation: false
        ),
        ToolDefinition(
            name: "create_reminder",
            description: "Создать напоминание в приложении 'Напоминания' iOS",
            parametersSchema: ["title": "текст напоминания", "dueDate": "ISO8601 дата или nil"],
            requiresConfirmation: true
        ),
        ToolDefinition(
            name: "get_reminders",
            description: "Прочитать список активных напоминаний",
            parametersSchema: ["date": "ISO8601 дата для фильтрации или 'today'"],
            requiresConfirmation: false
        ),
        ToolDefinition(
            name: "create_calendar_event",
            description: "Запланировать встречу или событие в Календаре iOS",
            parametersSchema: ["title": "название события", "startDate": "ISO8601 дата начала", "endDate": "ISO8601 дата окончания"],
            requiresConfirmation: true
        ),
        ToolDefinition(
            name: "get_calendar_events",
            description: "Посмотреть планы и встречи в Календаре",
            parametersSchema: ["date": "ISO8601 дата или 'today'"],
            requiresConfirmation: false
        ),
        ToolDefinition(
            name: "create_note",
            description: "Сохранить важную мысль или заметку в локальный дневник AiCat",
            parametersSchema: ["title": "заголовок", "content": "текст заметки"],
            requiresConfirmation: true
        ),
        ToolDefinition(
            name: "search_notes",
            description: "Поиск по сохраненным заметкам",
            parametersSchema: ["query": "поисковый запрос"],
            requiresConfirmation: false
        ),
        ToolDefinition(
            name: "search_knowledge_base",
            description: "Полнотекстовый поиск по документам RAG (PDF, TXT, MD) через алгоритм BM25",
            parametersSchema: ["query": "запрос для поиска в документах"],
            requiresConfirmation: false
        ),
        ToolDefinition(
            name: "open_app",
            description: "Запустить системное или установленное приложение на iPhone",
            parametersSchema: ["appName": "telegram | youtube | whatsapp | camera | settings | music | maps | calculator | notes"],
            requiresConfirmation: true
        ),
        ToolDefinition(
            name: "device_action",
            description: "Управление телефоном и приложениями iOS",
            parametersSchema: ["command": PhoneCommand.toolCommands, "value": "номер, имя контакта, email, адрес, название команды, текст или число", "detail": "текст сообщения или входной текст команды"],
            requiresConfirmation: false
        ),
        ToolDefinition(
            name: "translate",
            description: "Офлайн-перевод текста на другой язык",
            parametersSchema: ["text": "исходный текст", "targetLanguage": "язык перевода"],
            requiresConfirmation: false
        ),
        ToolDefinition(
            name: "analyze_photo",
            description: "Офлайн-анализ изображения через Vision (OCR распознавание текста, удаление фона, улучшение)",
            parametersSchema: ["action": "ocr | remove_background | auto_enhance"],
            requiresConfirmation: false
        ),
        ToolDefinition(
            name: "generate_image",
            description: "Генерация арта на чипе A17 Pro (города, космос, авто, кибер-кот)",
            parametersSchema: ["prompt": "описание желаемого арта"],
            requiresConfirmation: false
        ),
        ToolDefinition(
            name: "play_music",
            description: "Синтезировать и включить олдскульный бит на стерео-синтезаторе",
            parametersSchema: ["style": "lo-fi | cyberpunk | 8-bit"],
            requiresConfirmation: false
        ),
        ToolDefinition(
            name: "start_workout",
            description: "Запустить интерактивную фитнес-тренировку",
            parametersSchema: ["workoutType": "pushups | squats | yoga | breathing | mobility | plank", "reps": "количество повторений 1–100"],
            requiresConfirmation: false
        ),
        ToolDefinition(
            name: "get_status",
            description: "Получить полный статус кота, тамагочи, срок сертификата и состояние моделей",
            parametersSchema: [:],
            requiresConfirmation: false
        )
    ]
    
    private init() {}
    
    // Парсер и диспетчер вызовов инструментов
    public func executeTool(name: String, parameters: [String: String]) async -> (success: Bool, result: String, image: UIImage?) {
        switch name {
        case "cat_action":
            let action = parameters["action"] ?? "idle"
            let item = parameters["item"]
            let res = await MainActor.run { CatActionHandler.shared.execute(action: action, item: item) }
            return (true, res, nil)
            
        case "create_reminder":
            let title = parameters["title"] ?? "Новое напоминание"
            let dueDate = parseDate(from: parameters["dueDate"])
            let res = await ReminderTool.shared.createReminder(title: title, dueDate: dueDate)
            return (true, res, nil)
            
        case "get_reminders":
            let filterDate = parseDate(from: parameters["date"])
            let list = await ReminderTool.shared.fetchReminders(for: filterDate)
            let res = list.isEmpty ? "Напоминаний нет! Все чисто, можно отдыхать." : "Твои напоминания:\n• " + list.joined(separator: "\n• ")
            return (true, res, nil)
            
        case "create_calendar_event":
            let title = parameters["title"] ?? "Встреча"
            let start = parseDate(from: parameters["startDate"]) ?? Date().addingTimeInterval(3600)
            let end = parseDate(from: parameters["endDate"]) ?? start.addingTimeInterval(3600)
            let res = await CalendarTool.shared.createEvent(title: title, startDate: start, endDate: end)
            return (true, res, nil)
            
        case "get_calendar_events":
            let targetDate = parseDate(from: parameters["date"]) ?? Date()
            let events = await CalendarTool.shared.getEvents(for: targetDate)
            let res = events.isEmpty ? "В календаре на этот день ничего нет. Ты свободен!" : "Планы в календаре:\n• " + events.joined(separator: "\n• ")
            return (true, res, nil)
            
        case "create_note":
            let title = parameters["title"] ?? "Заметка от AiCat"
            let content = parameters["content"] ?? ""
            let res = await MainActor.run { NotesTool.shared.saveNote(title: title, content: content) }
            return (true, res, nil)
            
        case "search_notes":
            let q = parameters["query"] ?? ""
            let filtered = await MainActor.run { NotesTool.shared.searchNotes(query: q) }
            if filtered.isEmpty {
                return (true, "Заметок по запросу «\(q)» не нашлось.", nil)
            }
            let res = filtered.map { "📌 \($0.title):\n\($0.content)" }.joined(separator: "\n---\n")
            return (true, res, nil)
            
        case "search_knowledge_base":
            let q = parameters["query"] ?? ""
            let found = await MainActor.run { RAGTool.shared.searchKnowledge(query: q) }
            let res = found.isEmpty ? "В твоих проиндексированных документах ничего подходящего не нашлось." : "Вот что я нашел в твоих файлах:\n" + found
            return (true, res, nil)
            
        case "open_app":
            let appName = parameters["appName"] ?? ""
            let res = await AppLauncherTool.shared.openApp(named: appName)
            return (true, res, nil)
            
        case "device_action":
            let cmd = parameters["command"] ?? ""
            let res = await PhoneControlTool.shared.execute(command: cmd, value: parameters["value"] ?? "", detail: parameters["detail"] ?? "")
            return (true, res, nil)
            
        case "translate":
            let text = parameters["text"] ?? ""
            let target = parameters["targetLanguage"] ?? "английский"
            let translation = await ModelManager.shared.infer(prompt: text, system: "Переведи на \(target). Выведи только перевод.")
            return (true, translation, nil)
            
        case "analyze_photo":
            let action = parameters["action"] ?? "ocr"
            return (true, "Инструмент анализа фото готов к работе. Прикрепи изображение для \(action).", nil)
            
        case "generate_image":
            let prompt = parameters["prompt"] ?? "Киберпанк город будущего"
            let genRes = await ImageGenerationTool.shared.generateImageAsync(prompt: prompt)
            return (true, genRes.status, genRes.image)
            
        case "play_music":
            let style = parameters["style"] ?? "lo-fi"
            let res = await MusicTool.shared.generateBeat(style: style)
            return (true, res, nil)
            
        case "start_workout":
            let type = (parameters["workoutType"] ?? "pushups").lowercased()
            let res: String
            if type.contains("squat") || type.contains("присед") {
                res = await MainActor.run { CatFitnessCoach.shared.startSquats(reps: Int(parameters["reps"] ?? "") ?? 20) }
            } else if ["yoga", "breathing", "mobility", "plank"].contains(type) || type.contains("йог") {
                res = await MainActor.run { YogaCoachTool.shared.startWorkout(type: type) }
            } else {
                res = await MainActor.run { CatFitnessCoach.shared.startPushups(reps: Int(parameters["reps"] ?? "") ?? 15) }
            }
            return (true, res, nil)
            
        case "control_workout":
            let message = await MainActor.run { () -> String in
                guard YogaCoachTool.shared.isSessionActive || CatFitnessCoach.shared.isWorkoutActive else {
                    return "Сначала начни занятие, кожаный."
                }
                switch parameters["action"] ?? "pause" {
                case "resume": YogaCoachTool.shared.resume(); CatFitnessCoach.shared.resume()
                case "next": YogaCoachTool.shared.nextPose()
                case "rep": CatFitnessCoach.shared.manualRecordRep()
                case "stop":
                    CatFitnessCoach.shared.stopWorkout()
                    _ = YogaCoachTool.shared.stopWorkout()
                default: YogaCoachTool.shared.pause(); CatFitnessCoach.shared.pause()
                }
                if YogaCoachTool.shared.isSessionActive {
                    return "\(YogaCoachTool.shared.currentExercise.name). \(YogaCoachTool.shared.isPaused ? "Пауза" : "Продолжаем")"
                }
                if CatFitnessCoach.shared.isWorkoutActive {
                    return "\(CatFitnessCoach.shared.currentRepsCount)/\(CatFitnessCoach.shared.targetReps). \(CatFitnessCoach.shared.isPaused ? "Пауза" : "Продолжаем")"
                }
                return "Занятие остановлено."
            }
            return (true, message, nil)

        case "get_status":
            let (satiety, happiness, energy) = await MainActor.run {
                (TamagotchiManager.shared.satiety, TamagotchiManager.shared.happiness, TamagotchiManager.shared.energy)
            }
            let certDays = await MainActor.run { CertificateWatchdog.shared.daysRemaining }
            let isModel = await MainActor.run { ModelManager.shared.isModelLoaded }
            let res = """
            📊 СТАТУС AICAT:
            • Сытость: \(satiety)% 🐟
            • Счастье: \(happiness)% ❤️
            • Энергия: \(energy)% ⚡
            • До обновления сертификата: \(certDays) дн. ⏰
            • Модель GGUF: \(isModel ? "Активна (Metal)" : "Не установлена (Простой режим)")
            """
            return (true, res, nil)
            
        default:
            return (false, "Неизвестный инструмент: \(name)", nil)
        }
    }
    
    // Парсер дат из ISO8601 или относительных строк
    private func parseDate(from string: String?) -> Date? {
        guard let s = string?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        
        let lower = s.lowercased()
        if lower == "today" || lower == "сегодня" { return Date() }
        if lower == "tomorrow" || lower == "завтра" { return Calendar.current.date(byAdding: .day, value: 1, to: Date()) }
        
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) { return d }
        
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        let formats = ["yyyy-MM-dd", "yyyy-MM-dd HH:mm", "dd.MM.yyyy", "dd.MM.yyyy HH:mm", "yyyy-MM-dd'T'HH:mm:ssZ"]
        for f in formats {
            df.dateFormat = f
            if let d = df.date(from: s) { return d }
        }
        return nil
    }
}
