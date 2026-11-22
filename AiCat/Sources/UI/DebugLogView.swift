import SwiftUI

public struct DebugLogView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var logger = DebugLogger.shared
    @State private var filterLevel: LogLevel? = nil
    @State private var copiedAlert: Bool = false
    
    public init() {}
    
    private var filteredEntries: [LogEntry] {
        if let level = filterLevel {
            return logger.entries.filter { $0.level == level }
        }
        return logger.entries
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.08, blue: 0.11).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // RAM Monitor & System Stats Bar
                    ramStatusBar
                    
                    // Filter Chips
                    filterBar
                    
                    // Terminal Log List
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 6) {
                                if filteredEntries.isEmpty {
                                    Text("Логи отсутствуют")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.gray)
                                        .padding()
                                } else {
                                    ForEach(filteredEntries) { entry in
                                        logRow(entry)
                                            .id(entry.id)
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                        }
                    }
                    
                    // Bottom Controls
                    bottomControls
                }
            }
            .navigationTitle("Терминал отладки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
    }
    
    private var ramStatusBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("RAM:")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f MB", logger.currentMemoryMB))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(memoryColor)
                    Text("/ 2048 MB")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule()
                            .fill(memoryColor)
                            .frame(width: min(geo.size.width * CGFloat(logger.currentMemoryMB / 2048.0), geo.size.width))
                    }
                }
                .frame(height: 4)
            }
            
            Spacer()
            
            Button(action: { logger.updateMemoryUsage() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundColor(.cyan)
                    .padding(6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.4))
    }
    
    private var memoryColor: Color {
        if logger.currentMemoryMB > 1600 { return .red }
        if logger.currentMemoryMB > 1000 { return .yellow }
        return .cyan
    }
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip(title: "Все (\(logger.entries.count))", level: nil)
                filterChip(title: "⚠️ Ошибки", level: .error)
                filterChip(title: "⚡ RAM", level: .ram)
                filterChip(title: "ℹ️ Инфо", level: .info)
                filterChip(title: "⚠️ Предупреждения", level: .warn)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color.black.opacity(0.2))
    }
    
    private func filterChip(title: String, level: LogLevel?) -> some View {
        Button(action: { filterLevel = level }) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(filterLevel == level ? Color.cyan.opacity(0.3) : Color.white.opacity(0.06))
                .foregroundColor(filterLevel == level ? .cyan : .gray)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(filterLevel == level ? Color.cyan.opacity(0.6) : Color.clear, lineWidth: 1)
                )
        }
    }
    
    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(entry.formattedTime)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 65, alignment: .leading)
            
            Text("[\(entry.tag)]")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan.opacity(0.8))
                .frame(width: 55, alignment: .leading)
            
            Text(entry.message)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(entryColor(entry.level))
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(entry.level == .error ? Color.red.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
    
    private func entryColor(_ level: LogLevel) -> Color {
        switch level {
        case .info: return .white.opacity(0.9)
        case .warn: return .yellow
        case .error: return .red
        case .ram: return .cyan
        }
    }
    
    private var bottomControls: some View {
        HStack(spacing: 12) {
            Button(action: copyToClipboard) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                    Text("Копировать")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
            }
            
            Button(action: { logger.clear() }) {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("Очистить")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.red.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.15))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.5))
        .alert("Логи скопированы в буфер обмена!", isPresented: $copiedAlert) {
            Button("ОК", role: .cancel) {}
        }
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = logger.exportLogs()
        copiedAlert = true
    }
}
