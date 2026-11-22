import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

public final class PhotoTool {
    public static let shared = PhotoTool()
    private let context = CIContext()
    
    private init() {}
    
    public func normalized(_ image: UIImage, size: CGSize? = nil) -> UIImage {
        let target = size ?? image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    // 1. Вырезание объекта / удаление фона (100% офлайн через Vision)
    public func removeBackground(from image: UIImage) -> UIImage? {
        guard let cgImage = normalized(image).cgImage else { return nil }
        
        if #available(iOS 17.0, *) {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
                guard let result = request.results?.first else { return image }
                let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
                let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
                let originalCI = CIImage(cgImage: cgImage)
                
                let filter = CIFilter.blendWithMask()
                filter.inputImage = originalCI
                filter.maskImage = maskImage
                filter.backgroundImage = CIImage.empty()
                
                guard let output = filter.outputImage,
                      let renderedCG = context.createCGImage(output, from: output.extent) else { return image }
                
                return UIImage(cgImage: renderedCG)
            } catch {
                return image
            }
        }
        return image
    }
    
    // 2. Умное авто-улучшение фото (Auto Enhance & Contrast)
    public func autoEnhance(image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        let adjustments = ciImage.autoAdjustmentFilters()
        var currentImage = ciImage
        for filter in adjustments {
            filter.setValue(currentImage, forKey: kCIInputImageKey)
            if let output = filter.outputImage {
                currentImage = output
            }
        }
        
        guard let cgImage = context.createCGImage(currentImage, from: currentImage.extent) else { return image }
        return UIImage(cgImage: cgImage)
    }
    
    // 3. Распознавание текста на фото (Офлайн OCR на русском и английском)
    public func recognizeText(from image: UIImage, completion: @escaping (String) -> Void) {
        guard let cgImage = normalized(image).cgImage else {
            completion("Не удалось прочитать картинку.")
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                completion("Текст на фото не обнаружен.")
                return
            }
            
            let detected = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            completion(detected.isEmpty ? "Текст не найден." : detected)
        }
        
        request.recognitionLanguages = ["ru-RU", "en-US"]
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do { try handler.perform([request]) }
            catch { completion("Ошибка распознавания: \(error.localizedDescription)") }
        }
    }
    
    public func recognizeTextAsync(from image: UIImage) async -> String {
        await withCheckedContinuation { continuation in
            recognizeText(from: image) { text in
                continuation.resume(returning: text)
            }
        }
    }
}
