import SwiftUI
import ActivityKit

@main
struct AiCatApp: App {
    @StateObject private var speechRecognizer = OfflineSpeechRecognizer.shared
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        createAppDirectories()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        LiveActivityManager.shared.startOrUpdateActivity()
                        checkBackTapLaunch()
                    }
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        checkBackTapLaunch()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WakeAiCatTriggered"))) { _ in
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
                try? speechRecognizer.startListening()
            }
        }
    }
}
