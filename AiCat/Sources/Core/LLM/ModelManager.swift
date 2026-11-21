import Foundation
import Combine

public final class ModelManager: ObservableObject {
    public static let shared = ModelManager()
    
    @Published public var isModelLoaded: Bool = false
    @Published public var activeModelName: String = "Поиск модели..."
    @Published public var activeModelURL: URL? = nil
    @Published public var modelPathInfo: String = ""
    
    private init() {
        findAndLoadModel()
    }
    
    // Сканирует все возможные места, где может лежать файл qwen2.5-3b-instruct-q4_k_m.gguf
    public func findAndLoadModel() {
        let fileName = "qwen2.5-3b-instruct-q4_k_m.gguf"
        
        // 1. Проверяем папку Models внутри бандла приложения (куда положил пользователь)
        let bundleModelsURL = Bundle.main.bundleURL.appendingPathComponent("Models").appendingPathComponent(fileName)
        let bundleRootURL = Bundle.main.bundleURL.appendingPathComponent(fileName)
        let bundleResourceURL = Bundle.main.url(forResource: "qwen2.5-3b-instruct-q4_k_m", withExtension: "gguf")
        
        // 2. Проверяем папку Documents/Models (куда можно скинуть через приложение Файлы)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let docsModelsURL = docs.appendingPathComponent("Models").appendingPathComponent(fileName)
        let docsRootURL = docs.appendingPathComponent(fileName)
        
        let candidateURLs = [bundleModelsURL, bundleRootURL, bundleResourceURL, docsModelsURL, docsRootURL].compactMap { $0 }
        
        for url in candidateURLs {
            if FileManager.default.fileExists(atPath: url.path) {
                let sizeBytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                let sizeGB = Double(sizeBytes) / (1024 * 1024 * 1024)
                
                DispatchQueue.main.async {
                    self.activeModelURL = url
                    self.activeModelName = "Qwen 2.5 3B (Офлайн)"
                    self.isModelLoaded = true
                    self.modelPathInfo = "Файл найден (\(String(format: "%.2f", sizeGB)) ГБ). Мозг A17 Pro готов к работе!"
                }
                return
            }
        }
        
        DispatchQueue.main.async {
            self.isModelLoaded = false
            self.activeModelName = "Модель не найдена в папке"
            self.modelPathInfo = "Положи файл qwen2.5-3b-instruct-q4_k_m.gguf в папку AiCat/Models"
        }
    }
}
