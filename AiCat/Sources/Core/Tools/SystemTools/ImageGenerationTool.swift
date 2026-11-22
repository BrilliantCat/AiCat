import Combine
import UIKit

@MainActor
public final class ImageGenerationTool: ObservableObject {
    public static let shared = ImageGenerationTool()
    @Published public var isGenerating = false
    @Published public var lastGeneratedImage: UIImage?
    public var isDiffusionModelInstalled: Bool { ModelManager.shared.isDiffusionLoaded }
    private init() {}

    public func generateImageAsync(prompt: String) async -> (image: UIImage?, status: String) {
        guard !isGenerating else { return (nil, "Картинка уже создаётся.") }
        guard let url = ModelManager.shared.diffusionURL else {
            return (nil, "Нужна полная модель Stable Diffusion в Models, включая vocab.json и merges.txt.")
        }
        isGenerating = true
        defer { isGenerating = false }
        do {
            let image = try await LocalInference.shared.image(url: url, prompt: prompt)
            lastGeneratedImage = image
            return (image, "Картинка готова, кожаный!")
        } catch {
            return (nil, "Ошибка создания картинки: \(error.localizedDescription)")
        }
    }

    public func generateImage(prompt: String, completion: @escaping (UIImage?, String) -> Void) {
        Task {
            let result = await generateImageAsync(prompt: prompt)
            completion(result.image, result.status)
        }
    }
}
