import ActivityKit
import Foundation

public struct AiCatAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var statusMessage: String
        public var moodEmoji: String
        public var currentAction: String
        public var isHanging: Bool
        public var isListening: Bool
        
        public init(statusMessage: String, moodEmoji: String, currentAction: String, isHanging: Bool, isListening: Bool) {
            self.statusMessage = statusMessage
            self.moodEmoji = moodEmoji
            self.currentAction = currentAction
            self.isHanging = isHanging
            self.isListening = isListening
        }
    }
    
    public var catName: String
    
    public init(catName: String = "AiCat") {
        self.catName = catName
    }
}
