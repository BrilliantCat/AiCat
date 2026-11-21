import Foundation

public final class TranslatorTool {
    public static let shared = TranslatorTool()
    
    private init() {}
    
    // Промпт для режима мгновенного офлайн перевода через модель Qwen
    public func buildTranslationPrompt(text: String, targetLanguage: String = "английский") -> String {
        return """
        ТЫ — ПРОФЕССИОНАЛЬНЫЙ СИНХРОННЫЙ ПЕРЕВОДЧИК.
        Задача: Переведи следующий текст на \(targetLanguage).
        Правила:
        - Переводи точно, естественно и идиоматично.
        - Сохраняй юмор, сленг и эмоции оригинала.
        - Выведи ТОЛЬКО готовый перевод, без вводных слов и кавычек.
        
        ТЕКСТ ДЛЯ ПЕРЕВОДА:
        \(text)
        """
    }
}
