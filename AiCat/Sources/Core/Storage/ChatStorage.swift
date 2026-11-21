import Foundation

public final class ChatStorage {
    public static let shared = ChatStorage()
    
    private let fileName = "chat_history.json"
    
    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }
    
    private init() {}
    
    public func loadMessages() -> [ChatMessage] {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let messages = try? JSONDecoder().decode([ChatMessage].self, from: data),
              !messages.isEmpty else {
            return [
                ChatMessage(
                    sender: .cat,
                    text: "Салют, кожаный! Я AiCat — твой 3D-агент в черных очках. Моделирую мысли в чипе A17 Pro. Погладь меня, нажми трюки или спроси что угодно!"
                )
            ]
        }
        return messages
    }
    
    public func saveMessages(_ messages: [ChatMessage]) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            // Сохраняем последние 100 сообщений
            let toSave = Array(messages.suffix(100))
            if let data = try? JSONEncoder().encode(toSave) {
                try? data.write(to: self.fileURL, options: .atomic)
            }
        }
    }
    
    public func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
