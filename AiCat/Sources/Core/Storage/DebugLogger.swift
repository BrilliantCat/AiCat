import Combine
import Foundation
import UIKit
import Darwin

public enum LogLevel: String, Codable {
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
    case ram = "RAM"
    
    public var emoji: String {
        switch self {
        case .info: return "ℹ️"
        case .warn: return "⚠️"
        case .error: return "🛑"
        case .ram: return "⚡"
        }
    }
}

public struct LogEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let level: LogLevel
    public let message: String
    public let tag: String
    
    public init(id: UUID = UUID(), timestamp: Date = Date(), level: LogLevel, message: String, tag: String = "AiCat") {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.tag = tag
    }
    
    public var formattedTime: String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        return df.string(from: timestamp)
    }
}

public final class DebugLogger: ObservableObject {
    public static let shared = DebugLogger()
    
    @Published public private(set) var entries: [LogEntry] = []
    @Published public private(set) var currentMemoryMB: Double = 0.0
    
    private let fileQueue = DispatchQueue(label: "AiCat.LogFile")
    private let maxEntries = 500
    private var memoryTimer: Timer?
    
    private var logFileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("debug_runtime.log")
    }
    
    private init() {
        log("Диспетчер логов AiCat инициализирован", level: .info, tag: "System")
        updateMemoryUsage()
        startMemoryMonitoring()
    }
    
    public func log(_ message: String, level: LogLevel = .info, tag: String = "AiCat") {
        let entry = LogEntry(level: level, message: message, tag: tag)
        let line = "[\(entry.formattedTime)] [\(level.rawValue)] [\(tag)] \(message)\n"
        print(line, terminator: "")
        fileQueue.async { self.appendToFile(line) }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.entries.append(entry)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
    }
    
    public func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.entries.removeAll()
        }
        if let url = logFileURL {
            fileQueue.sync { try? FileManager.default.removeItem(at: url) }
        }
        log("Журнал отладки очищен", level: .info, tag: "Debug")
    }
    
    public func exportLogs() -> String {
        return entries.map { "[\($0.formattedTime)] [\($0.level.rawValue)] [\($0.tag)] \($0.message)" }.joined(separator: "\n")
    }
    
    public func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            let mb = Double(info.resident_size) / (1024.0 * 1024.0)
            DispatchQueue.main.async { [weak self] in
                self?.currentMemoryMB = mb
            }
        }
    }
    
    private func startMemoryMonitoring() {
        DispatchQueue.main.async { [weak self] in
            self?.memoryTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                self?.updateMemoryUsage()
            }
        }
    }
    
    private func appendToFile(_ text: String) {
        guard let url = logFileURL, let data = text.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}
