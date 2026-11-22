import Combine
import Foundation
import PDFKit

public struct DocumentChunk: Codable, Identifiable, Equatable {
    public let id: UUID
    public let sourceName: String
    public let text: String
    public let tokens: [String]
    
    public init(id: UUID = UUID(), sourceName: String, text: String, tokens: [String] = []) {
        self.id = id
        self.sourceName = sourceName
        self.text = text
        self.tokens = tokens.isEmpty ? RAGTool.tokenize(text) : tokens
    }
}

public struct IndexedDocumentMeta: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let chunkCount: Int
    public let dateAdded: Date
}

public final class RAGTool: ObservableObject {
    public static let shared = RAGTool()
    
    @Published public var indexedDocuments: [DocumentChunk] = []
    @Published public var documentsMeta: [IndexedDocumentMeta] = []
    
    private let chunksStorageURL: URL
    private let metaStorageURL: URL
    
    // Параметры BM25
    private let storageQueue = DispatchQueue(label: "AiCat.RAGStorage")
    private let k1: Double = 1.2
    private let b: Double = 0.75
    
    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.chunksStorageURL = docs.appendingPathComponent("aicat_rag_chunks.json")
        self.metaStorageURL = docs.appendingPathComponent("aicat_rag_meta.json")
        loadData()
    }
    
    // Нормализация и токенизация текста с русской лемматизацией/стеммингом
    public static func tokenize(_ text: String) -> [String] {
        let lower = text.lowercased()
        let rawTokens = lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 1 }
        
        // Стоп-слова (русские и английские)
        let stopWords: Set<String> = [
            "и", "в", "на", "с", "по", "к", "у", "о", "из", "за", "от", "для", "до", "не", "что", "это", "как",
            "так", "но", "а", "да", "же", "ли", "бы", "то", "он", "она", "оно", "они", "мы", "вы", "я", "ты",
            "the", "a", "an", "is", "in", "at", "of", "on", "and", "or", "to", "for", "with"
        ]
        
        return rawTokens.compactMap { token in
            guard !stopWords.contains(token) else { return nil }
            return stemRussian(token)
        }
    }
    
    // Простой эффективный стеммер русских окончаний
    private static func stemRussian(_ word: String) -> String {
        var w = word
        let suffixes = [
            "ание", "ания", "ость", "ости", "ство", "ения", "ение", "ами", "ями", "ов", "ев", "ей", "ам", "ям",
            "ах", "ях", "ую", "юю", "ой", "ей", "ем", "ом", "ым", "им", "ая", "яя", "ое", "ее",
            "ый", "ий", "ых", "их", "ать", "ять", "еть", "ить", "ся", "сь", "ал", "ил", "ел", "а", "ы", "и", "у", "я", "е"
        ]
        for s in suffixes {
            if w.count > s.count + 2 && w.hasSuffix(s) {
                w = String(w.dropLast(s.count))
                break
            }
        }
        return w
    }
    
    // Добавление файла (поддерживает .pdf, .txt, .md)
    public func addDocument(name: String, content: String) {
        let chunks = splitIntoChunks(text: content, chunkSize: 500, overlap: 100)
        var newChunks: [DocumentChunk] = []
        
        for cText in chunks {
            let tokens = RAGTool.tokenize(cText)
            if !tokens.isEmpty {
                newChunks.append(DocumentChunk(sourceName: name, text: cText, tokens: tokens))
            }
        }
        
        indexedDocuments.removeAll { $0.sourceName == name }
        indexedDocuments.append(contentsOf: newChunks)
        documentsMeta.removeAll { $0.name == name }
        documentsMeta.append(IndexedDocumentMeta(id: UUID(), name: name, chunkCount: newChunks.count, dateAdded: Date()))
        saveData()
    }
    
    // Импорт документа по URL (например, через UIDocumentPicker)
    public func importDocument(url: URL) -> (success: Bool, message: String) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent
        
        if ext == "pdf" {
            guard let pdf = PDFDocument(url: url) else {
                return (false, "Не удалось открыть PDF документ.")
            }
            var fullText = ""
            for i in 0..<pdf.pageCount {
                if let page = pdf.page(at: i), let pageText = page.string {
                    fullText += pageText + "\n"
                }
            }
            if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (false, "В PDF не найдено текстового слоя.")
            }
            addDocument(name: name, content: fullText)
            return (true, "PDF «\(name)» успешно проиндексирован!")
        } else {
            // Текстовый файл или Markdown
            guard let text = try? String(contentsOf: url, encoding: .utf8) ?? String(contentsOf: url, encoding: .windowsCP1251) else {
                return (false, "Не удалось прочитать текст файла.")
            }
            addDocument(name: name, content: text)
            return (true, "Документ «\(name)» успешно добавлен в память кота!")
        }
    }
    
    // Удаление документа
    public func removeDocument(name: String) {
        indexedDocuments.removeAll { $0.sourceName == name }
        documentsMeta.removeAll { $0.name == name }
        saveData()
    }
    
    // Очистить всю базу
    public func clearAll() {
        indexedDocuments.removeAll()
        documentsMeta.removeAll()
        try? FileManager.default.removeItem(at: chunksStorageURL)
        try? FileManager.default.removeItem(at: metaStorageURL)
    }
    
    // Полноценный поиск BM25
    public func searchKnowledge(query: String, topK: Int = 3) -> String {
        let queryTokens = RAGTool.tokenize(query)
        guard !queryTokens.isEmpty, !indexedDocuments.isEmpty else { return "" }
        
        let totalDocs = Double(indexedDocuments.count)
        let avgDocLen = Double(indexedDocuments.reduce(0) { $0 + $1.tokens.count }) / totalDocs
        
        // 1. Расчет Document Frequency (DF) для каждого токена запроса
        var df: [String: Double] = [:]
        for qTok in Set(queryTokens) {
            let count = indexedDocuments.filter { $0.tokens.contains(qTok) }.count
            df[qTok] = Double(count)
        }
        
        // 2. Скоринг каждого чанка по формуле BM25
        var scoredResults: [(chunk: DocumentChunk, score: Double)] = []
        
        for chunk in indexedDocuments {
            var chunkScore: Double = 0.0
            let docLen = Double(chunk.tokens.count)
            
            // Term Frequency (TF) внутри чанка
            var tf: [String: Double] = [:]
            for t in chunk.tokens { tf[t, default: 0.0] += 1.0 }
            
            for qTok in queryTokens {
                let termFreq = tf[qTok] ?? 0.0
                guard termFreq > 0 else { continue }
                
                let docFreq = df[qTok] ?? 0.0
                // Формула Robertson-Spärck Jones IDF
                let idf = log((totalDocs - docFreq + 0.5) / (docFreq + 0.5) + 1.0)
                
                let numerator = termFreq * (k1 + 1.0)
                let denominator = termFreq + k1 * (1.0 - b + b * (docLen / max(1.0, avgDocLen)))
                chunkScore += idf * (numerator / denominator)
            }
            
            if chunkScore > 0.0 {
                scoredResults.append((chunk, chunkScore))
            }
        }
        
        scoredResults.sort { $0.score > $1.score }
        let topResults = scoredResults.prefix(topK)
        
        if topResults.isEmpty { return "" }
        
        return topResults.map {
            "📄 [Источник: \($0.chunk.sourceName)]\n\($0.chunk.text)"
        }.joined(separator: "\n\n---\n\n")
    }
    
    private func splitIntoChunks(text: String, chunkSize: Int, overlap: Int) -> [String] {
        var chunks: [String] = []
        let clean = text.replacingOccurrences(of: "\r\n", with: "\n")
        var startIndex = clean.startIndex
        
        while startIndex < clean.endIndex {
            let endIndex = clean.index(startIndex, offsetBy: chunkSize, limitedBy: clean.endIndex) ?? clean.endIndex
            let chunkStr = String(clean[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunkStr.isEmpty {
                chunks.append(chunkStr)
            }
            if endIndex == clean.endIndex { break }
            startIndex = clean.index(startIndex, offsetBy: max(1, chunkSize - overlap), limitedBy: clean.endIndex) ?? clean.endIndex
        }
        return chunks
    }
    
    private func saveData() {
        let chunks = indexedDocuments
        let metadata = documentsMeta
        storageQueue.async { [weak self] in
            guard let self = self else { return }
            if let data = try? JSONEncoder().encode(chunks) {
                try? data.write(to: self.chunksStorageURL, options: .atomic)
            }
            if let metaData = try? JSONEncoder().encode(metadata) {
                try? metaData.write(to: self.metaStorageURL, options: .atomic)
            }
        }
    }
    
    private func loadData() {
        if let data = try? Data(contentsOf: chunksStorageURL),
           let chunks = try? JSONDecoder().decode([DocumentChunk].self, from: data) {
            self.indexedDocuments = chunks
        }
        if let metaData = try? Data(contentsOf: metaStorageURL),
           let metas = try? JSONDecoder().decode([IndexedDocumentMeta].self, from: metaData) {
            self.documentsMeta = metas
        }
    }
}
