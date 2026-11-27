import ActivityKit
import WidgetKit
import SwiftUI

struct AiCatLiveActivity: Widget {
    init() {}

    private func islandState(for mood: String) -> String {
        switch mood {
        case "💤": return "sleep"
        case "🤔", "🧠": return "think"
        default: return "peek"
        }
    }
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: AiCatAttributes.self) { context in
            let saying = DailySaying.forDay(Date())
            HStack(spacing: 10) {
                CatPicture(scene: "idle", islandSide: "leading", outfit: context.state.outfit, islandState: "peek")
                    .frame(width: 38, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(saying.text).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    Text(saying.source).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .activityBackgroundTint(.clear)
            .widgetURL(URL(string: "aicat://chat"))
        } dynamicIsland: { context in
            let mood = context.isStale ? "😼" : context.state.moodEmoji
            return DynamicIsland {
                // Развернутый вид (по долгому тапу на Dynamic Island)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        CatPicture(scene: CatSnapshot.scene(mood: mood), outfit: context.state.outfit)
                            .frame(width: 40, height: 40)
                        Text("AiCat")
                            .font(.headline)
                            .bold()
                            .foregroundColor(.white)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.isStale ? "В комнате" : context.state.currentAction)
                        .font(.caption)
                        .bold()
                        .foregroundColor(.cyan)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.isStale ? "Загляни к коту" : context.state.statusMessage)
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                        Button(intent: CareForCatIntent(.pet)) { Image(systemName: "heart.fill") }
                            .accessibilityLabel("Погладить")
                        Button(intent: CareForCatIntent(.feed)) { Image(systemName: "fish.fill") }
                            .accessibilityLabel("Покормить")
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // Левая часть компактного Dynamic Island
                CatPicture(scene: CatSnapshot.scene(mood: mood), islandSide: "leading", outfit: context.state.outfit, islandState: islandState(for: mood))
                    .frame(width: 34, height: 24).id(mood).transition(.opacity)
            } compactTrailing: {
                // Правая часть компактного Dynamic Island
                if ["🐟", "🧶", "👅", "😻", "💻"].contains(mood) {
                    Text(mood).font(.caption).id(mood).transition(.opacity)
                } else {
                    CatPicture(scene: CatSnapshot.scene(mood: mood), islandSide: "trailing", outfit: context.state.outfit, islandState: islandState(for: mood))
                        .frame(width: 24, height: 22)
                }
            } minimal: {
                // Минимальный вид (когда активно несколько приложений)
                CatPicture(scene: CatSnapshot.scene(mood: mood), islandSide: "leading", outfit: context.state.outfit, islandState: islandState(for: mood))
                    .frame(width: 24, height: 24)
            }
            .widgetURL(URL(string: "aicat://chat"))
        }
        .contentMarginsDisabled()
    }
}
