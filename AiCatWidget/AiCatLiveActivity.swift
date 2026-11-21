import ActivityKit
import WidgetKit
import SwiftUI

public struct AiCatLiveActivity: Widget {
    public init() {}
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: AiCatAttributes.self) { context in
            // Banner presentation for Lock Screen / Notification Center
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.8))
                        .frame(width: 50, height: 50)
                    Text(context.state.moodEmoji)
                        .font(.system(size: 28))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(context.attributes.catName)
                            .font(.headline)
                            .foregroundColor(.white)
                        if context.state.isHanging {
                            Text("🐾 На лапках")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.3))
                                .cornerRadius(8)
                                .foregroundColor(.orange)
                        }
                    }
                    Text(context.state.statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: context.state.isListening ? "waveform.circle.fill" : "pawprint.fill")
                    .font(.title2)
                    .foregroundColor(context.state.isListening ? .green : .cyan)
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.9))
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded View (когда зажимаешь островок)
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Text(context.state.moodEmoji)
                            .font(.system(size: 32))
                        VStack(alignment: .leading) {
                            Text(context.attributes.catName)
                                .font(.headline)
                                .bold()
                            Text(context.state.currentAction)
                                .font(.caption2)
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding(.leading, 8)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        if context.state.isListening {
                            HStack(spacing: 4) {
                                Circle().fill(Color.red).frame(width: 6, height: 6)
                                Text("Слушаю...")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        } else {
                            Text("Офлайн A17 Pro")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.trailing, 8)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        Text(context.state.statusMessage)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        // Быстрые кнопки действий прямо в Dynamic Island
                        HStack(spacing: 12) {
                            Button(intent: WakeAiCatVoiceIntent()) {
                                Label("Сказать", systemImage: "mic.fill")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(12)
                            }
                            
                            Button(intent: HangCatIntent()) {
                                Label("Повисни", systemImage: "arrow.down.to.line")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
            } compactLeading: {
                // Левая часть островка в свернутом виде
                HStack(spacing: 3) {
                    Text(context.state.moodEmoji)
                        .font(.system(size: 14))
                    if context.state.isHanging {
                        Text("🐾")
                            .font(.system(size: 10))
                    }
                }
            } compactTrailing: {
                // Правая часть островка в свернутом виде
                if context.state.isListening {
                    Image(systemName: "waveform")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(.cyan)
                }
            } minimal: {
                // Минимальный кругляшок
                Text(context.state.moodEmoji)
                    .font(.system(size: 12))
            }
        }
    }
}
