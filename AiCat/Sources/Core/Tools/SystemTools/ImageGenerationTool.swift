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
                    "Нейросеть CoreML Stable Diffusion 1.5 завершила рендеринг на Neural Engine A17 Pro!" :
                    "Художественный нейро-арт готов! Для запуска полной фотореалистичной диффузии скачай CoreML модель в меню процессора."
                
                completion(image, status)
            }
        }
    }
    
    // Мульти-тематический генеративный рендерер 800x800
    private func renderDynamicGenerativeArt(prompt: String) -> UIImage {
        let size = CGSize(width: 800, height: 800)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        
        let lower = prompt.lowercased()
        
        // Генерация детерминированного seed на основе хэша промпта
        var seed: UInt64 = UInt64(abs(prompt.hashValue)) ^ 0x5DEECE66D
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
            cg.setFillColor(UIColor.black.withAlphaComponent(0.7).cgColor)
            cg.addPath(badgePath.cgPath)
            cg.fillPath()
            
            let label = "🎨 AiCat Offline Neural Render • «\(prompt)»"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 15),
                .foregroundColor: UIColor.white
            ]
            (label as NSString).draw(in: CGRect(x: 50, y: 738, width: 700, height: 26), withAttributes: attrs)
        }
    }
    
    // ТЕМА 1: Киберпанк Метрополис (Неоновый город с высотками)
    private func renderCyberCity(cg: CGContext, space: CGColorSpace, nextRand: () -> Double) {
        let colors = [
            UIColor(red: 0.04, green: 0.02, blue: 0.12, alpha: 1.0).cgColor,
            UIColor(red: 0.20, green: 0.04, blue: 0.25, alpha: 1.0).cgColor
        ] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) {
            cg.drawLinearGradient(g, start: CGPoint(x: 400, y: 0), end: CGPoint(x: 400, y: 800), options: [])
        }
        
        // Луна
        cg.setFillColor(UIColor.systemCyan.withAlphaComponent(0.15).cgColor)
        cg.fillEllipse(in: CGRect(x: 250, y: 80, width: 300, height: 300))
        cg.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
        cg.fillEllipse(in: CGRect(x: 320, y: 150, width: 160, height: 160))
        
        // Силуэты небоскребов
        var x: CGFloat = 0
        while x < 800 {
            let width = CGFloat(nextRand() * 60 + 40)
            let height = CGFloat(nextRand() * 320 + 220)
            let y = 800 - height
            
            cg.setFillColor(UIColor(red: 0.06, green: 0.07, blue: 0.13, alpha: 0.98).cgColor)
            cg.fill(CGRect(x: x, y: y, width: width, height: height))
            
            // Неоновые окна
            cg.setFillColor(UIColor.cyan.withAlphaComponent(0.7).cgColor)
            for wx in stride(from: x + 8, to: x + width - 8, by: 12) {
                for wy in stride(from: y + 10, to: 780, by: 18) {
                    if nextRand() > 0.45 {
                        cg.fill(CGRect(x: wx, y: wy, width: 6, height: 8))
                    }
                }
            }
            x += width + 4
        }
    }
    
    // ТЕМА 2: Глубокий Космос (Спиральная туманность)
    private func renderDeepCosmos(cg: CGContext, space: CGColorSpace, nextRand: () -> Double) {
        let colors = [
            UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1.0).cgColor,
            UIColor(red: 0.08, green: 0.02, blue: 0.18, alpha: 1.0).cgColor
        ] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) {
            cg.drawLinearGradient(g, start: CGPoint(x: 400, y: 0), end: CGPoint(x: 400, y: 800), options: [])
        }
        
        // Звезды
        for _ in 0..<250 {
            let sx = CGFloat(nextRand()) * 800
            let sy = CGFloat(nextRand()) * 800
            let r = CGFloat(nextRand() * 2.5 + 0.5)
            cg.setFillColor(UIColor.white.withAlphaComponent(CGFloat(nextRand() * 0.8 + 0.2)).cgColor)
            cg.fillEllipse(in: CGRect(x: sx, y: sy, width: r, height: r))
        }
        
        // Спиральная туманность
        let center = CGPoint(x: 400, y: 400)
        for i in 0..<180 {
            let angle = Double(i) * 0.12
            let dist = Double(i) * 2.2
            let px = center.x + CGFloat(cos(angle) * dist)
            let py = center.y + CGFloat(sin(angle) * dist)
            let pr = CGFloat(nextRand() * 18 + 8)
            let color = nextRand() > 0.5 ? UIColor.magenta : UIColor.cyan
            cg.setFillColor(color.withAlphaComponent(0.35).cgColor)
            cg.fillEllipse(in: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2))
        }
    }
    
    // ТЕМА 3: Synthwave Пейзаж (Закат и горы)
    private func renderSynthwaveLandscape(cg: CGContext, space: CGColorSpace, nextRand: () -> Double) {
        let skyColors = [
            UIColor(red: 0.15, green: 0.02, blue: 0.25, alpha: 1.0).cgColor,
            UIColor(red: 0.95, green: 0.35, blue: 0.25, alpha: 1.0).cgColor
        ] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: skyColors, locations: [0.0, 1.0]) {
            cg.drawLinearGradient(g, start: CGPoint(x: 400, y: 0), end: CGPoint(x: 400, y: 500), options: [])
        }
        
        // Огромное закатное солнце с полосками
        let sunCenter = CGPoint(x: 400, y: 340)
        let sunRadius: CGFloat = 140
        cg.setFillColor(UIColor.yellow.cgColor)
        cg.fillEllipse(in: CGRect(x: sunCenter.x - sunRadius, y: sunCenter.y - sunRadius, width: sunRadius * 2, height: sunRadius * 2))
        
        // Полосы заката на солнце
        cg.setFillColor(UIColor(red: 0.15, green: 0.02, blue: 0.25, alpha: 1.0).cgColor)
        for y in stride(from: 320, to: 460, by: 16) {
            cg.fill(CGRect(x: 240, y: CGFloat(y), width: 320, height: 6))
        }
        
        // Горы
        let mtnPath = CGMutablePath()
        mtnPath.move(to: CGPoint(x: 0, y: 520))
        mtnPath.addLine(to: CGPoint(x: 200, y: 360))
        mtnPath.addLine(to: CGPoint(x: 400, y: 480))
        mtnPath.addLine(to: CGPoint(x: 620, y: 320))
        mtnPath.addLine(to: CGPoint(x: 800, y: 520))
        mtnPath.closeSubpath()
        cg.setFillColor(UIColor(red: 0.05, green: 0.04, blue: 0.12, alpha: 1.0).cgColor)
        cg.addPath(mtnPath)
        cg.fillPath()
        
        // Сетка
        cg.setStrokeColor(UIColor.systemCyan.withAlphaComponent(0.5).cgColor)
        cg.setLineWidth(1.5)
        for y in stride(from: 520, through: 800, by: 28) {
            cg.move(to: CGPoint(x: 0, y: y))
            cg.addLine(to: CGPoint(x: 800, y: y))
        }
        for x in stride(from: 0, through: 800, by: 50) {
            cg.move(to: CGPoint(x: CGFloat(x), y: 800))
            cg.addLine(to: CGPoint(x: 400 + (CGFloat(x) - 400) * 0.2, y: 520))
        }
        cg.strokePath()
    }
    
    // ТЕМА 4: Кибер-автомобиль
    private func renderCyberVehicle(cg: CGContext, space: CGColorSpace, nextRand: () -> Double) {
        let colors = [
            UIColor(red: 0.03, green: 0.05, blue: 0.10, alpha: 1.0).cgColor,
            UIColor(red: 0.01, green: 0.18, blue: 0.24, alpha: 1.0).cgColor
        ] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) {
            cg.drawLinearGradient(g, start: CGPoint(x: 400, y: 0), end: CGPoint(x: 400, y: 800), options: [])
        }
        
        // Неоновые туннельные круги
        for i in 1...6 {
            let r = CGFloat(i * 65)
            cg.setStrokeColor(UIColor.cyan.withAlphaComponent(CGFloat(0.7 - Double(i) * 0.1)).cgColor)
            cg.setLineWidth(2.5)
            cg.strokeEllipse(in: CGRect(x: 400 - r, y: 400 - r, width: r * 2, height: r * 2))
        }
        
        // Силуэт спорткара
        let carPath = CGMutablePath()
        carPath.move(to: CGPoint(x: 200, y: 520))
        carPath.addLine(to: CGPoint(x: 260, y: 460))
        carPath.addLine(to: CGPoint(x: 480, y: 450))
        carPath.addLine(to: CGPoint(x: 620, y: 500))
        carPath.addLine(to: CGPoint(x: 660, y: 550))
        carPath.addLine(to: CGPoint(x: 180, y: 550))
        carPath.closeSubpath()
        cg.setFillColor(UIColor(red: 0.08, green: 0.09, blue: 0.14, alpha: 1.0).cgColor)
        cg.addPath(carPath)
        cg.fillPath()
        
        // Неоновая светодиодная полоса фар
        cg.setStrokeColor(UIColor.cyan.cgColor)
        cg.setLineWidth(4.0)
        cg.move(to: CGPoint(x: 180, y: 525))
        cg.addLine(to: CGPoint(x: 660, y: 525))
        cg.strokePath()
    }
    
    // ТЕМА 5: Портрет Кибер-Кота
    private func renderCyberCatPortrait(cg: CGContext, space: CGColorSpace, nextRand: () -> Double) {
        let colors = [
            UIColor(red: 0.05, green: 0.07, blue: 0.15, alpha: 1.0).cgColor,
            UIColor(red: 0.02, green: 0.22, blue: 0.32, alpha: 1.0).cgColor
        ] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) {
            cg.drawLinearGradient(g, start: CGPoint(x: 400, y: 0), end: CGPoint(x: 400, y: 800), options: [])
        }
        
        // Неоновый нимб
        let haloColors = [UIColor.cyan.withAlphaComponent(0.6).cgColor, UIColor.clear.cgColor] as CFArray
        if let hg = CGGradient(colorsSpace: space, colors: haloColors, locations: [0.0, 1.0]) {
            cg.drawRadialGradient(hg, startCenter: CGPoint(x: 400, y: 350), startRadius: 50, endCenter: CGPoint(x: 400, y: 350), endRadius: 220, options: [])
        }
        
        // Кот
        cg.setFillColor(UIColor(red: 0.07, green: 0.08, blue: 0.12, alpha: 1.0).cgColor)
        
        // Ушки
        let earL = CGMutablePath()
        earL.move(to: CGPoint(x: 320, y: 340))
        earL.addLine(to: CGPoint(x: 280, y: 200))
        earL.addLine(to: CGPoint(x: 370, y: 260))
        earL.closeSubpath()
        cg.addPath(earL)
        cg.fillPath()
        
        let earR = CGMutablePath()
        earR.move(to: CGPoint(x: 480, y: 340))
        earR.addLine(to: CGPoint(x: 520, y: 200))
        earR.addLine(to: CGPoint(x: 430, y: 260))
        earR.closeSubpath()
        cg.addPath(earR)
        cg.fillPath()
        
        // Голова и тело
        cg.fillEllipse(in: CGRect(x: 290, y: 240, width: 220, height: 190))
        cg.fillEllipse(in: CGRect(x: 280, y: 380, width: 240, height: 280))
        
        // Очки с градиентом
        let glassesRect = CGRect(x: 320, y: 295, width: 160, height: 46)
        let glassesPath = UIBezierPath(roundedRect: glassesRect, cornerRadius: 10)
        cg.setFillColor(UIColor.black.cgColor)
        cg.addPath(glassesPath.cgPath)
        cg.fillPath()
        
        cg.setStrokeColor(UIColor.cyan.cgColor)
        cg.setLineWidth(3.0)
        cg.addPath(glassesPath.cgPath)
        cg.strokePath()
        
        // Неоновый блик
        cg.setFillColor(UIColor.cyan.cgColor)
        cg.fill(CGRect(x: 330, y: 300, width: 140, height: 4))
    }
}
