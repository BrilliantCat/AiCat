import Foundation
import Combine

public struct AvailableModel: Identifiable {
    public let id: String
    public let name: String
    public let sizeText: String
    public let description: String
    public let downloadURL: URL
    public let fileName: String
}

public final class ModelManager: ObservableObject {
    public static let shared = ModelManager()
    
    // Каталог рекомендованных моделей под 8 ГБ RAM iPhone 15 Pro
    public let availableModels: [AvailableModel] = [
        AvailableModel(
            id: "qwen-2.5-3b",
            name: "Qwen 2.5 3B Instruct (Q4_K_M)",
            sizeText: "1.9 ГБ",
            description: "Рекомендуется! Лучший русский язык, логика, юмор и точное выполнение команд.",
            downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf")!,
            fileName: "qwen2.5-3b-instruct-q4_k_m.gguf"
        ),
        AvailableModel(
            id: "qwen-2.5-1.5b",
            name: "Qwen 2.5 1.5B Instruct (Q4_K_M)",
            sizeText: "0.98 ГБ",
            description: "Ультрабыстрая модель. Моментальные ответы (40+ токенов/сек), легкая нагрузка на батарею.",
            downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf")!,
            fileName: "qwen2.5-1.5b-instruct-q4_k_m.gguf"
        )
    ]
    
    @Published public var installedModels: [String] = []
    @Published public var downloadProgress: Double = 0.0
    @Published public var isDownloading: Bool = false
    @Published public var activeModelName: String = "Не загружена"
    
    private var downloadTask: URLSessionDownloadTask?
    
    private init() {
        scanLocalModels()
    }
    
    public var modelsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Models")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    // Сканирует папку приложения (включая файлы, закинутые через кабель / приложение «Файлы»)
    public func scanLocalModels() {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: modelsDirectory.path) else { return }
        let ggufFiles = files.filter { $0.hasSuffix(".gguf") }
        
        DispatchQueue.main.async {
            self.installedModels = ggufFiles
            if let first = ggufFiles.first {
                self.activeModelName = first
            }
        }
    }
    
    // Скачивание модели прямо на телефоне в 1 клик
    public func downloadModel(_ model: AvailableModel) {
        guard !isDownloading else { return }
        
        isDownloading = true
        downloadProgress = 0.0
        
        let destinationURL = modelsDirectory.appendingPathComponent(model.fileName)
        
        let session = URLSession(configuration: .default)
        downloadTask = session.downloadTask(with: model.downloadURL) { [weak self] tempURL, response, error in
            guard let self = self, let tempURL = tempURL, error == nil else {
                DispatchQueue.main.async { self?.isDownloading = false }
                return
            }
            
            try? FileManager.default.removeItem(at: destinationURL)
            try? FileManager.default.moveItem(at: tempURL, to: destinationURL)
            
            DispatchQueue.main.async {
                self.isDownloading = false
                self.scanLocalModels()
            }
        }
        
        downloadTask?.resume()
    }
}
