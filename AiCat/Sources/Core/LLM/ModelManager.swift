import Foundation
import Combine

public struct ModelCatalogItem: Identifiable {
    public let id: String
    public let name: String
    public let typeText: String
    public let sizeText: String
    public let description: String
    public let downloadURLString: String
    public let destinationFolder: String
}

public final class ModelManager: ObservableObject {
    public static let shared = ModelManager()
    
    @Published public var isModelLoaded: Bool = false
    @Published public var activeModelName: String = "Поиск модели..."
    @Published public var activeModelURL: URL? = nil
    @Published public var modelPathInfo: String = ""
    @Published public var isDiffusionLoaded: Bool = false
    
    // Каталог двух ключевых моделей (Языковая + Графическая)
    public let catalog: [ModelCatalogItem] = [
        ModelCatalogItem(
            id: "llm_qwen3b",
            name: "Qwen 2.5 3B Instruct (GGUF)",
            typeText: "🧠 Языковой мозг (LLM)",
            sizeText: "1.9 ГБ",
            description: "Разговоры, логика, юмор, управление телефоном, фитнес и задачи.",
            downloadURLString: "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf",
            destinationFolder: "Models/qwen2.5-3b-instruct-q4_k_m.gguf"
        ),
        ModelCatalogItem(
            id: "diffusion_sd15",
            name: "Stable Diffusion 1.5 (CoreML)",
            typeText: "🎨 Генератор изображений",
            sizeText: "2.1 ГБ",
            description: "Рисование фото и артов по тексту с нуля на Neural Engine A17 Pro.",
            downloadURLString: "https://huggingface.co/apple/coreml-stable-diffusion-v1-5/resolve/main/coreml-stable-diffusion-v1-5_split-einsum_compiled.zip",
            destinationFolder: "Models/sd_coreml"
        )
    ]
    
    private init() {
        findAndLoadModel()
    }
    
    public func findAndLoadModel() {
        let fileName = "qwen2.5-3b-instruct-q4_k_m.gguf"
        
        let bundleModelsURL = Bundle.main.bundleURL.appendingPathComponent("Models").appendingPathComponent(fileName)
        let bundleRootURL = Bundle.main.bundleURL.appendingPathComponent(fileName)
        let bundleResourceURL = Bundle.main.url(forResource: "qwen2.5-3b-instruct-q4_k_m", withExtension: "gguf")
        
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
