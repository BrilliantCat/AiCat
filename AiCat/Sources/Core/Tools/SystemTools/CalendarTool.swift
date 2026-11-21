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
    
    public func createEvent(title: String, startDate: Date, endDate: Date) async -> String {
        let granted = await requestAccess()
        guard granted else { return "Нет доступа к Календарю." }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return "Добавил в календарь: «\(title)». Твое время под моим присмотром."
        } catch {
            return "Ошибка при создании события: \(error.localizedDescription)"
        }
    }
    
    public func getTodayEvents() async -> [String] {
        let granted = await requestAccess()
        guard granted else { return ["Нет доступа к календарю."] }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        return events.map { "\(formatter.string(from: $0.startDate)) — \($0.title ?? "Событие")" }
    }
}
