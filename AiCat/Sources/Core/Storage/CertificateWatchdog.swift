import Foundation
import UserNotifications

public final class CertificateWatchdog: ObservableObject {
    public static let shared = CertificateWatchdog()
    
    @Published public var daysRemaining: Int = 7
    @Published public var needsRenewal: Bool = false
    
    private let installDateKey = "AiCat_InstallationDate"
    
    private init() {
        checkCertificateStatus()
    }
    
    public func checkCertificateStatus() {
        let defaults = UserDefaults.standard
        let installDate: Date
        
        if let savedDate = defaults.object(forKey: installDateKey) as? Date {
            installDate = savedDate
        } else {
            installDate = Date()
            defaults.set(installDate, forKey: installDateKey)
        }
        
        let elapsedDays = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
        let remaining = max(0, 7 - elapsedDays)
        
        DispatchQueue.main.async {
            self.daysRemaining = remaining
            self.needsRenewal = (remaining <= 2)
            
            if self.needsRenewal {
                self.notifyUser()
            }
        }
    }
    
    // Сброс таймера на 7 дней после успешного обновления через Sideloadly/SideStore
    public func resetAfterRefresh() {
        UserDefaults.standard.set(Date(), forKey: installDateKey)
        checkCertificateStatus()
    }
    
    private func notifyUser() {
        CatActionHandler.shared.state.moodEmoji = "⏰"
        CatActionHandler.shared.state.statusText = "Сертификат: осталось \(daysRemaining) дн."
    }
    
    // Подробная пошаговая инструкция кота
    public var instructionsText: String {
        return """
        🐱 ИНСТРУКЦИЯ ОТ AICAT: КАК ОБНОВИТЬ СЕРТИФИКАТ ЗА 1 МИНУТУ
        
        Apple дает бесплатным аккаунтам 7 дней на работу приложения. Чтобы я не отключился:
        
        ВАРИАНТ 1 (Самый простой — через Wi-Fi):
        1. Включи компьютер с Sideloadly (убедись, что iPhone и ПК в одной Wi-Fi сети).
        2. Sideloadly сам автоматически обновит сертификат по воздуху!
        
        ВАРИАНТ 2 (По кабелю):
        1. Подключи iPhone к компьютеру через обычный кабель.
        2. Открой Sideloadly на ПК и нажми кнопку «Start» (перетащив AiCat.ipa).
        3. Все данные, твои заметки и модель сохранятся, а таймер сбросится на новые 7 дней!
        """
    }
}
