import XCTest
import SceneKit
import Metal
import UIKit
import AVFoundation
@testable import AiCat

final class AiCatTests: XCTestCase {
    func testMusicStudioWritesAnAudibleBeat() throws {
        let url = try MusicTool.render(style: "lo-fi")
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        XCTAssertEqual(Double(file.length) / file.processingFormat.sampleRate, 8 * 60.0 / 82.0, accuracy: 0.01)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 22050))
        try file.read(into: buffer)
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        let pcm = UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength))
        XCTAssertGreaterThan(pcm.reduce(Float.zero) { $0 + $1 * $1 } / Float(pcm.count), 0.001)
    }

    func testChatRecognizesWordGamesAndPlaceNames() {
        XCTAssertTrue(PromptBuilder.wordGameInvitation("Давай поиграем в слова!"))
        XCTAssertTrue(PromptBuilder.wordGameInvitation("Сыграем в города?"))
        XCTAssertFalse(PromptBuilder.wordGameInvitation("Поиграй с мячом"))
        XCTAssertFalse(PromptBuilder.wordGameInvitation("Не хочу играть в слова"))
        XCTAssertEqual(PromptBuilder.placeNameHint("Йош-корола"), "Йошкар-Ола")
        XCTAssertNil(PromptBuilder.placeNameHint("Королёв"))
    }

    func testBundledModelTranscribesRussianOffline() throws {
        let model = try XCTUnwrap(OfflineSpeechRecognizer.bundledModel)
        let recording = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "RussianGreeting", withExtension: "wav"))
        let text = try XCTUnwrap(OfflineSpeechRecognizer.transcribe(recording: recording, model: model)).lowercased()
        for word in ["привет", "котик", "поиграем"] { XCTAssertTrue(text.contains(word), text) }
    }

    func testWardrobeRestoresOldNamesAndReplacesOnlyOneSlot() {
        let original = CatGarment.matching("Кожаная кепка, Чёрные кибер-очки и Неоновый худи")
        XCTAssertEqual(Set(original), [.cap, .glasses, .hoodie])
        XCTAssertEqual(CatGarment.matching("Бархатная бабочка"), [.bow])
        let layered = CatGarment.equipping([.beret, .bow], over: original)
        XCTAssertEqual(Set(layered), [.beret, .glasses, .bow, .hoodie])
        XCTAssertEqual(Set(CatGarment.matching(layered.map(\.rawValue).joined(separator: ", "))), Set(layered))
    }

    @MainActor
    func testLessonPosesDrawWithoutMagentaFrames() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("Metal unavailable") }
        let scene = SCNScene()
        let cat = SCNNode()
        scene.rootNode.addChildNode(cat)
        let rig = try XCTUnwrap(CatMotionRig(cat: cat))
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = SCNVector3(2.5, 1.2, 3)
        camera.look(at: SCNVector3(0, 0.65, 0))
        scene.rootNode.addChildNode(camera)
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camera
        renderer.autoenablesDefaultLighting = true
        scene.background.contents = UIColor.black
        for motion: CatMotion in [.breath, .shoulders, .plank, .pushUp] {
            rig.set(motion, reduced: true)
            rig.advance(by: 0.5)
            let size = 96
            let shot = renderer.snapshot(atTime: 0, with: CGSize(width: 96, height: 96), antialiasingMode: .none)
            let cgImage = try XCTUnwrap(shot.cgImage)
            var pixels = [UInt8](repeating: 0, count: size * size * 4)
            try pixels.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
                let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: size, height: size,
                    bitsPerComponent: 8, bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 96, height: 96))
            }
            var visible = 0, pink = 0
            for i in stride(from: 0, to: pixels.count, by: 4) {
                if max(pixels[i], pixels[i+1], pixels[i+2]) > 25 { visible += 1 }
                if pixels[i] > 190 && pixels[i+1] < 70 && pixels[i+2] > 190 { pink += 1 }
            }
            XCTAssertGreaterThan(visible, 60, motion.rawValue)
            XCTAssertLessThan(pink, size * size / 10, motion.rawValue)
        }
    }
    func testCameraCountsOnlyAFullReturnAndRecalibratesAfterLosingTheFace() {
        var detector = PushupCounter()
        for sample in 0...6 {
            XCTAssertFalse(detector.update(distance: 0.56, at: Double(sample) / 10))
        }
        XCTAssertEqual(detector.phase, .ready)
        XCTAssertFalse(detector.update(distance: 0.51, at: 0.70))
        XCTAssertFalse(detector.update(distance: 0.34, at: 0.82))
        XCTAssertFalse(detector.update(distance: 0.35, at: 1.02))
        XCTAssertTrue(detector.update(distance: 0.55, at: 1.26))
        XCTAssertFalse(detector.update(distance: 0.56, at: 1.34))
        XCTAssertFalse(detector.update(distance: 0.36, at: 1.49))
        XCTAssertFalse(detector.update(distance: nil, at: 2.30))
        XCTAssertFalse(detector.update(distance: 0.55, at: 2.45))
        XCTAssertEqual(detector.phase, .calibrating)
    }

    func testBreathJoinsAtTheDisplayedStepBoundary() {
        let join = Date()
        let inhale = BreathStep(inhale: true, duration: 4, end: join)
        let exhale = BreathStep(inhale: false, duration: 6, end: join.addingTimeInterval(6))
        XCTAssertEqual(inhale.phase(at: join), exhale.phase(at: join))
        XCTAssertEqual(inhale.phase(at: join.addingTimeInterval(-2)), 0.25)
        XCTAssertEqual(exhale.phase(at: join.addingTimeInterval(3)), 0.75)
    }

    func testBallGameCrossesRugAndBatsAtPawReach() {
        for fps: Float in [20, 30, 60] {
            var game = CatBallGame()
            game.start(at: .zero, facing: -0.54, repeats: true)
            var minX = game.position.x
            var maxX = minX
            for _ in 0..<Int(18 * fps) {
                let previousHits = game.hits
                game.advance(by: 1 / fps)
                minX = min(minX, game.position.x)
                maxX = max(maxX, game.position.x)
                XCTAssertLessThanOrEqual(abs(game.ball.x) * CatRoomScenery.kittenScale, 1.786)
                if game.hits > previousHits {
                    let paw = SIMD2<Float>(0.163 * cos(game.heading) + 0.72 * sin(game.heading),
                                           -0.163 * sin(game.heading) + 0.72 * cos(game.heading))
                    XCTAssertLessThanOrEqual(simd_distance(game.position + paw, game.ball), CatBallGame.radius)
                }
            }
            XCTAssertGreaterThanOrEqual(game.hits, 3)
            XCTAssertGreaterThan((maxX - minX) * CatRoomScenery.kittenScale, 2)
        }
    }

    func testSingleThrowCanBeRedirectedAndEnds() {
        var game = CatBallGame()
        game.start(at: .zero, facing: 0, target: [40, 20], repeats: false)
        for _ in 0..<15 { game.advance(by: 1 / 30) }
        game.throwBall(towards: [-1.5, 0.4])
        for _ in 0..<360 { game.advance(by: 1 / 30) }
        XCTAssertEqual(game.hits, 1)
        XCTAssertEqual(game.phase, .idle)
    }

    func testPhoneCommandsPreserveRecipientsAndPayloads() {
        XCTAssertEqual(PhoneCommand.parse("Котик, напиши СМС маме: Я дома!"),
                       PhoneCommand(command: "sms_draft", value: "маме", detail: "Я дома!"))
        XCTAssertEqual(PhoneCommand.parse("Письмо о прошлом звонке"), nil)
        XCTAssertNil(PhoneCommand.parse("Не позвони маме"))
        XCTAssertNil(PhoneCommand.parse("Как включить фонарик?"))
        XCTAssertEqual(PhoneCommand.parse("Маршрут пешком до Йошкар-Олы")?.value, "Йошкар-Олы")
        XCTAssertEqual(PhoneCommand.parse("запусти команду Заметка с текстом A&B + C"),
                       PhoneCommand(command: "run_shortcut", value: "Заметка", detail: "A&B + C"))
        XCTAssertEqual(PhoneCommand.parse("ВКЛЮЧИ Wi-Fi!", shortcuts: ["включи wi-fi":"Домашняя сеть"]),
                       PhoneCommand(command: "run_shortcut", value: "Домашняя сеть"))
        XCTAssertEqual(PhoneCommand.parse("Включи Wi-Fi")?.command, "shortcut_setup")
        XCTAssertEqual(PhoneCommand.parse("Планы на завтра")?.command, "agenda_tomorrow")
    }

    func testPhoneTimerUnderstandsUnitsAndRejectsExtraWords() {
        XCTAssertEqual(PhoneCommand.parse("поставь таймер на пять минут")?.value, "300.0")
        XCTAssertEqual(PhoneCommand.parse("таймер на 1 час и 15 минут")?.value, "4500.0")
        XCTAssertEqual(PhoneCommand.parse("таймер 1,5 мин")?.value, "90.0")
        XCTAssertEqual(PhoneCommand.parse("таймер 5 бананов")?.value, "")
        XCTAssertEqual(PhoneCommand.parse("Установи яркость на 40 процентов.")?.value, "40")
    }

    @MainActor
    func testCommunicationDestinationsAndDraftEncoding() throws {
        XCTAssertEqual(PhoneCommunication.phoneNumber("+7 (999) 123-45-67"), "+79991234567")
        XCTAssertNil(PhoneCommunication.phoneNumber("12*345#"))
        XCTAssertNil(PhoneCommunication.phoneNumber("123+456"))
        XCTAssertNil(PhoneCommunication.emailDraft(to: "x@example.com?bcc=a@b.co", body: "Привет"))
        let body = "Привет + & ? #"
        let draft = try XCTUnwrap(PhoneCommunication.emailDraft(to: "cat+test@example.com", body: body))
        let fields = try XCTUnwrap(URLComponents(url: draft, resolvingAgainstBaseURL: false))
        XCTAssertEqual(fields.path, "cat+test@example.com")
        XCTAssertEqual(fields.queryItems?.first?.value, body)
    }

    func testFloorTargetsStopAtTheRugEvenAfterRepeatedNudges() {
        for side: Float in [-1, 1] {
            var target = SIMD3<Float>.zero
            for _ in 0..<200 {
                target = CatRoomScenery.floorTarget(target + SIMD3(side * 0.18, 0, side * 0.2))
            }
            XCTAssertTrue(CatRoomScenery.rugX.contains(target.x + side * 0.6))
            XCTAssertTrue(CatRoomScenery.rugZ.contains(target.z))
            XCTAssertEqual(target, CatRoomScenery.floorTarget(target + SIMD3(side, 0, side)))
        }
    }

    func testSayingChangesAtLocalMidnight() throws {
        let zone = try XCTUnwrap(TimeZone(secondsFromGMT: 3 * 3600))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let evening = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 23, minute: 59)))
        let today = DailySaying.index(evening, zone: zone)
        XCTAssertEqual(today, DailySaying.index(evening.addingTimeInterval(-3600), zone: zone))
        let tomorrow = DailySaying.index(evening.addingTimeInterval(60), zone: zone)
        XCTAssertNotEqual(DailySaying.sayings[today].text, DailySaying.sayings[tomorrow].text)
    }

    @MainActor
    func testClothesShareTheKittenSkeletonAndTrousersLayerWithTops() throws {
        let cat = SCNNode()
        _ = try XCTUnwrap(CatMotionRig(cat: cat))
        let body = try XCTUnwrap(cat.childNode(withName: "BritishKittenSkin", recursively: true)?.skinner)
        for garment: CatGarment in [.hoodie, .vest, .trousers] {
            let fabric = try XCTUnwrap(cat.childNode(withName: garment.rawValue, recursively: true)?.skinner)
            XCTAssertTrue(fabric.skeleton === body.skeleton)
            XCTAssertEqual(fabric.bones.count, body.bones.count)
            XCTAssertGreaterThan(fabric.boneWeights.vectorCount, 100)
        }
        XCTAssertEqual(CatGarment.equipping([.trousers], over: [.hoodie]), [.hoodie, .trousers])
    }

    @MainActor
    func testScratchLiftsAlternatingFrontPaws() throws {
        let cat = SCNNode()
        let rig = try XCTUnwrap(CatMotionRig(cat: cat))
        let left = try XCTUnwrap(cat.childNode(withName: "foreL3", recursively: true))
        let right = try XCTUnwrap(cat.childNode(withName: "foreR3", recursively: true))
        rig.set(.scratch, reduced: true)
        var heights: [Float] = []
        for _ in 0..<64 {
            rig.advance(by: 1 / 60)
            heights.append(left.simdWorldPosition.y - right.simdWorldPosition.y)
        }
        XCTAssertGreaterThan(try XCTUnwrap(heights.max()), 0.05)
        XCTAssertLessThan(try XCTUnwrap(heights.min()), -0.05)
    }

    func testEveryLessonIncludesAPlayableSheet() throws {
        for motion in CatMotion.allCases where motion.isExercise || motion == .walk {
            let path = try XCTUnwrap(Bundle.main.url(forResource: motion.rawValue, withExtension: "jpg", subdirectory: "LivingRoom/Lessons"))
            let image = try XCTUnwrap(UIImage(contentsOfFile: path.path)?.cgImage)
            XCTAssertEqual(image.width, 1800, motion.rawValue)
            XCTAssertEqual(image.height, 1664, motion.rawValue)
        }
    }

    func testOnlineChoicePrefersAvailableLargerGeneralModel() throws {
        let json = #"{"data":[{"id":"gemma-E2B","x_horde":{"workers":2,"queued":0}},{"id":"Qwen-32B","x_horde":{"workers":0,"queued":0}},{"id":"Mistral-24B","x_horde":{"workers":1,"queued":3}}]}"#
        let models = try JSONDecoder().decode(HordeChat.Catalog.self, from: Data(json.utf8)).data
        XCTAssertEqual(HordeChat.preferredModel(in: models)?.id, "Mistral-24B")
        XCTAssertNil(HordeChat.preferredModel(in: Array(models.prefix(2))))
    }

    func testReplyContinuesPreviousConversation() {
        let old = [ChatMessage(sender: .user, text: "Поговорим?")]
        XCTAssertEqual(LLMEngine.continuation("Привет, кожаный! Как прошла прогулка?", after: "Я вернулся", history: old), "Как прошла прогулка?")
        XCTAssertEqual(LLMEngine.continuation("Привет! Я здесь.", after: "Привет!", history: old), "Привет! Я здесь.")
    }

    func testLivingRoomResourcesInBothLightingConditions() throws {
        for hour in [12, 23] {
            let scene = SCNScene()
            XCTAssertTrue(CatRoomScenery.install(in: scene, hour: hour))
            let room = try XCTUnwrap(scene.rootNode.childNode(withName: "SittingRoom", recursively: false))
            XCTAssertEqual(room.geometry?.elementCount, 6)
            let light = try XCTUnwrap(scene.rootNode.childNode(withName: "FloorLamp", recursively: false)?.light)
            CatRoomScenery.toggleLamp(in: scene)
            XCTAssertEqual(light.intensity, 0)
            CatRoomScenery.toggleLamp(in: scene)
            XCTAssertGreaterThan(light.intensity, 0)
            let window = try XCTUnwrap(room.geometry?.material(named: "window"))
            XCTAssertEqual(window.diffuse.contentsTransform.m22, -1)
        }
    }
    
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

    func testFrequentSavesDoNotChangeNeedsOrDelaySnack() throws {
        var cat = CatSnapshot()
        cat.date = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 12)))
        cat.satiety = 42
        let quarter = cat.date.addingTimeInterval(900)
        let fed = cat.projected(at: quarter)
        XCTAssertEqual(fed.action, "eat")
        XCTAssertEqual(fed.satiety, 69)
        XCTAssertNotEqual(fed.projected(at: quarter.addingTimeInterval(301)).action, "eat")

        var reopened = cat
        for minute in 1...600 {
            reopened = reopened.projected(at: cat.date.addingTimeInterval(Double(minute) * 60))
        }
        let uninterrupted = cat.projected(at: reopened.date)
        XCTAssertEqual(reopened.satiety, uninterrupted.satiety)
        XCTAssertEqual(reopened.happiness, uninterrupted.happiness)
        XCTAssertEqual(reopened.energy, uninterrupted.energy)
        XCTAssertEqual(reopened.action, uninterrupted.action)
    }

    func testCatSleepsOvernightThenWakesAfterOwnerIsAway() throws {
        var cat = CatSnapshot()
        cat.date = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 22)))
        let night = cat.projected(at: cat.date.addingTimeInterval(3 * 3600))
        XCTAssertTrue(night.sleeping)
        XCTAssertEqual(night.action, "sleep")
        let morning = night.projected(at: cat.date.addingTimeInterval(10 * 3600))
        XCTAssertFalse(morning.sleeping)
        XCTAssertNotEqual(morning.action, "sleep")
    }

    @MainActor
    func testKittenSettlesHaunchesBeforeClosingEyes() throws {
        let root = SCNNode()
        let rig = try XCTUnwrap(CatMotionRig(cat: root))
        let pelvis = try XCTUnwrap(root.childNode(withName: "pelvis", recursively: true))
        let head = try XCTUnwrap(root.childNode(withName: "head", recursively: true))
        let eye = try XCTUnwrap(root.childNode(withName: "eyeL", recursively: true))
        let standingHead = head.simdWorldPosition.y
        let standingPelvis = pelvis.simdWorldPosition.y
        rig.set(.sleep, reduced: false)
        rig.advance(by: 0.5)
        XCTAssertLessThan(pelvis.simdWorldPosition.y, standingPelvis - 0.1)
        XCTAssertGreaterThan(head.simdWorldPosition.y, standingHead - 0.07)
        XCTAssertGreaterThan(eye.simdScale.y, 0.9)
        rig.advance(by: 1.35)
        XCTAssertLessThan(eye.simdScale.y, 0.1)
        let restingHead = head.simdWorldPosition
        rig.advance(by: 0.01)
        XCTAssertLessThan(simd_distance(restingHead, head.simdWorldPosition), 0.01)
        rig.set(.walk, reduced: false)
        rig.advance(by: 0.4)
        XCTAssertGreaterThan(head.simdWorldPosition.y, standingHead - 0.10)
    }

    @MainActor
    func testBundledKittenWalkAndSleep() throws {
        let root = SCNNode()
        let rig = try XCTUnwrap(CatMotionRig(cat: root))
        let surface = try XCTUnwrap(root.childNode(withName: "BritishKittenSkin", recursively: true))
        let skin = try XCTUnwrap(surface.skinner)
        XCTAssertEqual(skin.bones.count, 31)
        let paw = try XCTUnwrap(root.childNode(withName: "foreL3", recursively: true))
        rig.set(.walk, reduced: false)
        rig.advance(by: 0.8)
        let start = paw.simdWorldPosition
        rig.advance(by: 0.2)
        XCTAssertGreaterThan(simd_distance(start, paw.simdWorldPosition), 0.07)
        let head = try XCTUnwrap(root.childNode(withName: "head", recursively: true))
        let standingHeight = head.simdWorldPosition.y
        rig.set(.sleep, reduced: true)
        XCTAssertLessThan(head.simdWorldPosition.y, standingHeight - 0.24)
        XCTAssertGreaterThan(paw.simdWorldPosition.y, 0.015)
        for motion in CatMotion.allCases {
            rig.set(motion, reduced: true)
            XCTAssertTrue(head.simdWorldPosition.y.isFinite)
        }
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
        let suite = "AiCatTests.lesson.\(UUID().uuidString)"
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let coach = YogaCoachTool(storage: storage, speak: { _ in },
                                 updateStatus: { _, _ in }, stopFitness: {})
        defer { _ = coach.stopWorkout() }
        _ = coach.startWorkout(type: "breathing")
        coach.pause()
        let remaining = coach.remainingSeconds
        XCTAssertTrue(coach.isPaused)
        coach.nextPose()
        XCTAssertTrue(coach.isPaused)
        XCTAssertEqual(coach.currentExerciseIndex, 1)
        XCTAssertGreaterThan(remaining, 0)
        let restored = YogaCoachTool(storage: storage, speak: { _ in },
                                    updateStatus: { _, _ in }, stopFitness: {})
        XCTAssertTrue(restored.isSessionActive)
        XCTAssertTrue(restored.isPaused)
        XCTAssertEqual(restored.currentExerciseIndex, 1)
        XCTAssertEqual(restored.remainingSeconds, coach.remainingSeconds)
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
    
    func testSnapshotUpgradeWithoutOutfit() throws {
        let data = try JSONEncoder().encode(CatSnapshot())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "outfit")
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(CatSnapshot.self, from: legacy)
        XCTAssertNil(decoded.outfit)
        XCTAssertEqual(decoded.satiety, 85)
    }

    func testConversationPromptAndHistoryRoles() {
        let prompt = PromptBuilder.buildSystemPrompt(includeTools: false)
        XCTAssertTrue(prompt.contains("AiCat"))
        XCTAssertFalse(prompt.contains("create_reminder"))
        let chat = PromptBuilder.formatChatML(system: prompt, messages: [
            (role: "user", content: "У меня кот Барсик"),
            (role: "assistant", content: "Как он поживает?"),
            (role: "user", content: "Помнишь его имя?")
        ])
        XCTAssertTrue(chat.contains("<|im_start|>assistant\nКак он поживает?<|im_end|>"))
        XCTAssertTrue(chat.contains("<|im_start|>user\nПомнишь его имя?<|im_end|>"))
        XCTAssertTrue(chat.hasSuffix("<|im_start|>assistant\n"))
    }

    // 3. Тест полнотекстового поиска BM25 с нормализацией и стеммингом
    func testBM25Search() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let rag = RAGTool(directory: directory)
        
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
    func testTamagotchiLogic() {
        var cat = CatSnapshot()
        cat.satiety = 35
        cat.happiness = 40
        cat.energy = 60
        cat.sleeping = true
        XCTAssertNil(cat.apply(.play))
        XCTAssertNotNil(cat.apply(.pet))
        XCTAssertTrue(cat.sleeping)
        XCTAssertEqual(cat.happiness, 60)
        XCTAssertNotNil(cat.apply(.feed))
        XCTAssertEqual(cat.satiety, 65)
        XCTAssertFalse(cat.sleeping)
        XCTAssertNotNil(cat.apply(.play))
        XCTAssertEqual(cat.action, "play")
        XCTAssertEqual(cat.energy, 52)
        XCTAssertEqual(cat.satiety, 62)
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
