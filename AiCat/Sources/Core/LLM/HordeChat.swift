import Foundation

enum HordeChat {
    struct Catalog: Decodable {
        struct Model: Decodable {
            struct Status: Decodable { let workers: Int; let queued: Double }
            let id: String
            let x_horde: Status?
        }
        let data: [Model]
    }

    private struct Completion: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
        let model: String?
    }

    static func preferredModel(in models: [Catalog.Model]) -> Catalog.Model? {
        // Prefer a multilingual general-purpose model. Workers and queues change throughout the day.
        let ranked = models.compactMap { model -> (model: Catalog.Model, priority: Int)? in
            let name = model.id.lowercased()
            guard (model.x_horde?.workers ?? 1) > 0 else { return nil }
            let larger = name.range(of: #"(?:^|[^a-z0-9.])(?:[7-9]|[1-9][0-9]{1,2})(?:\.[0-9]+)?b(?:$|[^a-z0-9])"#, options: .regularExpression) != nil
            let general = ["qwen", "mistral", "gemma", "llama"].contains { name.contains($0) }
            if name.contains("qwen") && (larger || name.contains("flash-next")) { return (model, 0) }
            if larger && general { return (model, 1) }
            return larger ? (model, 2) : nil
        }
        return ranked.min { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return (lhs.model.x_horde?.queued ?? 0) < (rhs.model.x_horde?.queued ?? 0)
        }?.model
    }

    static func reply(to text: String, history: [ChatMessage]) async -> (text: String, model: String)? {
        let base = URL(string: "https://oai.aihorde.net/v1/")!
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForResource = 8
        config.httpAdditionalHeaders = ["Authorization": "Bearer 0000000000"]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        do {
            var lookup = URLRequest(url: base.appendingPathComponent("models"))
            lookup.timeoutInterval = 2
            let (catalog, status) = try await session.data(for: lookup)
            guard (status as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let catalogModels = try JSONDecoder().decode(Catalog.self, from: catalog).data
            guard let model = preferredModel(in: catalogModels) else { return nil }

            var messages = [["role": "system", "content": PromptBuilder.buildSystemPrompt(includeTools: false, includeClock: false) + PromptBuilder.topicDetail(text)]]
            // Only reuse complete turns that already went through the online chat.
            for (user, answer) in zip(history, history.dropFirst()) where
                user.sender == .user && answer.sender == .cat && answer.source?.hasPrefix("AI Horde · ") == true {
                messages.append(["role":"user", "content":String(user.text.prefix(1200))])
                messages.append(["role":"assistant", "content":String(answer.text.prefix(1200))])
            }
            messages.append(["role":"user", "content":text])
            var request = URLRequest(url: base.appendingPathComponent("chat/completions"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["model":model.id, "messages":messages, "max_tokens":320])
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let result = try JSONDecoder().decode(Completion.self, from: data)
            guard let content = result.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !content.isEmpty else { return nil }
            return (content, "AI Horde · " + (result.model ?? model.id))
        } catch { return nil }
    }
}
