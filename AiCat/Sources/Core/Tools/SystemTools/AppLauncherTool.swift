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
        "музыка": "music://",
        "music": "music://",
        "карты": "maps://",
        "maps": "maps://",
        "calculator": "calculator://",
        "калькулятор": "calculator://",
        "notes": "mobilenotes://",
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
        guard let scheme = appSchemes[cleanName],
              let url = URL(string: scheme) else {
            return "Для «\(named)» создай в «Командах» сценарий с действием «Открыть приложение» и привяжи к нему фразу в AiCat → Телефон."
        }
        
        let opened = await UIApplication.shared.open(url, options: [:])
        return opened ? "Открыл «\(named)»." : "iOS не смогла открыть «\(named)»."
    }
}
