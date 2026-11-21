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
            return "Не удалось получить доступ к Напоминаниям. Проверь настройки конфиденциальности."
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
            return "Записал напоминание: «\(title)». Не вздумай забыть, кожаный!"
        } catch {
            return "Ошибка сохранения напоминания: \(error.localizedDescription)"
        }
    }
    
    public func fetchTodayReminders() async -> [String] {
        let granted = await requestAccess()
        guard granted else { return ["Нет доступа к напоминаниям."] }
        
        let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        
        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let titles = reminders?.map { $0.title ?? "Без названия" } ?? []
                continuation.resume(returning: titles)
            }
        }
    }
}
