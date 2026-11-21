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
    @Published public var ggufMetadata: GGUFMetadata? = nil
    
    @Published public var isDiffusionLoaded: Bool = false
    @Published public var diffusionPathInfo: String = ""
    
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
            downloadURLString: "https://huggingface.co/pcuenq/coreml-stable-diffusion-v1-5/resolve/main/coreml-stable-diffusion-v1-5_split_einsum_compiled.zip",
            destinationFolder: "Models/sd_coreml"
        )
    ]
    
    private init() {
        findAndLoadModel()
        findAndLoadDiffusionModel()
    }
    
    public func findAndLoadModel() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let bundle = Bundle.main.bundleURL
        
        // 1. Проверяем стандартные пути
        let targetFileName = "qwen2.5-3b-instruct-q4_k_m.gguf"
        var candidateURLs: [URL] = [
            docs.appendingPathComponent("Models").appendingPathComponent(targetFileName),
            docs.appendingPathComponent(targetFileName),
            bundle.appendingPathComponent("Models").appendingPathComponent(targetFileName),
            bundle.appendingPathComponent(targetFileName)
        ]
        
        // 2. Дополнительно ищем любой .gguf файл в Documents и подпапках
        if let enumerator = fm.enumerator(at: docs, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension.lowercased() == "gguf" && !candidateURLs.contains(fileURL) {
                    candidateURLs.append(fileURL)
                }
            }
        }
        
        for url in candidateURLs {
            if fm.fileExists(atPath: url.path) {
                let meta = GGUFReader.inspect(fileURL: url)
                let sizeGB = meta?.fileSizeGB ?? 1.93
                
                DispatchQueue.main.async {
                    self.activeModelURL = url
                    self.activeModelName = meta?.architecture ?? "Qwen 2.5 3B (GGUF)"
                    self.isModelLoaded = true
                    self.ggufMetadata = meta
                    self.modelPathInfo = "Файл: \(url.lastPathComponent) (\(String(format: "%.2f", sizeGB)) ГБ). Мозг активен на A17 Pro!"
                }
                return
            }
        }
        
        DispatchQueue.main.async {
            self.isModelLoaded = false
            self.activeModelName = "Модель не найдена в папке"
            self.modelPathInfo = "Положи файл qwen2.5-3b-instruct-q4_k_m.gguf в папку AiCat/Models или открой в 'Файлы' на iPhone"
        }
    }
    
    public func findAndLoadDiffusionModel() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let bundle = Bundle.main.bundleURL
        
        let candidateDirs: [URL] = [
            docs.appendingPathComponent("Models").appendingPathComponent("sd_coreml"),
            docs.appendingPathComponent("sd_coreml"),
            bundle.appendingPathComponent("Models").appendingPathComponent("sd_coreml"),
            docs.appendingPathComponent("coreml-stable-diffusion-v1-5_split_einsum_compiled")
        ]
        
        for dir in candidateDirs {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue {
                DispatchQueue.main.async {
                    self.isDiffusionLoaded = true
                    self.diffusionPathInfo = "CoreML Stable Diffusion найдена в \(dir.lastPathComponent)! Готова к нейрогенерации."
                }
                return
            }
        }
        
        DispatchQueue.main.async {
            self.isDiffusionLoaded = false
            self.diffusionPathInfo = "Модель CoreML SD 1.5 не найдена. Работает встроенный генератор арт-концептов."
        }
    }
}
