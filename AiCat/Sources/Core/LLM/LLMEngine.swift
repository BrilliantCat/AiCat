import Foundation
import UIKit

public final class LLMEngine: ObservableObject {
    public static let shared = LLMEngine()
    
    @Published public var isGenerating: Bool = false
    @Published public var lastToolExecuted: String? = nil
    
    private init() {}
    
    // Асинхронный цикл агента: Запрос -> (Поиск RAG) -> Модель / Диспетчер -> Вызов инструмента -> Финальный ответ
    public func generate(prompt: String, context: String = "") async -> (text: String, image: UIImage?) {
        await MainActor.run { self.isGenerating = true }
        defer { Task { @MainActor in self.isGenerating = false } }
        
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ("*Кот с любопытством посмотрел на тебя из-под черных очков*: Ты позвал меня, но молчишь, кожаный! Чего задумал?", nil)
        }
        
        // 1. Извлекаем контекст из локальной базы знаний (RAG BM25)
        let ragContext = RAGTool.shared.searchKnowledge(query: trimmed, topK: 2)
        
        // 2. Проверяем наличие установленной GGUF модели
        let isModelLoaded = await MainActor.run { ModelManager.shared.isModelLoaded }
        
        // 3. Выполняем инференс или интеллектуальный живой офлайн-диалог
        if isModelLoaded {
            return await runGGUFAgentLoop(userPrompt: trimmed, ragContext: ragContext)
        } else {
            return await runDirectToolAgentLoop(userPrompt: trimmed, ragContext: ragContext)
        }
    }
    
    // Агентский цикл с реальным парсингом JSON вызова инструментов
    private func runGGUFAgentLoop(userPrompt: String, ragContext: String) async -> (text: String, image: UIImage?) {
        let systemPrompt = PromptBuilder.buildSystemPrompt(ragContext: ragContext)
        let moodPrompt = await MainActor.run { TamagotchiManager.shared.moodContextPrompt() }
        let fullSystem = systemPrompt + "\n" + moodPrompt
        
        // Запрос к модели Qwen 2.5
        let rawModelOutput = await ModelManager.shared.infer(prompt: userPrompt, system: fullSystem)
        
        // Парсинг JSON-вызова инструмента
        if let toolCall = parseToolCall(from: rawModelOutput) {
            let toolRes = await ToolRegistry.shared.executeTool(name: toolCall.tool, parameters: toolCall.parameters ?? [:])
            await MainActor.run { self.lastToolExecuted = toolCall.tool }
            
            // Если инструмент вернул reply_text из JSON модели
            if let customReply = toolCall.reply_text, !customReply.isEmpty {
                return (customReply, toolRes.image)
            }
            return (toolRes.result, toolRes.image)
        }
        
        return (rawModelOutput, nil)
    }
    
    // Живой разговорный диспетчер кота (без дурацких технических отсылок к железу!)
    private func runDirectToolAgentLoop(userPrompt: String, ragContext: String) async -> (text: String, image: UIImage?) {
        let lower = userPrompt.lowercased()
        let words = lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let wordSet = Set(words)
        
        func hasWord(_ target: String) -> Bool { wordSet.contains(target) }
        func hasAnyWord(_ targets: [String]) -> Bool { !wordSet.isDisjoint(with: targets) }
        
        // 1. САМОЧУВСТВИЕ И РАЗГОВОР ПО ДУШАМ
        if lower.contains("как дела") || lower.contains("как жизнь") || lower.contains("как настроение") || lower.contains("как ты") {
            let (satiety, happiness) = await MainActor.run { (TamagotchiManager.shared.satiety, TamagotchiManager.shared.happiness) }
            if satiety < 40 {
                return ("Дела были бы в сто раз лучше, если бы в моей миске появилась свежая рыбка! Нажми 'Покормить', и я буду мурчать без умолку.", nil)
            } else if happiness < 40 {
                return ("Скучновато без твоих почесываний за ушком. Погладь меня, кожаный, подними кошачье настроение!", nil)
            } else {
                let replies = [
                    "Дела — просто блеск! Мурчу от удовольствия, лапы размяты, темные очки начищены. У тебя как день проходит?",
                    "Настроение шикарное, боевое! Готов составить компанию, поболтать или посчитать твои отжимания. Чем займемся?",
                    "Всё под контролем, кожаный! Сыт, доволен, слежу за порядком на твоем экране. Рассказывай, что нового?"
                ]
                return (replies.randomElement()!, nil)
            }
        }
        
        // Эмоциональные реплики хозяина
        if lower.contains("я устал") || lower.contains("тяжелый день") || lower.contains("сил нет") {
            return ("*Лег рядом и мягко заурчал*. Бросай все заботы, кожаный. Ложись отдыхать, а я постерегу твой покой. Заслуженный релакс!", nil)
        }
        if lower.contains("скучно") || lower.contains("развлеки") {
            return ("Скучно? Серьезно? А ну быстро: либо давай скручу тебе сальто, либо надевай кроссовки и погнали отжиматься! Что выбираешь?", nil)
        }
        if lower.contains("ты лучший") || lower.contains("красавчик") || lower.contains("люблю тебя") || lower.contains("молодец") {
            _ = await MainActor.run { TamagotchiManager.shared.petCat() }
            return ("*Довольно прищурился за темными очками и замурчал на всю комнату*. Естественно! Я же лучший кот во всей вселенной. Мур-мяу!", nil)
        }
        
        // Приветствия
        if hasAnyWord(["привет", "здравствуй", "салют", "хай", "мяу", "хеллоу", "вечер", "утро"]) {
            let greetings = [
                "Мяу! Здорово, кожаный. Я на связи, темные очки на мордочке, хвост трубой. О чем поболтаем?",
                "Салют! Рад тебя слышать. Я как раз полировал очки и думал, чем ты меня сегодня порадуешь. Что на уме?",
                "Привет-привет! Миска полная, настроение бодрое. Чем озадачишь своего любимого кота?",
                "О, ты вернулся! Я уже успел подремать и проверить обстановку. Готов к любым делам!"
            ]
            return (greetings.randomElement()!, nil)
        }
        
        // 2. ФИЗИЧЕСКИЕ КОМАНДЫ КОТУ (cat_action)
        if hasAnyWord(["помойся", "умойся", "умыться"]) {
            let res = await ToolRegistry.shared.executeTool(name: "cat_action", parameters: ["action": "wash"])
            return (res.result, nil)
        }
        if hasAnyWord(["кувырок", "сальто", "трюк"]) {
            let res = await ToolRegistry.shared.executeTool(name: "cat_action", parameters: ["action": "somersault"])
            return (res.result, nil)
        }
        if hasAnyWord(["повисни", "повиснуть"]) || (hasWord("лапки") && hasWord("остров")) {
            let res = await ToolRegistry.shared.executeTool(name: "cat_action", parameters: ["action": "hang_on_island"])
            return (res.result, nil)
        }
        if hasAnyWord(["поиграй", "клубок", "лазер"]) {
            let res = await ToolRegistry.shared.executeTool(name: "cat_action", parameters: ["action": "play"])
            return (res.result, nil)
        }
        if hasAnyWord(["покорми", "рыбка", "рыбку", "тунец"]) || (hasWord("еда") && !hasWord("беседа") && !hasWord("победа")) {
            let res = await MainActor.run { TamagotchiManager.shared.feedFish() }
            return (res, nil)
        }
        if hasAnyWord(["погладь", "почеши", "мурчи", "мурлыкни"]) {
            let res = await MainActor.run { TamagotchiManager.shared.petCat() }
            return (res, nil)
        }
        if hasAnyWord(["спать", "усни", "дремать", "отдыхай"]) {
            let res = await MainActor.run { TamagotchiManager.shared.sleep() }
            return (res, nil)
        }
        if hasAnyWord(["проснись", "подъем", "вставай"]) {
            let res = await MainActor.run { TamagotchiManager.shared.wake() }
            return (res, nil)
        }
        
        // 3. СИСТЕМНЫЕ ДЕЙСТВИЯ: ФОНАРИК, ТАЙМЕР
        if lower.contains("фонарик") || lower.contains("свет") {
            if lower.contains("выключ") || lower.contains("погаси") {
                let res = await ToolRegistry.shared.executeTool(name: "device_action", parameters: ["command": "flashlight_off"])
                return (res.result, nil)
            } else {
                let res = await ToolRegistry.shared.executeTool(name: "device_action", parameters: ["command": "flashlight_on"])
                return (res.result, nil)
            }
        }
        
        // 4. ТРЕНИРОВКИ: ОТЖИМАНИЯ, ПРИСЕДАНИЯ, ЙОГА
        if hasAnyWord(["отжимания", "отжимайся", "отжиматься"]) {
            let res = await ToolRegistry.shared.executeTool(name: "start_workout", parameters: ["workoutType": "pushups"])
            return (res.result, nil)
        }
        if hasAnyWord(["приседания", "приседай", "приседать"]) {
            let res = await ToolRegistry.shared.executeTool(name: "start_workout", parameters: ["workoutType": "squats"])
            return (res.result, nil)
        }
        if hasAnyWord(["йога", "йогу", "разминка", "растяжка"]) {
            let res = await ToolRegistry.shared.executeTool(name: "start_workout", parameters: ["workoutType": "yoga"])
            return (res.result, nil)
        }
        
        // 5. МУЗЫКА И СИНТЕЗАТОР
        if (hasWord("бит") || hasWord("музыка") || hasWord("сыграй") || hasWord("трек") || hasWord("мелодия")) {
            let style = lower.contains("кибер") ? "cyberpunk" : (lower.contains("8-bit") || lower.contains("ретро") ? "8-bit" : "lo-fi")
            let res = await ToolRegistry.shared.executeTool(name: "play_music", parameters: ["style": style])
            return (res.result, nil)
        }
        
        // 6. ГЕНЕРАЦИЯ ИЗОБРАЖЕНИЙ
        if (hasWord("арт") || hasWord("нарисуй") || hasWord("сгенерируй") || hasWord("рисунок") || hasWord("иллюстрация") || hasWord("картинка")) {
            let res = await ToolRegistry.shared.executeTool(name: "generate_image", parameters: ["prompt": userPrompt])
            return (res.result, res.image)
        }
        
        // 7. НАПОМИНАНИЯ И КАЛЕНДАРЬ (EventKit)
        if lower.contains("напомни") || lower.contains("создай напоминание") {
            let taskText = userPrompt.replacingOccurrences(of: "напомни", with: "", options: .caseInsensitive)
                                     .replacingOccurrences(of: "создай напоминание", with: "", options: .caseInsensitive)
                                     .trimmingCharacters(in: .whitespaces)
            let res = await ToolRegistry.shared.executeTool(name: "create_reminder", parameters: ["title": taskText.isEmpty ? "Важное дело" : taskText])
            return (res.result, nil)
        }
        
        if lower.contains("напоминания") || lower.contains("какие задачи") {
            let res = await ToolRegistry.shared.executeTool(name: "get_reminders", parameters: ["date": "today"])
            return (res.result, nil)
        }
        
        if lower.contains("календарь") || lower.contains("какие планы") || lower.contains("планы на сегодня") || lower.contains("встречи") {
            let res = await ToolRegistry.shared.executeTool(name: "get_calendar_events", parameters: ["date": "today"])
            return (res.result, nil)
        }
        
        // 8. ЗАПУСК ПРИЛОЖЕНИЙ
        if lower.contains("открой") || lower.contains("запусти") {
            for app in ["telegram", "телеграм", "youtube", "ютуб", "whatsapp", "ватсап", "камера", "настройки", "музыка", "карты", "калькулятор", "заметки"] {
                if lower.contains(app) {
                    let res = await ToolRegistry.shared.executeTool(name: "open_app", parameters: ["appName": app])
                    return (res.result, nil)
                }
            }
        }
        
        // 9. ЗАМЕТКИ И БАЗА ЗНАНИЙ (RAG BM25)
        if lower.contains("заметка") || lower.contains("запиши заметку") {
            let noteContent = userPrompt.replacingOccurrences(of: "запиши заметку", with: "", options: .caseInsensitive)
                                        .replacingOccurrences(of: "заметка", with: "", options: .caseInsensitive)
                                        .trimmingCharacters(in: .whitespaces)
            let res = await ToolRegistry.shared.executeTool(name: "create_note", parameters: ["title": "Заметка от AiCat", "content": noteContent])
            return (res.result, nil)
        }
        
        if !ragContext.isEmpty {
            return ("Раскопал в твоих документах:\n\n\(ragContext)\n\nС кошачьей точки зрения всё сходится, кожаный!", nil)
        }
        
        if lower.contains("найди в документах") || lower.contains("поищи в файлах") {
            let q = userPrompt.replacingOccurrences(of: "найди в документах", with: "", options: .caseInsensitive)
                              .trimmingCharacters(in: .whitespaces)
            let res = await ToolRegistry.shared.executeTool(name: "search_knowledge_base", parameters: ["query": q])
            return (res.result, nil)
        }
        
        // 10. ПЕРСОНА И ОБЩЕНИЕ
        if hasAnyWord(["кто"]) && (hasWord("ты") || hasWord("такой")) {
            return ("Я — твой AiCat! Самый стильный кот в темных очках, живущий прямо на твоем iPhone. Умею напоминать о делах, проверять календарь, светить фонариком, считать отжимания и приседания, генерировать арты, играть музыку и, конечно, душевно мурчать!", nil)
        }
        
        if hasAnyWord(["анекдот", "шутка", "посмеши", "прикол"]) {
            let jokes = [
                "Программист гладит кота. Кот мурчит. Программист думает: 'Надо же, девайс беспроводной, питается рыбой, вибрирует и работает без единого бага!'",
                "Знаешь, в чем главное преимущество кошачьего ИИ над облачным? Если отключится интернет, облачные нейросети умрут, а я просто потребую открыть банку с тунцом!",
                "— Кот, почему ты уронил кружку со стола?\n— Это был научный эксперимент по проверке работы силы притяжения! Физика, кожаный, чистая физика.",
                "Ученые доказали: кот состоит на 70% из грации, на 20% из наглости и на 10% из желания поспать в свежевыстиранных вещах."
            ]
            return (jokes.randomElement()!, nil)
        }
        
        // 11. СТАТУС КОТА
        if lower.contains("статус") || lower.contains("инфо") || lower.contains("сертификат") {
            let res = await ToolRegistry.shared.executeTool(name: "get_status", parameters: [:])
            return (res.result, nil)
        }
        
        // 12. ЖИВЫЕ ОСТРОУМНЫЕ РАЗГОВОРНЫЕ ОТВЕТЫ
        let thoughts = [
            "*Шевельнул ухом и с интересом посмотрел на тебя*. Насчет «\(userPrompt)» — мысль любопытная! Кошачья мудрость говорит: если сомневаешься, сделай паузу, выпей кофе, а потом действуй уверенно.",
            "Слушаю тебя внимательно! По поводу «\(userPrompt)» скажу так: звучит как отличный план. Давай сделаем это играючи, а потом отметим победу чем-нибудь вкусным!",
            "*Поправил черные очки лапой*. Хм, «\(userPrompt)»? А ты умеешь озадачить! Я на твоей стороне, так что давай разберемся с этим прямо сейчас."
        ]
        return (thoughts.randomElement()!, nil)
    }
    
    // Робастный парсер вызова инструмента из ответа модели
    public func parseToolCall(from text: String) -> ToolCallPayload? {
        guard let regex = try? NSRegularExpression(pattern: "\\{[\\s\\S]*?\"tool\"[\\s\\S]*?\\}", options: []) else {
            return nil
        }
        let ns = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        
        for m in matches {
            let jsonString = ns.substring(with: m.range)
            if let data = jsonString.data(using: .utf8),
               let payload = try? JSONDecoder().decode(ToolCallPayload.self, from: data) {
                return payload
            }
        }
        return nil
    }
}
