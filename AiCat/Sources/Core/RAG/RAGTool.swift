import Foundation

public struct DocumentChunk: Codable, Identifiable {
    public let id: UUID
    public let sourceName: String
    public let text: String
    
    public init(id: UUID = UUID(), sourceName: String, text: String) {
        self.id = id
        self.sourceName = sourceName
        self.text = text
    }
}

public final class RAGTool: ObservableObject {
    public static let shared = RAGTool()
    
    @Published public var indexedDocuments: [DocumentChunk] = []
    private let storageURL: URL
    
    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.storageURL = docs.appendingPathComponent("aicat_rag_chunks.json")
        loadChunks()
    }
    
    public func addDocument(name: String, content: String) {
        // Делим текст на чанки по 400-500 символов
        let sentences = content.components(separatedBy: "\n\n")
        for chunkText in sentences where !chunkText.trimmingCharacters(in: .whitespaces).isEmpty {
            let chunk = DocumentChunk(sourceName: name, text: chunkText)
            indexedDocuments.append(chunk)
        }
        saveChunks()
    }
    
    public func searchKnowledge(query: String, topK: Int = 3) -> String {
        let keywords = query.lowercased().split(separator: " ").map { String($0) }
        guard !keywords.isEmpty else { return "" }
        
        // Быстрый локальный BM25/Keyword скоринг
        var scored: [(chunk: DocumentChunk, score: Int)] = []
        for chunk in indexedDocuments {
            var score = 0
            let lowerText = chunk.text.lowercased()
            for kw in keywords {
                if lowerText.contains(kw) {
                    score += 1
                }
            }
            if score > 0 {
                scored.append((chunk, score))
            }
        }
        
        scored.sort { $0.score > $1.score }
        let topResults = scored.prefix(topK).map { "[\($0.chunk.sourceName)]: \($0.chunk.text)" }
        return topResults.joined(separator: "\n---\n")
    }
    
    private func saveChunks() {
        if let data = try? JSONEncoder().encode(indexedDocuments) {
            try? data.write(to: storageURL)
        }
    }
    
    private func loadChunks() {
        if let data = try? Data(contentsOf: storageURL),
           let saved = try? JSONDecoder().decode([DocumentChunk].self, from: data) {
            self.indexedDocuments = saved
        }
    }
}
