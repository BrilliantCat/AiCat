import SwiftUI
import ActivityKit

@main
struct AiCatApp: App {
    @StateObject private var speechRecognizer = OfflineSpeechRecognizer.shared
    private let lifeTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        createAppDirectories()
        _ = PhoneControlTool.shared
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(.dark)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        TamagotchiManager.shared.loadStateAndApplyDecay()
                        let cat = CatSnapshot.load().projected(at: Date())
                        LiveActivityManager.shared.startOrUpdateActivity(status: cat.label, mood: cat.mood, action: cat.label, recordAction: false)
                        checkBackTapLaunch()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase != .active {
                        YogaCoachTool.shared.pause()
                        CatFitnessCoach.shared.pause()
                    }
                    if newPhase == .active {
                        TamagotchiManager.shared.loadStateAndApplyDecay()
                        let cat = CatSnapshot.load().projected(at: Date())
                        LiveActivityManager.shared.startOrUpdateActivity(status: cat.label, mood: cat.mood, action: cat.label, recordAction: false)
                        checkBackTapLaunch()
                    }
                }
                .onReceive(lifeTimer) { _ in
                    if scenePhase == .active && !YogaCoachTool.shared.isSessionActive && !CatFitnessCoach.shared.isWorkoutActive {
                        TamagotchiManager.shared.refreshAutonomousLife()
                    }
                }
                .onOpenURL { url in
                    if url.scheme == "aicat" { TamagotchiManager.shared.loadStateAndApplyDecay() }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WakeAiCatTriggered"))) { _ in
                    UserDefaults.standard.set(false, forKey: "startListeningOnLaunch")
                    triggerVoiceListening()
                }
        }
    }
    
    // Создаем папки Models и sd_coreml в Documents, чтобы они были видны в приложении "Файлы"
    private func createAppDirectories() {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let modelsDir = docs.appendingPathComponent("Models")
        let sdDir = modelsDir.appendingPathComponent("sd_coreml")
        let imagesDir = docs.appendingPathComponent("Images")
        
        try? fm.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: sdDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)
    }
    
    private func checkBackTapLaunch() {
        if UserDefaults.standard.bool(forKey: "startListeningOnLaunch") {
            UserDefaults.standard.set(false, forKey: "startListeningOnLaunch")
            triggerVoiceListening()
        }
    }
    
    private func triggerVoiceListening() {
        speechRecognizer.requestPermissions { granted in
            if granted {
                do { try speechRecognizer.startListening() }
                catch { speechRecognizer.errorMessage = error.localizedDescription }
            }
        }
    }
}
