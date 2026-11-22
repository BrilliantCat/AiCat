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
    @Environment(\.widgetFamily) private var family
    private var wide: Bool { family == .systemMedium }
    var body: some View {
        GeometryReader { bounds in
            ZStack(alignment: wide ? .trailing : .bottom) {
                if let image = CatPicture.artwork(named: entry.cat.roomArtwork, folder: "widget") {
                    roomImage(image, size: bounds.size)
                        .scaleEffect(entry.cat.action == "purr" ? 1.065 : 1,
                                     anchor: wide ? .leading : .center)
                        .id(entry.cat.roomArtwork)
                        .transition(.opacity)
                } else {
                    CatPicture(scene: entry.cat.action, outfit: entry.cat.outfit)
                }
                VStack(alignment: wide ? .leading : .center, spacing: wide ? 7 : 1) {
                    Text(entry.cat.label)
                        .font(.system(wide ? .headline : .caption, design: .rounded, weight: .semibold))
                        .lineLimit(2)
                    if wide && CatSnapshot.sharedDefaults != nil {
                        Label("\(entry.cat.satiety)%", systemImage: "fish.fill").font(.caption)
                    }
                    HStack(spacing: 3) {
                        careButton(.pet, symbol: "heart.fill", title: "Погладить")
                        careButton(.feed, symbol: "fish.fill", title: "Покормить")
                        careButton(.play, symbol: "tennisball.fill", title: "Поиграть")
                    }
                }
                .foregroundStyle(.white)
                .padding(wide ? 12 : 4)
                .frame(width: wide ? bounds.size.width * 0.45 : bounds.size.width)
            }
            .frame(width: bounds.size.width, height: bounds.size.height)
            .clipped()
            .animation(.easeInOut(duration: 0.5), value: entry.cat.action)
        }
        .widgetURL(URL(string: "aicat://room"))
        .containerBackground(for: .widget) { Color(white: 0.10) }
    }

    private func roomImage(_ image: UIImage, size: CGSize) -> some View {
        ZStack(alignment: .leading) {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(width: size.width, height: size.height).clipped()
            if wide {
                Rectangle().fill(.ultraThinMaterial)
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: size.height * 1.22, height: size.height).clipped()
                    .mask(LinearGradient(stops: [.init(color: .white, location: 0.78),
                                                  .init(color: .clear, location: 1)],
                                         startPoint: .leading, endPoint: .trailing))
            }
            LinearGradient(colors: [.clear, .black.opacity(wide ? 0.62 : 0.84)],
                           startPoint: wide ? .center : .init(x: 0.5, y: 0.53),
                           endPoint: wide ? .trailing : .bottom)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func careButton(_ care: CatCare, symbol: String, title: String) -> some View {
        let icon = Image(systemName: symbol).font(.footnote)
            .frame(minWidth: 33, minHeight: 30)
            .background(.black.opacity(0.52), in: Capsule())
        if CatSnapshot.sharedDefaults != nil {
            Button(intent: CareForCatIntent(care)) { icon }
                .buttonStyle(.plain).accessibilityLabel(title)
                .disabled(care == .play && (entry.cat.sleeping || entry.cat.energy < 20))
        } else if let url = URL(string: "aicat://room?care=\(care.rawValue)") {
            Link(destination: url) { icon }.accessibilityLabel(title + " в комнате")
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
        .contentMarginsDisabled()
    }
}
