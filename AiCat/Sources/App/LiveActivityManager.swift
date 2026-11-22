import Foundation
import ActivityKit

public final class LiveActivityManager: ObservableObject {
    public static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<AiCatAttributes>?
    
    private init() {}
    
    // Запуск или переподключение к Live Activity
    public func startOrUpdateActivity(status: String = "AiCat на посту",
                                     mood: String = "😼",
                                     action: String = "Наблюдаю",
                                     isHanging: Bool = false) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let contentState = AiCatAttributes.ContentState(
            statusMessage: status,
            moodEmoji: mood,
            currentAction: action,
            isHanging: isHanging,
            isListening: false
        )
        
        // Если активность уже запущена — плавно обновляем её
        if let activity = currentActivity ?? Activity<AiCatAttributes>.activities.first {
            self.currentActivity = activity
            Task {
                await activity.update(.init(state: contentState, staleDate: nil))
            }
            return
        }
        
        // Закрываем старые зависшие активности перед стартом новой
        endAllActivities()
        
        let attributes = AiCatAttributes(catName: "AiCat")
        do {
            let activity = try Activity<AiCatAttributes>.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            self.currentActivity = activity
        } catch {
            print("Ошибка запуска Dynamic Island Live Activity: \(error.localizedDescription)")
        }
    }
    
    // Обновление состояния кота на Dynamic Island
    public func update(status: String, mood: String, action: String) {
        startOrUpdateActivity(status: status, mood: mood, action: action)
    }
    
    // Завершение всех активностей
    public func endAllActivities() {
        for activity in Activity<AiCatAttributes>.activities {
            Task {
                let emptyState: ActivityContent<AiCatAttributes.ContentState>? = nil
                await activity.end(emptyState, dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil
    }
}
