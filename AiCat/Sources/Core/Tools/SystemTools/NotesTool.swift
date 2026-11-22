import Combine
import Foundation

public struct CatNote: Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let content: String
    public let createdAt: Date
    
    public init(id: UUID = UUID(), title: String, content: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
    }
}

public final class NotesTool: ObservableObject {
    public static let shared = NotesTool()
    
    @Published public var notes: [CatNote] = []
    private let fileURL: URL
    
    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("aicat_notes.json")
        loadNotes()
    }
    
    public func saveNote(title: String, content: String) -> String {
        let note = CatNote(title: title, content: content)
        notes.insert(note, at: 0)
        do {
            let data = try JSONEncoder().encode(notes)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            notes.removeAll { $0.id == note.id }
            return "Не удалось сохранить заметку: \(error.localizedDescription)"
        }
        return "Записал в локальный дневник: «\(title)». Надежно сохранено в памяти AiCat."
    }
    
    public func searchNotes(query: String) -> [CatNote] {
        let lower = query.lowercased()
        return notes.filter { $0.title.lowercased().contains(lower) || $0.content.lowercased().contains(lower) }
    }
    
    private func loadNotes() {
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([CatNote].self, from: data) {
            self.notes = saved
        }
    }
}
