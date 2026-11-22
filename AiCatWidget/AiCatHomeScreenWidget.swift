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
    @Environment(\.widgetFamily) private var family
    private var sharedStateAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: CatSnapshot.group) != nil
    }
    var body: some View {
        Group {
            if family == .systemMedium {
                HStack(spacing: 18) {
                    CatPicture(scene: entry.cat.action, outfit: entry.cat.outfit).frame(width: 112, height: 112)
                    details
                    Spacer(minLength: 0)
                }
            } else {
                VStack(spacing: 8) {
                    CatPicture(scene: entry.cat.action, outfit: entry.cat.outfit).frame(maxHeight: 88)
                    details
                }
            }
        }
        .widgetURL(URL(string: "aicat://chat"))
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(red: 0.12, green: 0.18, blue: 0.22),
                                    Color(red: 0.10, green: 0.10, blue: 0.16)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    private var details: some View {
        VStack(alignment: family == .systemMedium ? .leading : .center, spacing: 6) {
            Text("AiCat").font(.system(.headline, design: .rounded)).foregroundStyle(.white)
            Text(entry.cat.label).font(.caption).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
            if sharedStateAvailable {
                HStack(spacing: 10) {
                    Label("\(entry.cat.satiety)%", systemImage: "fish.fill").foregroundStyle(.mint)
                    Label("\(entry.cat.happiness)%", systemImage: "heart.fill").foregroundStyle(.pink)
                }.font(.caption2)
            } else {
                Text("Загляни к коту").font(.caption2).foregroundStyle(.mint)
            }
        }
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
