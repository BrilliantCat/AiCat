import UIKit

public final class AppLauncherTool {
    public static let shared = AppLauncherTool()
    
    private init() {}
    
    // Список поддерживаемых системных и сторонних приложений
    private let appSchemes: [String: String] = [
        "telegram": "tg://",
        "телеграм": "tg://",
        "youtube": "youtube://",
        "ютуб": "youtube://",
        "whatsapp": "whatsapp://",
        "ватсап": "whatsapp://",
        "камера": "camera://",
        "camera": "camera://",
        "настройки": "App-Prefs:root=General",
        "settings": "App-Prefs:root=General",
        "музыка": "music://",
        "music": "music://",
        "карты": "maps://",
        "maps": "maps://",
        "калькулятор": "calculator://",
        "заметки": "mobilenotes://"
    ]
    
    @MainActor
    public func openApp(named: String) async -> String {
        let cleanName = named.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if ["camera", "камера"].contains(cleanName) {
            return await PhoneControlTool.shared.execute(command: "camera")
        }
        if ["settings", "настройки"].contains(cleanName) {
            return await PhoneControlTool.shared.execute(command: "settings")
        }
        guard let scheme = appSchemes[cleanName] ?? appSchemes.first(where: { cleanName.contains($0.key) })?.value,
              let url = URL(string: scheme) else {
            return "Не смог найти приложение «\(named)». Возможно, у него нет системной URL-схемы."
        }
        
        let opened = await UIApplication.shared.open(url, options: [:])
        return opened ? "Открыл «\(named)»." : "iOS не смогла открыть «\(named)»."
    }
}
