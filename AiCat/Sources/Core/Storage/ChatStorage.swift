import Foundation

public final class ChatStorage {
    public static let shared = ChatStorage()
    
    private let queue = DispatchQueue(label: "AiCat.ChatStorage")
    private let fileName = "chat_history.json"
    
    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }
    
    private init() {}
    
    public func loadMessages() -> [ChatMessage] {
        queue.sync { readMessages() }
    }

    private func readMessages() -> [ChatMessage] {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let messages = try? JSONDecoder().decode([ChatMessage].self, from: data),
              !messages.isEmpty else {
            return [
                ChatMessage(
                    sender: .cat,
                    text: "Привет, кожаный. Я рядом. Как ты сегодня?"
                )
            ]
        }
        return messages
    }
    
    public func saveMessages(_ messages: [ChatMessage]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            // Сохраняем последние 100 сообщений
            let toSave = Array(messages.suffix(100))
            if let data = try? JSONEncoder().encode(toSave) {
                try? data.write(to: self.fileURL, options: .atomic)
            }
        }
    }
    
    public func clear() {
        queue.sync { try? FileManager.default.removeItem(at: fileURL) }
    }
}
