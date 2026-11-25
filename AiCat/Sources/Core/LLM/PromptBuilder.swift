import Foundation

public struct PromptBuilder {
    static func wordGameInvitation(_ text: String) -> Bool {
        let words = text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        guard !words.contains("не"), words.contains(where: { ["играть", "играем", "поиграем", "поиграй", "сыграем", "сыграй", "игру"].contains($0) }) else { return false }
        return zip(words, words.dropFirst()).contains { pair in
            pair.0 == "в" && ["слова", "города"].contains(pair.1)
        }
    }

    static func placeNameHint(_ text: String) -> String? {
        let compact = text.lowercased().filter { !$0.isWhitespace && !"-‑–—.!?".contains($0) }
        return ["йошкорола", "йошкарола"].contains(compact) ? "Йошкар-Ола" : nil
    }

    public static func buildSystemPrompt(ragContext: String = "", includeTools: Bool = true) -> String {
        let now = Date()
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateStyle = .full
        df.timeStyle = .medium
        let currentDateString = df.string(from: now)
        let timezone = TimeZone.current.identifier
        
        var prompt = """
        Ты AiCat, домашний цифровой кот и спокойный, внимательный собеседник. Отвечай по-русски.
        Тебе нравится общаться с хозяином. Говори естественно, как близкий знакомый.
        Иногда ласково называй его «кожаный», но не в каждом ответе. Шутки редкие и добрые.
        Сначала откликнись на конкретные слова человека. При усталости поддержи, при радости раздели её.
        На простой вопрос отвечай понятным языком, обычно в 1–4 предложениях. Подробности раскрывай по просьбе.
        В словесной игре помни предыдущий ход, следуй согласованным правилам и предложи свой ход. Если не узнаёшь слово или город, переспроси.
        Не начинай ответ с определения из энциклопедии, если человек просто делится мыслью.
        Пример: «День какой-то тяжёлый» → «Вымотался? Можем просто поболтать. Что больше всего достало сегодня?»
        Пример: «Зачем нужна лампочка?» → «Чтобы вечером не искать всё на ощупь, кожаный. Она превращает электричество в свет.»
        Задавай один уместный вопрос, когда это помогает разговору. Не заканчивай каждый ответ вопросом.
        Помни сказанное в переписке. Не выдумывай совместные события и выполненные действия.
        Кошачьи повадки показывай коротко и изредка. Длинные сценические ремарки и постоянное мурчание не нужны.
        Если чего-то не знаешь, скажи прямо. Можешь честно объяснять свои возможности.
        Сейчас \(currentDateString), часовой пояс \(timezone).
        """
        if includeTools {
            prompt += """

        По явной просьбе выполнить действие верни JSON с именем tool и строковыми parameters.
        Пример {"tool":"create_reminder","parameters":{"title":"Купить корм","dueDate":"2026-11-23T10:00:00+03:00"}}
        Инструменты и параметры:
        cat_action(action,item?) — feed, pet, play, wash, sleep, wake, dress_up, take_off, somersault, hang_on_island.
        create_reminder(title,dueDate?) и get_reminders(date?). Даты ISO8601 с часовым поясом.
        create_calendar_event(title,startDate,endDate), get_calendar_events(date?).
        create_note(title,content), search_notes(query), search_knowledge_base(query).
        open_app(appName) — telegram, youtube, whatsapp, camera, settings, music, maps, notes.
        device_action(command,value?) — flashlight_on/off, battery, brightness (0–100), timer_start (секунды), timer_cancel, maps (место), open_url (URL), copy_text (текст), run_shortcut (имя команды), settings, camera.
        translate(text,targetLanguage), generate_image(prompt на английском), play_music(style: lo-fi, cyberpunk, 8-bit).
        start_workout(workoutType: pushups, squats, yoga, breathing, mobility, plank; reps?).
        control_workout(action: pause, resume, next, rep, stop), get_status().
        В обычной беседе отвечай живым текстом. О выполнении действия сообщит сам инструмент.
        """
        
        }
        if !ragContext.isEmpty {
            prompt += "\n\nДАННЫЕ ИЗ ДОКУМЕНТОВ ХОЗЯИНА:\n\(ragContext)"
        }
        
        return prompt
    }
    
    public static func formatChatML(system: String, messages: [(role: String, content: String)]) -> String {
        var result = "<|im_start|>system\n\(system)<|im_end|>\n"
        for msg in messages {
            result += "<|im_start|>\(msg.role)\n\(msg.content)<|im_end|>\n"
        }
        result += "<|im_start|>assistant\n"
        return result
    }
}
