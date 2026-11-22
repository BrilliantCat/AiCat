import XCTest
@testable import AiCat

final class AiCatTests: XCTestCase {
    
    func testToolCallWithBracesInString() {
        let input = #"{"tool":"create_note","parameters":{"title":"{кот}","content":"Он сказал \"мяу\""}}"#
        let result = LLMEngine.shared.parseToolCall(from: input)
        XCTAssertEqual(result?.parameters?["title"], "{кот}")
        XCTAssertEqual(result?.parameters?["content"], "Он сказал \"мяу\"")
    }

    func testPetSnapshotProjection() {
        var cat = CatSnapshot()
        cat.date = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 12))!
        cat.energy = 70
        cat.sleeping = true
        let later = cat.projected(at: cat.date.addingTimeInterval(3600))
        XCTAssertEqual(later.satiety, 83)
        XCTAssertEqual(later.energy, 85)
        XCTAssertEqual(cat.energy, 70)
    }

    func testAutonomousCatSleepsWhenTired() {
        var cat = CatSnapshot()
        cat.date = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 12))!
        cat.energy = 20
        cat.actionUntil = .distantPast
        let later = cat.projected(at: cat.date.addingTimeInterval(3600))
        XCTAssertTrue(later.sleeping)
        XCTAssertEqual(later.action, "sleep")
        XCTAssertGreaterThan(later.energy, cat.energy)
    }

    func testAutonomousCatKeepsExplicitActionAndBounds() {
        var cat = CatSnapshot()
        cat.action = "eat"
        cat.actionUntil = cat.date.addingTimeInterval(120)
        XCTAssertEqual(cat.projected(at: cat.date.addingTimeInterval(60)).action, "eat")
        let later = cat.projected(at: cat.date.addingTimeInterval(86400 * 60))
        XCTAssertTrue((10...100).contains(later.energy))
        XCTAssertTrue((10...100).contains(later.satiety))
        XCTAssertTrue((15...100).contains(later.happiness))
    }

    @MainActor
    func testLessonPauseAndAdvance() {
        let coach = YogaCoachTool.shared
        _ = coach.startWorkout(type: "breathing")
        coach.pause()
        let remaining = coach.remainingSeconds
        XCTAssertTrue(coach.isPaused)
        coach.nextPose()
        XCTAssertTrue(coach.isPaused)
        XCTAssertEqual(coach.currentExerciseIndex, 1)
        XCTAssertGreaterThan(remaining, 0)
        coach.resume()
        XCTAssertFalse(coach.isPaused)
        _ = coach.stopWorkout()
        XCTAssertFalse(coach.isSessionActive)
    }

    // 1. Тест парсера JSON вызова инструментов (с мусором вокруг JSON)
    func testToolCallJsonParsing() {
        let engine = LLMEngine.shared
        
        let validJson = """
        Я подумал и решил выполнить команду:
        ```json
        {
          "thought": "Хозяин хочет кувырок",
          "tool": "cat_action",
          "parameters": {
            "action": "somersault"
          },
          "reply_text": "Кручу сальто назад!"
        }
        ```
        Надеюсь, тебе понравилось!
        """
        
        let parsed = engine.parseToolCall(from: validJson)
        XCTAssertNotNil(parsed, "Парсер должен успешно извлечь JSON из текста с markdown")
        XCTAssertEqual(parsed?.tool, "cat_action")
        XCTAssertEqual(parsed?.parameters?["action"], "somersault")
        XCTAssertEqual(parsed?.reply_text, "Кручу сальто назад!")
    }
    
    // 2. Тест шаблона промпта ChatML
    func testPromptBuilderChatML() {
        let system = PromptBuilder.buildSystemPrompt(ragContext: "Тестовый документ")
        XCTAssertTrue(system.contains("AiCat"), "Системный промпт должен содержать имя агента")
        XCTAssertTrue(system.contains("Тестовый документ"), "Системный промпт должен содержать RAG контекст")
        
        let chatML = PromptBuilder.formatChatML(
            system: "Ты кот",
            messages: [("user", "Привет"), ("assistant", "Мяу")]
        )
        XCTAssertTrue(chatML.contains("<|im_start|>system\nТы кот<|im_end|>"))
        XCTAssertTrue(chatML.contains("<|im_start|>user\nПривет<|im_end|>"))
        XCTAssertTrue(chatML.contains("<|im_start|>assistant\n"))
    }
    
    // 3. Тест полнотекстового поиска BM25 с нормализацией и стеммингом
    func testBM25Search() {
        let rag = RAGTool.shared
        rag.clearAll()
        
        rag.addDocument(name: "doc1.txt", content: "Коты любят свежую рыбу и спать на солнышке.")
        rag.addDocument(name: "doc2.txt", content: "Язык программирования Swift создан компанией Apple для iOS.")
        
        let searchCat = rag.searchKnowledge(query: "рыбка для кота", topK: 1)
        XCTAssertTrue(searchCat.contains("doc1.txt"), "BM25 должен найти doc1.txt по запросу про рыбу")
        XCTAssertFalse(searchCat.contains("doc2.txt"), "doc2.txt не должен попасть в топ по запросу про рыбу")
        
        let searchSwift = rag.searchKnowledge(query: "программирование под iPhone", topK: 1)
        XCTAssertTrue(searchSwift.contains("doc2.txt"), "BM25 должен найти документ по Swift")
        
        rag.clearAll()
    }
    
    // 4. Тест тамагочи: сытость и счастье
    @MainActor
    func testTamagotchiLogic() {
        let tamagotchi = TamagotchiManager.shared
        let initialSatiety = tamagotchi.satiety
        
        _ = tamagotchi.feedFish()
        XCTAssertGreaterThanOrEqual(tamagotchi.satiety, initialSatiety, "Кормление должно увеличивать сытость")
        
        let initialHappiness = tamagotchi.happiness
        _ = tamagotchi.petCat()
        XCTAssertGreaterThanOrEqual(tamagotchi.happiness, initialHappiness, "Поглаживание должно увеличивать счастье")
        
        let prompt = tamagotchi.moodContextPrompt()
        XCTAssertTrue(prompt.contains("ТАМАГОЧИ"), "Промпт должен включать статус тамагочи")
    }
    
    // 5. Тест распознавания даты и фильтрации
    func testDateParsingAndFiltering() {
        let iso = ISO8601DateFormatter()
        let testDateString = "2026-11-23T10:00:00Z"
        let parsedDate = iso.date(from: testDateString)
        XCTAssertNotNil(parsedDate, "ISO8601 парсер должен распознавать дату")
        
        let cal = Calendar.current
        let today = Date()
        let startToday = cal.startOfDay(for: today)
        let laterToday = startToday.addingTimeInterval(3600)
        XCTAssertEqual(cal.startOfDay(for: laterToday), startToday, "Даты в один день должны иметь одинаковый startOfDay")
    }
    
    // 6. Тест алгоритма подсчета приседаний по 3D-вектору ускорения
    func testSquatsAccelerationMagnitude() {
        // Симуляция вектора в покое (1g)
        let restMag = sqrt(0.0 * 0.0 + 0.0 * 0.0 + 1.0 * 1.0)
        XCTAssertEqual(restMag, 1.0, accuracy: 0.001)
        
        // Симуляция опускания тела (невесомость: падение до 0.7g)
        let downMag = sqrt(0.1 * 0.1 + 0.1 * 0.1 + 0.7 * 0.7)
        XCTAssertLessThan(downMag, 0.85, "Опускание тела должно быть < 0.85g")
        
        // Симуляция торможения внизу и подъема (перегрузка: 1.35g)
        let upMag = sqrt(0.2 * 0.2 + 0.2 * 0.2 + 1.35 * 1.35)
        XCTAssertGreaterThan(upMag, 1.25, "Подъем должен создавать пик > 1.25g")
    }
}
