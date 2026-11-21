import ActivityKit
import WidgetKit
import SwiftUI

public struct AiCatLiveActivity: Widget {
    public init() {}
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: AiCatAttributes.self) { context in
            // Экран блокировки (Lock Screen Banner)
            HStack(spacing: 14) {
                Text(context.state.moodEmoji)
                    .font(.system(size: 38))
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
            .activityBackgroundTint(Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.95))
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Развернутый вид (по долгому тапу на Dynamic Island)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Text(context.state.moodEmoji)
                            .font(.title2)
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
                        Text("A17 Pro")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // Левая часть компактного Dynamic Island
                Text(context.state.moodEmoji)
                    .font(.system(size: 14))
            } compactTrailing: {
                // Правая часть компактного Dynamic Island
                Text("AiCat")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
            } minimal: {
                // Минимальный вид (когда активно несколько приложений)
                Text(context.state.moodEmoji)
                    .font(.system(size: 12))
            }
        }
    }
}
