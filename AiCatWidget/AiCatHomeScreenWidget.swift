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
        var cat = CatSnapshot.load().projected(at: now)
        var dates = [now]
        if cat.actionUntil > now {
            dates.append(max(cat.actionUntil, now.addingTimeInterval(300)))
        }
        let firstTick = (floor(now.timeIntervalSince1970 / 900) + 1) * 900
        dates += (0..<96).map { Date(timeIntervalSince1970: firstTick + Double($0) * 900) }
        let entries = Set(dates).sorted().map { date in
            cat = cat.projected(at: date)
            return AiCatHomeScreenEntry(date: date, cat: cat)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct AiCatHomeScreenWidgetView: View {
    let entry: AiCatHomeScreenEntry

    var body: some View {
        CatPicture(scene: entry.cat.action, outfit: entry.cat.outfit)
            .padding(10)
            .id(entry.cat.action)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.5), value: entry.cat.action)
            .widgetURL(URL(string: "aicat://room"))
            .containerBackground(for: .widget) { Color.clear }
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
        .contentMarginsDisabled()
    }
}
