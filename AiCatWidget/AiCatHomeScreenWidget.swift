import WidgetKit
import SwiftUI

struct AiCatHomeScreenEntry: TimelineEntry {
    let date: Date
    let cat: CatSnapshot
}

struct AiCatHomeScreenWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AiCatHomeScreenEntry {
        AiCatHomeScreenEntry(date: Date(), cat: CatSnapshot())
    }
    func getSnapshot(in context: Context, completion: @escaping (AiCatHomeScreenEntry) -> Void) {
        completion(AiCatHomeScreenEntry(date: Date(), cat: CatSnapshot.load().projected(at: Date())))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AiCatHomeScreenEntry>) -> Void) {
        let now = Date()
        let snapshot = CatSnapshot.load()
        let entries = (0..<96).map { index in
            let date = now.addingTimeInterval(Double(index) * 900)
            return AiCatHomeScreenEntry(date: date, cat: snapshot.projected(at: date))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct AiCatHomeScreenWidgetView: View {
    let entry: AiCatHomeScreenEntry
    var body: some View {
        VStack(spacing: 4) {
            CatPicture(scene: entry.cat.action)
            Text(entry.cat.label).font(.caption).foregroundStyle(.white)
            HStack {
                Text("🐟 \(entry.cat.satiety)%")
                Text("❤️ \(entry.cat.happiness)%")
            }.font(.caption2).foregroundStyle(.white)
        }
        .widgetURL(URL(string: "aicat://chat"))
        .containerBackground(Color(red: 0.1, green: 0.11, blue: 0.15), for: .widget)
    }
}

struct AiCatHomeScreenWidget: Widget {
    let kind = "AiCatHomeScreenWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AiCatHomeScreenWidgetProvider()) {
            AiCatHomeScreenWidgetView(entry: $0)
        }
        .configurationDisplayName("AiCat")
        .description("Кот играет, умывается и отдыхает в течение дня.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
