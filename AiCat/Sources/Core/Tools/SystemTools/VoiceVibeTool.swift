import Foundation

public struct VoiceVibeResult {
    public let dominantEmotion: String
    public let stressLevel: Int // 0-100%
    public let energyLevel: Int // 0-100%
    public let catAdvice: String
}

public final class VoiceVibeTool {
    public static let shared = VoiceVibeTool()
    
    private init() {}
    
    // Анализ речи и тембра голоса
    public func analyzeVibe(transcribedText: String, pitchVariation: Float = 0.5) -> VoiceVibeResult {
        let lower = transcribedText.lowercased()
        
        let stressKeywords = ["устал", "тяжело", "бесит", "надоело", "стресс", "проблема", "срочно", "горю", "дедлайн"]
        let happyKeywords = ["ура", "круто", "отлично", "кайф", "супер", "получилось", "люблю", "рад"]
        
        var isStressed = false
        var isHappy = false
        
        for word in stressKeywords {
            if lower.contains(word) { isStressed = true; break }
        }
        for word in happyKeywords {
            if lower.contains(word) { isHappy = true; break }
        }
        
        if isStressed {
            return VoiceVibeResult(
                dominantEmotion: "Напряжение / Усталость",
                stressLevel: 78,
                energyLevel: 35,
                catAdvice: "Кожаный, слышу по голосу — батарейка садится. Предлагаю бросить всё на 5 минут: я включу тебе кошачий Lo-Fi бит или сделаем быструю растяжку спины!"
            )
        } else if isHappy {
            return VoiceVibeResult(
                dominantEmotion: "Бодрость и драйв",
                stressLevel: 15,
                energyLevel: 92,
                catAdvice: "Ого, да ты сегодня на кураже! Голос звенит, как открывающаяся банка с тунцом. Направь эту энергию в дело!"
            )
        } else {
            return VoiceVibeResult(
                dominantEmotion: "Спокойная сосредоточенность",
                stressLevel: 28,
                energyLevel: 70,
                catAdvice: "Голос ровный, уверенный. Ты в идеальном балансе. Продолжай в том же духе, я прикрываю тебя из Dynamic Island."
            )
        }
    }
}
