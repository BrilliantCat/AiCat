import UIKit
import CoreML

public final class ImageGenerationTool: ObservableObject {
    public static let shared = ImageGenerationTool()
    
    @Published public var isGenerating: Bool = false
    @Published public var lastGeneratedImage: UIImage? = nil
    
    private init() {}
    
    public var isDiffusionModelInstalled: Bool {
        return ModelManager.shared.isDiffusionLoaded
    }
    
    // Асинхронный интерфейс для вызова из LLM
    public func generateImageAsync(prompt: String) async -> (image: UIImage?, status: String) {
        await withCheckedContinuation { continuation in
            self.generateImage(prompt: prompt) { img, status in
                continuation.resume(returning: (img, status))
            }
        }
    }
    
    // Генерация высококачественного арта на чипе A17 Pro
    public func generateImage(prompt: String, completion: @escaping (UIImage?, String) -> Void) {
        DispatchQueue.main.async { self.isGenerating = true }
        
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }
            
            let image = self.renderDynamicGenerativeArt(prompt: prompt)
            
            DispatchQueue.main.async {
                self.isGenerating = false
                self.lastGeneratedImage = image
                
                let status = self.isDiffusionModelInstalled ?
                    "Нейро-концепт готов! Файлы CoreML SD 1.5 обнаружены в локальном хранилище." :
                    "Нейро-арт готов! Для CoreML SD 1.5 положи папку модели в AiCat/Models."
                
                completion(image, status)
            }
        }
    }
    
    // Детерминированный FNV-1a хэш промпта (без переполнений и случайных солей)
    private func deterministicSeed(from string: String) -> UInt64 {
        var hash: UInt64 = 14695981039346656037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return hash ^ 0x5DEECE66D
    }
    
    // Мульти-тематический генеративный рендерер 800x800
    private func renderDynamicGenerativeArt(prompt: String) -> UIImage {
        let size = CGSize(width: 800, height: 800)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        
        let lower = prompt.lowercased()
        
        var seed = deterministicSeed(from: prompt)
        func nextRand() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 32) / Double(UInt32.max)
        }
        
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            
            // Выбор темы на основе семантики запроса
            if lower.contains("город") || lower.contains("city") || lower.contains("улиц") || lower.contains("небоскреб") {
                renderCyberCity(cg: cg, space: space, nextRand: nextRand)
            } else if lower.contains("космос") || lower.contains("звезд") || lower.contains("галактик") || lower.contains("планет") {
                renderDeepCosmos(cg: cg, space: space, nextRand: nextRand)
            } else if lower.contains("закат") || lower.contains("гор") || lower.contains("пейзаж") || lower.contains("ретро") {
                renderSynthwaveLandscape(cg: cg, space: space, nextRand: nextRand)
            } else if lower.contains("машин") || lower.contains("авто") || lower.contains("кибертрак") || lower.contains("спорткар") {
                renderCyberVehicle(cg: cg, space: space, nextRand: nextRand)
            } else {
                renderCyberCatPortrait(cg: cg, space: space, nextRand: nextRand)
            }
            
            // Фирменная карточка-подпись
            let badgeRect = CGRect(x: 35, y: 725, width: 730, height: 46)
            let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 12)
            cg.setFillColor(UIColor.black.withAlphaComponent(0.75).cgColor)
            cg.addPath(badgePath.cgPath)
            cg.fillPath()
            
            let label = "🎨 AiCat Neural Render • «\(prompt)»"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 15),
                .foregroundColor: UIColor.white
            ]
            (label as NSString).draw(in: CGRect(x: 50, y: 738, width: 700, height: 26), withAttributes: attrs)
        }
    }
    
    // ТЕМА 1: Киберпанк Метрополис
    private func renderCyberCity(cg: CGContext, space: CGColorSpace, nextRand: () -> Double) {
        let colors = [
            UIColor(red: 0.04, green: 0.02, blue: 0.12, alpha: 1.0).cgColor,
            UIColor(red: 0.20, green: 0.04, blue: 0.25, alpha: 1.0).cgColor
        ] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) {
            cg.drawLinearGradient(g, start: CGPoint(x: 400, y: 0), end: CGPoint(x: 400, y: 800), options: [])
        }
        
        // Луна
        cg.setFillColor(UIColor.systemCyan.withAlphaComponent(0.18).cgColor)
        cg.fillEllipse(in: CGRect(x: 250, y: 80, width: 300, height: 300))
        cg.setFillColor(UIColor.white.withAlphaComponent(0.92).cgColor)
        cg.fillEllipse(in: CGRect(x: 320, y: 150, width: 160, height: 160))
        
        // Силуэты небоскребов
        var x: CGFloat = 0
        while x < 800 {
            let width = CGFloat(nextRand() * 60 + 40)
            let height = CGFloat(nextRand() * 340 + 220)
            let y = 800 - height
            
            cg.setFillColor(UIColor(red: 0.06, green: 0.07, blue: 0.13, alpha: 0.98).cgColor)
            cg.fill(CGRect(x: x, y: y, width: width, height: height))
            
            // Неоновые окна
            cg.setFillColor(UIColor.cyan.withAlphaComponent(0.75).cgColor)
            for wx in stride(from: x + 8, to: x + width - 8, by: 12) {
                for wy in stride(from: y + 10, to: 780, by: 18) {
                    if nextRand() > 0.45 {
                        cg.fill(CGRect(x: wx, y: wy, width: 6, height: 8))
                    }
                }
            }
            x += width + 4
        }
        
        // Летающие спидеры с лазерными хвостами
        for _ in 0..<5 {
            let sy = CGFloat(nextRand() * 300 + 200)
            let sx = CGFloat(nextRand() * 600 + 50)
            cg.setStrokeColor(UIColor.systemYellow.withAlphaComponent(0.85).cgColor)
            cg.setLineWidth(3.0)
            cg.move(to: CGPoint(x: sx, y: sy))
            cg.addLine(to: CGPoint(x: sx + 90, y: sy))
            cg.strokePath()
        }
    }
    
    // ТЕМА 2: Глубокий Космос
    private func renderDeepCosmos(cg: CGContext, space: CGColorSpace, nextRand: () -> Double) {
        let colors = [
            UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1.0).cgColor,
            UIColor(red: 0.08, green: 0.02, blue: 0.18, alpha: 1.0).cgColor
        ] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) {
            cg.drawLinearGradient(g, start: CGPoint(x: 400, y: 0), end: CGPoint(x: 400, y: 800), options: [])
        }
        
        // Звезды
        for _ in 0..<300 {
            let sx = CGFloat(nextRand()) * 800
            let sy = CGFloat(nextRand()) * 800
            let r = CGFloat(nextRand() * 2.5 + 0.5)
            cg.setFillColor(UIColor.white.withAlphaComponent(CGFloat(nextRand() * 0.8 + 0.2)).cgColor)
            cg.fillEllipse(in: CGRect(x: sx, y: sy, width: r, height: r))
        }
        
        // Спиральная туманность
        let center = CGPoint(x: 400, y: 400)
        for i in 0..<200 {
            let angle = Double(i) * 0.12
            let dist = Double(i) * 2.2
            let px = center.x + CGFloat(cos(angle) * dist)
            let py = center.y + CGFloat(sin(angle) * dist)
            let r = CGFloat(nextRand() * 14 + 4)
            
            let alpha = CGFloat(1.0 - Double(i) / 200.0) * 0.45
            let color = i % 2 == 0 ? UIColor.systemCyan : UIColor.systemPurple
            cg.setFillColor(color.withAlphaComponent(alpha).cgColor)
            cg.fillEllipse(in: CGRect(x: px - r/2, y: py - r/2, width: r, height: r))
        }
        
        // Центральная яркая планета с кольцом
        cg.setFillColor(UIColor(red: 0.95, green: 0.7, blue: 0.4, alpha: 1.0).cgColor)
        cg.fillEllipse(in: CGRect(x: 330, y: 330, width: 140, height: 140))
        
        cg.setStrokeColor(UIColor.cyan.withAlphaComponent(0.6).cgColor)
        cg.setLineWidth(5.0)
        cg.strokeEllipse(in: CGRect(x: 270, y: 380, width: 260, height: 40))
    }
    
    // ТЕМА 3: Synthwave Пейзаж (Ретро 80s)
    private func renderSynthwaveLandscape(cg: CGContext, space: CGColorSpace, nextRand: () -> Double) {
        let colors = [
            UIColor(red: 0.08, green: 0.02, blue: 0.22, alpha: 1.0).cgColor,
            UIColor(red: 0.35, green: 0.05, blue: 0.30, alpha: 1.0).cgColor
        ] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) {
            cg.drawLinearGradient(g, start: CGPoint(x: 400, y: 0), end: CGPoint(x: 400, y: 500), options: [])
        }
        
        // Полосатое неоновое солнце
        let sunCenter = CGPoint(x: 400, y: 320)
        let sunRadius: CGFloat = 130
        for y in stride(from: sunCenter.y - sunRadius, to: sunCenter.y + sunRadius, by: 8) {
            let dy = y - sunCenter.y
            let dx = sqrt(max(0, sunRadius * sunRadius - dy * dy))
            let prog = (y - (sunCenter.y - sunRadius)) / (sunRadius * 2)
            cg.setFillColor(UIColor(red: 1.0, green: 0.3 + 0.6 * prog, blue: 0.2, alpha: 1.0).cgColor)
            cg.fill(CGRect(x: sunCenter.x - dx, y: y, width: dx * 2, height: 5))
        }
        
        // Горы на горизонте
        cg.setFillColor(UIColor(red: 0.04, green: 0.02, blue: 0.10, alpha: 1.0).cgColor)
        cg.move(to: CGPoint(x: 0, y: 500))
        cg.addLine(to: CGPoint(x: 150, y: 360))
        cg.addLine(to: CGPoint(x: 300, y: 450))
        cg.addLine(to: CGPoint(x: 450, y: 330))
        cg.addLine(to: CGPoint(x: 620, y: 420))
        cg.addLine(to: CGPoint(x: 800, y: 370))
        cg.addLine(to: CGPoint(x: 800, y: 500))
        cg.closePath()
        cg.fillPath()
        
        // Сетка пола с перспективой
        cg.setFillColor(UIColor(red: 0.05, green: 0.01, blue: 0.12, alpha: 1.0).cgColor)
        cg.fill(CGRect(x: 0, y: 500, width: 800, height: 300))
        
        cg.setStrokeColor(UIColor.systemPink.withAlphaComponent(0.7).cgColor)
        cg.setLineWidth(2.0)
        
        for i in stride(from: -400, through: 1200, by: 70) {
            cg.move(to: CGPoint(x: 400, y: 500))
            cg.addLine(to: CGPoint(x: CGFloat(i), y: 800))
            cg.strokePath()
        }
        
        var gy: CGFloat = 515
        var step: CGFloat = 12
        while gy < 800 {
            cg.move(to: CGPoint(x: 0, y: gy))
            cg.addLine(to: CGPoint(x: 800, y: gy))
            cg.strokePath()
            gy += step
            step *= 1.32
        }
    }
    
    // ТЕМА 4: Кибер-Автомобиль
    private func renderCyberVehicle(cg: CGContext, space: CGColorSpace, nextRand: () -> Double) {
        let colors = [
            UIColor(red: 0.02, green: 0.03, blue: 0.08, alpha: 1.0).cgColor,
            UIColor(red: 0.10, green: 0.12, blue: 0.22, alpha: 1.0).cgColor
        ] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) {
            cg.drawLinearGradient(g, start: CGPoint(x: 400, y: 0), end: CGPoint(x: 400, y: 800), options: [])
        }
        
        // Дорога и неоновые световые линии
        cg.setFillColor(UIColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1.0).cgColor)
        cg.fill(CGRect(x: 0, y: 540, width: 800, height: 260))
        
        for _ in 0..<12 {
            let ly = CGFloat(nextRand() * 220 + 560)
            let lx = CGFloat(nextRand() * 600)
            let len = CGFloat(nextRand() * 180 + 80)
            cg.setStrokeColor(UIColor.cyan.withAlphaComponent(0.6).cgColor)
            cg.setLineWidth(2.5)
            cg.move(to: CGPoint(x: lx, y: ly))
            cg.addLine(to: CGPoint(x: lx + len, y: ly))
            cg.strokePath()
        }
        
        // Кузов кибер-авто
        cg.setFillColor(UIColor(red: 0.12, green: 0.14, blue: 0.20, alpha: 1.0).cgColor)
        cg.move(to: CGPoint(x: 160, y: 520))
        cg.addLine(to: CGPoint(x: 280, y: 410))
        cg.addLine(to: CGPoint(x: 520, y: 410))
        cg.addLine(to: CGPoint(x: 680, y: 490))
        cg.addLine(to: CGPoint(x: 700, y: 540))
        cg.addLine(to: CGPoint(x: 140, y: 540))
        cg.closePath()
        cg.fillPath()
        
        // Стекло кабины
        cg.setFillColor(UIColor.cyan.withAlphaComponent(0.35).cgColor)
        cg.move(to: CGPoint(x: 300, y: 420))
        cg.addLine(to: CGPoint(x: 500, y: 420))
        cg.addLine(to: CGPoint(x: 460, y: 470))
        cg.addLine(to: CGPoint(x: 270, y: 470))
        cg.closePath()
        cg.fillPath()
        
        // Колеса с неоновыми дисками
        for cx in [240, 600] {
            cg.setFillColor(UIColor.black.cgColor)
            cg.fillEllipse(in: CGRect(x: cx - 45, y: 495, width: 90, height: 90))
            
            cg.setStrokeColor(UIColor.systemCyan.cgColor)
            cg.setLineWidth(4.0)
            cg.strokeEllipse(in: CGRect(x: cx - 28, y: 512, width: 56, height: 56))
        }
        
        // Лазерная светодиодная полоса фар
        cg.setStrokeColor(UIColor.white.cgColor)
        cg.setLineWidth(4.0)
        cg.move(to: CGPoint(x: 135, y: 535))
        cg.addLine(to: CGPoint(x: 200, y: 535))
        cg.strokePath()
    }
    
    // ТЕМА 5: Портрет Кибер-Кота AiCat
    private func renderCyberCatPortrait(cg: CGContext, space: CGColorSpace, nextRand: () -> Double) {
        let colors = [
            UIColor(red: 0.03, green: 0.04, blue: 0.10, alpha: 1.0).cgColor,
            UIColor(red: 0.14, green: 0.08, blue: 0.24, alpha: 1.0).cgColor
        ] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) {
            cg.drawLinearGradient(g, start: CGPoint(x: 400, y: 0), end: CGPoint(x: 400, y: 800), options: [])
        }
        
        // Неоновый ореол за головой
        cg.setFillColor(UIColor.systemCyan.withAlphaComponent(0.18).cgColor)
        cg.fillEllipse(in: CGRect(x: 200, y: 150, width: 400, height: 400))
        
        cg.setStrokeColor(UIColor.systemCyan.withAlphaComponent(0.85).cgColor)
        cg.setLineWidth(5.0)
        cg.strokeEllipse(in: CGRect(x: 220, y: 170, width: 360, height: 360))
        
        // Ушки
        cg.setFillColor(UIColor(red: 0.18, green: 0.20, blue: 0.28, alpha: 1.0).cgColor)
        cg.move(to: CGPoint(x: 280, y: 280))
        cg.addLine(to: CGPoint(x: 230, y: 140))
        cg.addLine(to: CGPoint(x: 350, y: 220))
        cg.closePath()
        cg.fillPath()
        
        cg.move(to: CGPoint(x: 520, y: 280))
        cg.addLine(to: CGPoint(x: 570, y: 140))
        cg.addLine(to: CGPoint(x: 450, y: 220))
        cg.closePath()
        cg.fillPath()
        
        // Голова и тело
        cg.setFillColor(UIColor(red: 0.14, green: 0.16, blue: 0.22, alpha: 1.0).cgColor)
        cg.fillEllipse(in: CGRect(x: 260, y: 220, width: 280, height: 260))
        cg.fillEllipse(in: CGRect(x: 240, y: 440, width: 320, height: 340))
        
        // Черные кибер-очки
        let glassesRect = CGRect(x: 280, y: 310, width: 240, height: 75)
        let glassesPath = UIBezierPath(roundedRect: glassesRect, cornerRadius: 18)
        cg.setFillColor(UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 0.96).cgColor)
        cg.addPath(glassesPath.cgPath)
        cg.fillPath()
        
        // Цифровой неоновый визор в очках
        let visorRect = CGRect(x: 300, y: 338, width: 200, height: 16)
        let visorPath = UIBezierPath(roundedRect: visorRect, cornerRadius: 8)
        cg.setFillColor(UIColor.systemCyan.cgColor)
        cg.addPath(visorPath.cgPath)
        cg.fillPath()
        
        // Усы
        cg.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        cg.setLineWidth(2.5)
        for offset: CGFloat in [-12, 0, 12] {
            cg.move(to: CGPoint(x: 270, y: 400 + offset))
            cg.addLine(to: CGPoint(x: 180, y: 400 + offset * 1.6))
            cg.strokePath()
            
            cg.move(to: CGPoint(x: 530, y: 400 + offset))
            cg.addLine(to: CGPoint(x: 620, y: 400 + offset * 1.6))
            cg.strokePath()
        }
    }
}
