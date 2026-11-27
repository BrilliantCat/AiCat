import Combine
import Foundation
import ActivityKit
import WidgetKit
import UIKit

@MainActor
public final class LiveActivityManager: ObservableObject {
    public static let shared = LiveActivityManager()
    
    @Published public private(set) var islandStatus = "Остров ещё не запущен"
    
    private init() {}
    private var pendingUpdate: Task<Void, Never>?

    func finishPendingUpdate() async {
        await pendingUpdate?.value
    }
    
    // Запуск или переподключение к Live Activity
    public func startOrUpdateActivity(status: String = "AiCat на посту",
                                     mood: String = "😼",
                                     action: String = "Наблюдаю",
                                     isHanging: Bool = false,
                                     recordAction: Bool = true) {
        if recordAction {
            var snapshot = CatSnapshot.load().projected(at: Date())
            snapshot.action = CatSnapshot.scene(mood: mood)
            snapshot.actionUntil = Date().addingTimeInterval(mood == "💤" ? 3600 : 120)
            snapshot.save()
            WidgetCenter.shared.reloadTimelines(ofKind: "AiCatHomeScreenWidget")
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            islandStatus = "Live Activities отключены в настройках iOS"
            return
        }
        
        var contentState = AiCatAttributes.ContentState(
            statusMessage: status,
            moodEmoji: mood,
            currentAction: action,
            isHanging: isHanging,
            isListening: false
        )
        
        contentState.outfit = CatSnapshot.load().outfit
        let now = Date()
        contentState.quoteDay = DailySaying.index(now)
        let nextMidnight = Calendar.current.dateInterval(of: .day, for: now)?.end ?? now.addingTimeInterval(86400)
        let nextTick = Date(timeIntervalSince1970: (floor(now.timeIntervalSince1970 / 900) + 1) * 900)
        let until = CatSnapshot.load().actionUntil
        let content = ActivityContent(state: contentState, staleDate: min(nextMidnight, until > now ? until : nextTick))

        // Если активность уже запущена — плавно обновляем её
        let active = Activity<AiCatAttributes>.activities.first {
            $0.activityState == .active || $0.activityState == .stale
        }
        if let activity = active {
            islandStatus = "Кот в острове"
            let previous = pendingUpdate
            pendingUpdate = Task {
                await previous?.value
                await activity.update(content)
            }
            return
        }
        
        guard UIApplication.shared.applicationState == .active else {
            islandStatus = "Открой AiCat, чтобы запустить остров"
            return
        }
        let attributes = AiCatAttributes(catName: "AiCat")
        do {
            _ = try Activity<AiCatAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            islandStatus = "Кот в острове"
        } catch {
            islandStatus = "Не удалось запустить остров: \(error.localizedDescription)"
            DebugLogger.shared.log(islandStatus, level: .warn, tag: "Island")
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
        islandStatus = "Остров завершён"
    }
}
