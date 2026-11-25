import Foundation
import llama
import StableDiffusion
import CoreML
import UIKit

/// One serial executor keeps the two large models from occupying memory together.
actor LocalInference {
    static let shared = LocalInference()

    private init() { llama_backend_init() }

    func reply(url: URL, prompt: String, system: String, history: [(role: String, content: String)] = []) throws -> String {
        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = 99
        guard let model = llama_model_load_from_file(url.path, modelParams) else {
            throw failure("Не удалось загрузить GGUF. Проверь целостность файла модели.")
        }
        defer { llama_model_free(model) }
        var params = llama_context_default_params()
        params.n_ctx = 4096
        params.n_batch = 512
        params.n_threads = 4
        params.n_threads_batch = 4
        guard let context = llama_init_from_model(model, params) else {
            throw failure("Не хватает памяти для контекста Qwen.")
        }
        defer { llama_free(context) }
        let vocab = llama_model_get_vocab(model)
        var messages = history + [(role: "user", content: prompt)]
        var input = PromptBuilder.formatChatML(system: system, messages: messages)
        var required = -llama_tokenize(vocab, input, Int32(input.utf8.count), nil, 0, false, true)
        while required >= 3584 && messages.count > 1 {
            messages.removeFirst()
            input = PromptBuilder.formatChatML(system: system, messages: messages)
            required = -llama_tokenize(vocab, input, Int32(input.utf8.count), nil, 0, false, true)
        }
        let byteCount = Int32(input.utf8.count)
        guard required > 0, required < 3584 else {
            throw failure("Сообщение и история слишком длинные. Сократи запрос или очисти историю.")
        }
        var tokens = [llama_token](repeating: 0, count: Int(required))
        let count = llama_tokenize(vocab, input, byteCount, &tokens, required, false, true)
        guard count > 0 else { throw failure("Ошибка токенизации.") }
        for offset in stride(from: 0, to: Int(count), by: 512) {
            try Task.checkCancellation()
            var chunk = Array(tokens[offset..<min(offset + 512, Int(count))])
            let result = chunk.withUnsafeMutableBufferPointer {
                llama_decode(context, llama_batch_get_one($0.baseAddress, Int32($0.count)))
            }
            guard result == 0 else { throw failure("Ошибка обработки контекста Qwen.") }
        }
        guard let sampler = llama_sampler_chain_init(llama_sampler_chain_default_params()) else {
            throw failure("Не удалось создать генератор токенов.")
        }
        defer { llama_sampler_free(sampler) }
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.9, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.7))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(UInt32.random(in: 0..<UInt32.max)))
        var bytes = [UInt8]()
        for _ in 0..<512 {
            try Task.checkCancellation()
            var token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, token) { break }
            var piece = [CChar](repeating: 0, count: 256)
            var size = llama_token_to_piece(vocab, token, &piece, Int32(piece.count), 0, false)
            if size < 0 {
                piece = [CChar](repeating: 0, count: Int(-size))
                size = llama_token_to_piece(vocab, token, &piece, Int32(piece.count), 0, false)
            }
            guard size >= 0 else { throw failure("Ошибка декодирования токена.") }
            bytes.append(contentsOf: piece.prefix(Int(size)).map { UInt8(bitPattern: $0) })
            let result = withUnsafeMutablePointer(to: &token) {
                llama_decode(context, llama_batch_get_one($0, 1))
            }
            guard result == 0 else { throw failure("Ошибка генерации Qwen.") }
        }
        return String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func image(url: URL, prompt: String, startingImage: CGImage? = nil, textModel: URL? = nil) throws -> UIImage {
        var conditioning = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !conditioning.isEmpty else { throw failure("Введи описание изображения.") }
        if let textModel, conditioning.range(of: "[А-Яа-яЁё]", options: .regularExpression) != nil {
            let translated = try reply(url: textModel, prompt: conditioning, system:
                "Translate the visual description into concise English for an image generator. Preserve subjects, colors, style and spatial relations. Output only the description.")
            if !translated.isEmpty { conditioning = translated }
        }
        let modelConfiguration = MLModelConfiguration()
        modelConfiguration.computeUnits = .cpuAndNeuralEngine
        let pipeline = try StableDiffusionPipeline(resourcesAt: url, controlNet: [], configuration: modelConfiguration,
                                                   disableSafety: false, reduceMemory: true)
        defer { pipeline.unloadResources() }
        var configuration = StableDiffusionPipeline.Configuration(prompt: conditioning)
        configuration.startingImage = startingImage
        configuration.strength = startingImage == nil ? 1 : 0.55
        configuration.stepCount = 28
        configuration.negativePrompt = "compression artifacts, duplicate limbs, malformed anatomy"
        configuration.seed = UInt32.random(in: 0..<UInt32.max)
        let images = try pipeline.generateImages(configuration: configuration)
        guard let image = images.compactMap({ $0 }).first else {
            throw failure("Генерация завершилась без изображения.")
        }
        return UIImage(cgImage: image)
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "AiCat.Inference", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
