import Foundation
import EventKit

public final class ReminderTool {
    public static let shared = ReminderTool()
    private let eventStore = EKEventStore()
    
    private init() {}
    
    public func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await eventStore.requestFullAccessToReminders()
            } else {
                return try await eventStore.requestAccess(to: .reminder)
            }
        } catch {
            return false
        }
    }
    
    public func createReminder(title: String, dueDate: Date? = nil) async -> String {
        let granted = await requestAccess()
        guard granted else {
            return "Не удалось получить доступ к Напоминаниям. Разреши доступ в Настройки -> AiCat."
        }
        
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        if let dueDate = dueDate {
            let calendar = Calendar.current
            reminder.dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        }
        
        do {
            try eventStore.save(reminder, commit: true)
            var msg = "Записал напоминание: «\(title)»"
            if let dueDate = dueDate {
                let df = DateFormatter()
                df.locale = Locale(identifier: "ru_RU")
                df.dateStyle = .short
                df.timeStyle = .short
                msg += " на \(df.string(from: dueDate))"
            }
            msg += ". Не вздумай забыть, кожаный!"
            return msg
        } catch {
            return "Ошибка сохранения напоминания: \(error.localizedDescription)"
        }
    }
    
    // Получение напоминаний с фильтрацией по дате
    public func fetchReminders(for date: Date? = nil) async -> [String] {
        let granted = await requestAccess()
        guard granted else { return ["Нет доступа к напоминаниям."] }
        
        let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        
        let allReminders: [EKReminder] = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { list in
                continuation.resume(returning: list ?? [])
            }
        }
        
        if let filterDate = date {
            let calendar = Calendar.current
            let targetDay = calendar.startOfDay(for: filterDate)
            
            let filtered = allReminders.filter { reminder in
                guard let comps = reminder.dueDateComponents, let rDate = calendar.date(from: comps) else {
                    return false
                }
                return calendar.startOfDay(for: rDate) == targetDay
            }
            return filtered.map { $0.title ?? "Без названия" }
        } else {
            return allReminders.map { $0.title ?? "Без названия" }
        }
    }
    
    public func fetchTodayReminders() async -> [String] {
        return await fetchReminders(for: Date())
    }
}
