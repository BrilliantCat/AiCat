import SwiftUI
import ActivityKit

@main
struct AiCatApp: App {
    @StateObject private var speechRecognizer = OfflineSpeechRecognizer.shared
    @StateObject private var speechSynthesizer = CatSpeechSynthesizer.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .onAppear {
                    // Запуск разрешений и Dynamic Island с мягкой задержкой после отрисовки экрана
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        speechRecognizer.requestPermissions { _ in }
                        startDynamicIslandActivity()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WakeAiCatTriggered"))) { _ in
                    // Срабатывает при тройном постукивании по крышке телефона
                    try? speechRecognizer.startListening()
                }
        }
    }
    
    // Запуск постоянного присутствия котика в Dynamic Island
    private func startDynamicIslandActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let initialAttributes = AiCatAttributes(catName: "AiCat")
        let initialContentState = AiCatAttributes.ContentState(
            statusMessage: "AiCat онлайн. Живу в A17 Pro.",
            moodEmoji: "😼",
            currentAction: "Наблюдаю за тобой",
            isHanging: false,
            isListening: false
        )
        
        do {
            _ = try Activity<AiCatAttributes>.request(
                attributes: initialAttributes,
                content: .init(state: initialContentState, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("Ошибка запуска Live Activity: \(error.localizedDescription)")
        }
    }
}
