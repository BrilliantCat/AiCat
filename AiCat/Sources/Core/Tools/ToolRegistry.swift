import Foundation

public struct ToolCallPayload: Codable {
    public let thought: String?
    public let tool: String
    public let parameters: [String: String]?
    public let reply_text: String?
}

public final class ToolRegistry {
    public static let shared = ToolRegistry()
    
    private init() {}
    
    public func executeToolCall(jsonString: String) async -> (executed: Bool, catReply: String) {
        guard let data = jsonString.data(using: .utf8),
              let payload = try? JSONDecoder().decode(ToolCallPayload.self, from: data) else {
            return (false, jsonString)
        }
        
        var actionResult = ""
        
        switch payload.tool {
        case "cat_action":
            let action = payload.parameters?["action"] ?? "idle"
            let item = payload.parameters?["item"]
            actionResult = CatActionHandler.shared.execute(action: action, item: item)
            
        case "create_reminder":
            let title = payload.parameters?["title"] ?? "Новая задача"
            actionResult = await ReminderTool.shared.createReminder(title: title)
            
        case "get_reminders":
            let list = await ReminderTool.shared.fetchTodayReminders()
            actionResult = list.isEmpty ? "Напоминаний нет. Можно подремать!" : "Твои напоминания:\n" + list.joined(separator: "\n• ")
            
        case "get_calendar_events":
            let events = await CalendarTool.shared.getTodayEvents()
            actionResult = events.isEmpty ? "Сегодня никаких встреч. Ты свободен!" : "Планы на сегодня:\n" + events.joined(separator: "\n")
            
        case "create_note":
            let title = payload.parameters?["title"] ?? "Заметка"
            let content = payload.parameters?["content"] ?? ""
            actionResult = NotesTool.shared.saveNote(title: title, content: content)
            
        case "search_knowledge_base":
            let q = payload.parameters?["query"] ?? ""
            let found = RAGTool.shared.searchKnowledge(query: q)
            actionResult = found.isEmpty ? "В твоих документах ничего похожего не нашел." : "Вот что я раскопал в твоих файлах:\n" + found
            
        default:
            actionResult = "Инструмент '\(payload.tool)' выполнен."
        }
        
        let finalReply = payload.reply_text ?? actionResult
        return (true, finalReply)
    }
}
