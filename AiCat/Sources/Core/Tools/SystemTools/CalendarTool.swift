import Foundation
import EventKit

public final class CalendarTool {
    public static let shared = CalendarTool()
    private let eventStore = EKEventStore()
    
    private init() {}
    
    public func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await eventStore.requestFullAccessToEvents()
            } else {
                return try await eventStore.requestAccess(to: .event)
            }
        } catch {
            return false
        }
    }
    
    // Создание события календаря с поддержкой ISO8601 дат
    public func createEvent(title: String, startDate: Date, endDate: Date) async -> String {
        let granted = await requestAccess()
        guard granted else { return "Нет доступа к Календарю. Разреши доступ в Настройки -> AiCat." }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            let df = DateFormatter()
            df.locale = Locale(identifier: "ru_RU")
            df.dateStyle = .short
            df.timeStyle = .short
            return "Добавил в календарь: «\(title)» на \(df.string(from: startDate)). Твое время под моим присмотром!"
        } catch {
            return "Ошибка при создании события: \(error.localizedDescription)"
        }
    }
    
    // Получение событий на конкретную дату (или сегодня по умолчанию)
    public func getEvents(for date: Date = Date()) async -> [String] {
        let granted = await requestAccess()
        guard granted else { return ["Нет доступа к календарю."] }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        
        return events.map { "\(formatter.string(from: $0.startDate)) — \($0.title ?? "Событие")" }
    }
    
    public func getTodayEvents() async -> [String] {
        return await getEvents(for: Date())
    }
}
