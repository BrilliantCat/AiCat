import ActivityKit
import WidgetKit
import SwiftUI

struct AiCatLiveActivity: Widget {
    init() {}
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: AiCatAttributes.self) { context in
            // Экран блокировки (Lock Screen Banner)
            HStack(spacing: 14) {
                CatPicture(scene: CatSnapshot.scene(mood: context.state.moodEmoji), outfit: context.state.outfit)
                    .frame(width: 64, height: 64)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("AiCat")
                            .font(.headline)
                            .bold()
                            .foregroundColor(.white)
                        Text("•")
                            .foregroundColor(.gray)
                        Text(context.state.currentAction)
                            .font(.subheadline)
                            .foregroundColor(.cyan)
                    }
                    Text(context.state.statusMessage)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding()
            .widgetURL(URL(string: "aicat://chat"))
            .activityBackgroundTint(Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.95))
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Развернутый вид (по долгому тапу на Dynamic Island)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        CatPicture(scene: CatSnapshot.scene(mood: context.state.moodEmoji), outfit: context.state.outfit)
                            .frame(width: 40, height: 40)
                        Text("AiCat")
                            .font(.headline)
                            .bold()
                            .foregroundColor(.white)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.currentAction)
                        .font(.caption)
                        .bold()
                        .foregroundColor(.cyan)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.statusMessage)
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                        Text("Офлайн 🐾")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // Левая часть компактного Dynamic Island
                CatPicture(scene: CatSnapshot.scene(mood: context.state.moodEmoji), islandSide: "leading", outfit: context.state.outfit)
                    .frame(width: 26, height: 26)
            } compactTrailing: {
                // Правая часть компактного Dynamic Island
                CatPicture(scene: CatSnapshot.scene(mood: context.state.moodEmoji), islandSide: "trailing", outfit: context.state.outfit)
                    .frame(width: 26, height: 26)
            } minimal: {
                // Минимальный вид (когда активно несколько приложений)
                CatPicture(scene: CatSnapshot.scene(mood: context.state.moodEmoji), outfit: context.state.outfit)
                    .frame(width: 24, height: 24)
            }
            .widgetURL(URL(string: "aicat://chat"))
        }
    }
}
