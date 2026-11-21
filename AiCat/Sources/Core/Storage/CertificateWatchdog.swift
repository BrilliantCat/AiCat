import Foundation

public final class CertificateWatchdog: ObservableObject {
    public static let shared = CertificateWatchdog()
    
    @Published public var daysRemaining: Int = 7
    @Published public var needsRenewal: Bool = false
    @Published public var expirationDateString: String = ""
    
    private init() {
        checkCertificateStatus()
    }
    
    public func checkCertificateStatus() {
        // 1. Пытаемся прочитать точную дату истечения из реального embedded.mobileprovision
        if let expDate = extractExpirationFromProvisioning() {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day], from: Date(), to: expDate)
            let remaining = max(0, components.day ?? 0)
            
            let df = DateFormatter()
            df.locale = Locale(identifier: "ru_RU")
            df.dateStyle = .medium
            df.timeStyle = .short
            
            DispatchQueue.main.async {
                self.daysRemaining = remaining
                self.needsRenewal = (remaining <= 2)
                self.expirationDateString = df.string(from: expDate)
                if self.needsRenewal {
                    self.notifyUser()
                }
            }
            return
        }
        
        // 2. Фолбэк на дату установки файла Bundle.main
        let bundleDate = (try? FileManager.default.attributesOfItem(atPath: Bundle.main.bundlePath)[.creationDate] as? Date) ?? Date()
        let elapsed = Calendar.current.dateComponents([.day], from: bundleDate, to: Date()).day ?? 0
        let remaining = max(0, 7 - elapsed)
        
        DispatchQueue.main.async {
            self.daysRemaining = remaining
            self.needsRenewal = (remaining <= 2)
            if self.needsRenewal {
                self.notifyUser()
            }
        }
    }
    
    private func extractExpirationFromProvisioning() -> Date? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") ??
                        Bundle.main.bundleURL.appendingPathComponent("embedded.mobileprovision") as URL?,
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .ascii) else {
            return nil
        }
        
        // Ищем тег <key>ExpirationDate</key><date>...</date>
        guard let regex = try? NSRegularExpression(pattern: "<key>ExpirationDate</key>\\s*<date>([^<]+)</date>", options: []) else {
            return nil
        }
        
        let nsText = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        
        if let match = results.first, match.numberOfRanges > 1 {
            let dateStr = nsText.substring(with: match.range(at: 1))
            let isoFormatter = ISO8601DateFormatter()
            return isoFormatter.date(from: dateStr)
        }
        
        return nil
    }
    
    private func notifyUser() {
        CatActionHandler.shared.state.moodEmoji = "⏰"
        CatActionHandler.shared.state.statusText = "Сертификат: осталось \(daysRemaining) дн."
    }
    
    public var instructionsText: String {
        return """
        🐱 ИНСТРУКЦИЯ ОТ AICAT: ОБНОВЛЕНИЕ СЕРТИФИКАТА
        
        Бесплатный сертификат Apple действует 7 дней.
        Осталось дней: \(daysRemaining) (до \(expirationDateString)).
        
        КАК ОБНОВИТЬ:
        1. Включи компьютер с iloader / SideStore.
        2. Нажми 'Обновить сертификаты' по Wi-Fi или через кабель.
        3. Приложение автоматически продлится еще на 7 дней без потери данных!
        """
    }
}
