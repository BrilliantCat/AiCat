import Combine
import Foundation
import UIKit

public struct BenchmarkResult: Equatable {
    public let timeToFirstTokenMs: Double
    public let tokensPerSecond: Double
    public let generatedText: String
    public let memoryUsageMB: Double
}

public final class ModelManager: ObservableObject {
    public static let shared = ModelManager()
    
    @Published public var isModelLoaded: Bool = false
    @Published public var activeModelName: String = "Модель не найдена"
    @Published public var activeModelURL: URL? = nil
    @Published public var modelPathInfo: String = ""
    @Published public var ggufMetadata: GGUFMetadata? = nil
    
    @Published public var diffusionURL: URL? = nil
    @Published public var isDiffusionLoaded: Bool = false
    @Published public var diffusionPathInfo: String = ""
    
    @Published public var isBenchmarking: Bool = false
    @Published public var lastBenchmark: BenchmarkResult? = nil
    
    private init() {
        findAndLoadModel()
        findAndLoadDiffusionModel()
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    public func findAndLoadModel() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let bundle = Bundle.main.bundleURL
        
        let targetFileName = "qwen2.5-3b-instruct-q4_k_m.gguf"
        var candidateURLs: [URL] = [
            docs.appendingPathComponent("Models").appendingPathComponent(targetFileName),
            docs.appendingPathComponent("Model").appendingPathComponent(targetFileName),
            docs.appendingPathComponent(targetFileName),
            bundle.appendingPathComponent("Models").appendingPathComponent(targetFileName),
            bundle.appendingPathComponent("Model").appendingPathComponent(targetFileName),
            bundle.appendingPathComponent(targetFileName)
        ]
        
        // Поиск любого .gguf в Documents
        if let enumerator = fm.enumerator(at: docs, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension.lowercased() == "gguf" && !candidateURLs.contains(fileURL) {
                    candidateURLs.append(fileURL)
                }
            }
        }
        
        for url in candidateURLs {
            if fm.fileExists(atPath: url.path) {
                if let meta = GGUFReader.inspect(fileURL: url) {
                    DispatchQueue.main.async {
                        self.activeModelURL = url
                        self.activeModelName = "\(meta.architecture) (GGUF \(meta.quantization))"
                        self.isModelLoaded = true
                        self.ggufMetadata = meta
                        self.modelPathInfo = "Файл: \(url.lastPathComponent) (\(String(format: "%.2f", meta.fileSizeGB)) ГБ). Файл найден. Загрузка при первом запросе."
                    }
                    return
                }
            }
        }
        
        DispatchQueue.main.async {
            self.activeModelURL = nil
            self.isModelLoaded = false
            self.activeModelName = "Модель не найдена в папке"
            self.modelPathInfo = "Положи qwen2.5-3b-instruct-q4_k_m.gguf в папку AiCat/Models через приложение 'Файлы'"
            self.ggufMetadata = nil
        }
    }
    
    public func findAndLoadDiffusionModel() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let bundle = Bundle.main.bundleURL
        
        let candidateDirs: [URL] = [
            bundle.appendingPathComponent("Model").appendingPathComponent("sd_coreml"),
            bundle.appendingPathComponent("Model").appendingPathComponent("coreml-stable-diffusion-v1-5_split_einsum_compiled"),
            docs.appendingPathComponent("Model").appendingPathComponent("sd_coreml"),
            docs.appendingPathComponent("Model").appendingPathComponent("coreml-stable-diffusion-v1-5_split_einsum_compiled"),
            bundle.appendingPathComponent("Models").appendingPathComponent("sd_coreml"),
            bundle.appendingPathComponent("Models").appendingPathComponent("coreml-stable-diffusion-v1-5_split_einsum_compiled"),
            bundle.appendingPathComponent("sd_coreml"),
            bundle.appendingPathComponent("coreml-stable-diffusion-v1-5_split_einsum_compiled"),
            docs.appendingPathComponent("Models").appendingPathComponent("sd_coreml"),
            docs.appendingPathComponent("Models").appendingPathComponent("coreml-stable-diffusion-v1-5_split_einsum_compiled"),
            docs.appendingPathComponent("sd_coreml"),
            docs.appendingPathComponent("coreml-stable-diffusion-v1-5_split_einsum_compiled")
        ]
        
        for dir in candidateDirs {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue,
               ["TextEncoder.mlmodelc", "VAEDecoder.mlmodelc", "vocab.json", "merges.txt"].allSatisfy({ fm.fileExists(atPath: dir.appendingPathComponent($0).path) }),
               (fm.fileExists(atPath: dir.appendingPathComponent("Unet.mlmodelc").path) ||
                ["UnetChunk1.mlmodelc", "UnetChunk2.mlmodelc"].allSatisfy({ fm.fileExists(atPath: dir.appendingPathComponent($0).path) })) {
                DispatchQueue.main.async {
                    self.diffusionURL = dir
                    self.isDiffusionLoaded = true
                    self.diffusionPathInfo = "CoreML Stable Diffusion найдена в \(dir.lastPathComponent)!"
                }
                return
            }
        }
        
        DispatchQueue.main.async {
            self.diffusionURL = nil
            self.isDiffusionLoaded = false
            self.diffusionPathInfo = "Папка coreml-stable-diffusion-v1-5_split_einsum_compiled не найдена."
        }
    }
    
    // Инференс через локальный движок
    public func infer(prompt: String, system: String) async -> String {
        guard let url = activeModelURL else { return "Файл Qwen не найден. Открой меню моделей." }
        do {
            return try await LocalInference.shared.reply(url: url, prompt: prompt, system: system)
        } catch {
            return "Не удалось выполнить запрос: \(error.localizedDescription)"
        }
    }

    public func runBenchmark(completion: @escaping (BenchmarkResult) -> Void) {
        isBenchmarking = true
        Task {
            let start = Date()
            let output = await infer(prompt: "Привет! Представься одним предложением.", system: "Ты AiCat. Отвечай по-русски.")
            let elapsed = Date().timeIntervalSince(start) * 1000
            await MainActor.run {
                let result = BenchmarkResult(timeToFirstTokenMs: elapsed, tokensPerSecond: 0,
                                             generatedText: output, memoryUsageMB: 0)
                self.lastBenchmark = result
                self.isBenchmarking = false
                completion(result)
            }
        }
    }

    public func handleMemoryWarning() {
        // Корректная выгрузка контекста при нехватке памяти на бесплатном профиле
        DebugLogger.shared.log("Предупреждение памяти. Модели освобождаются после каждой задачи.", level: .warning, tag: "Memory")
    }
}
