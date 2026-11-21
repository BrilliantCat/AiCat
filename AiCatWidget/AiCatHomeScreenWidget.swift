import WidgetKit
import SwiftUI

public struct AiCatHomeScreenEntry: TimelineEntry {
    public let date: Date
    public let statusText: String
    public let moodEmoji: String
    public let satiety: Int
    public let happiness: Int
}

public struct AiCatHomeScreenWidgetProvider: TimelineProvider {
    public func placeholder(in context: Context) -> AiCatHomeScreenEntry {
        AiCatHomeScreenEntry(date: Date(), statusText: "Мурчит на солнышке", moodEmoji: "😼", satiety: 85, happiness: 90)
    }

    public func getSnapshot(in context: Context, completion: @escaping (AiCatHomeScreenEntry) -> Void) {
        let entry = AiCatHomeScreenEntry(date: Date(), statusText: "Готов к командам", moodEmoji: "😼", satiety: 85, happiness: 90)
        completion(entry)
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<AiCatHomeScreenEntry>) -> Void) {
        let entry = AiCatHomeScreenEntry(date: Date(), statusText: "AiCat на страже в A17 Pro", moodEmoji: "😼", satiety: 85, happiness: 90)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 15)))
        completion(timeline)
    }
}

public struct AiCatHomeScreenWidgetView: View {
    var entry: AiCatHomeScreenWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    public var body: some View {
        if #available(iOS 17.0, *) {
            content
                .containerBackground(Color(red: 0.1, green: 0.11, blue: 0.15), for: .widget)
        } else {
            content
                .background(Color(red: 0.1, green: 0.11, blue: 0.15))
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if family == .systemSmall {
            VStack(spacing: 6) {
                HStack {
                    Text("AiCat")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.cyan)
                    Spacer()
                    Text("🐟 \(entry.satiety)%")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Text(entry.moodEmoji)
                    .font(.system(size: 44))
                
                Text(entry.statusText)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(8)
        } else {
            // SystemMedium
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("AiCat")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(entry.moodEmoji)
                            .font(.title3)
                    }
                    Text(entry.statusText)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Text("🐟 Сытость: \(entry.satiety)%")
                            .font(.caption2)
                            .foregroundColor(.cyan)
                        Text("❤️ Счастье: \(entry.happiness)%")
                            .font(.caption2)
                            .foregroundColor(.pink)
                    }
                }
                
                Spacer()
                
                // Индикатор состояния
                VStack(spacing: 6) {
                    Text(entry.moodEmoji)
                        .font(.system(size: 36))
                    Text("A17 Pro")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(14)
        }
    }
}

public struct AiCatHomeScreenWidget: Widget {
    public let kind: String = "AiCatHomeScreenWidget"

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AiCatHomeScreenWidgetProvider()) { entry in
            AiCatHomeScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("AiCat Маскот")
        .description("Живой кот на твоем рабочем столе с индикатором настроения и сытости.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
