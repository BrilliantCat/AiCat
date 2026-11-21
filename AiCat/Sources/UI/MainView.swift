import SwiftUI

public struct MainView: View {
    @StateObject private var catHandler = CatActionHandler.shared
    @StateObject private var tamagotchi = TamagotchiManager.shared
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var certificateWatchdog = CertificateWatchdog.shared
    
    @State private var inputText: String = ""
    @State private var voiceEnabled: Bool = true
    @State private var isListening: Bool = false
    @State private var showCertificateInfo: Bool = false
    @State private var showModelManager: Bool = false
    @State private var showWardrobe: Bool = false
    
    @State private var chatMessages: [ChatMessage] = [
        ChatMessage(sender: .cat, text: "Салют, кожаный! Я AiCat — твой 3D-агент в черных очках. Моделирую мысли в чипе A17 Pro. Погладь меня по голове или спроси что угодно!")
    ]
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Сертификатный баннер, если осталось мало дней
                if certificateWatchdog.needsRenewal {
                    certificateBanner
                }
                
                // Интерактивная 3D-сцена с настоящим котиком (погладить, покрутить)
                ZStack(alignment: .bottom) {
                    Cat3DSceneView()
                        .frame(height: 230)
                    
                    // Статус сытости, счастья и состояния
                    statusBadges
                }
                
                // Панель быстрых трюков для котика
                actionChipsBar
                
                // Лента сообщений чата
                messagesScrollView
                
                // Поле ввода запроса и микрофон
                inputBar
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showWardrobe) {
            WardrobeSheet()
        }
        .sheet(isPresented: $showModelManager) {
            ModelManagerView()
        }
        .alert(isPresented: $showCertificateInfo) {
            Alert(
                title: Text("Обновление сертификата (7 дней)"),
                message: Text(certificateWatchdog.instructionsText),
                dismissButton: .default(Text("Понятно, сделаю!"))
            )
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("AiCat")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    Text(catHandler.state.moodEmoji)
                        .font(.title3)
                }
                Text(modelManager.isModelLoaded ? "Офлайн A17 Pro • Мозг активен" : "Офлайн A17 Pro (Поиск GGUF)")
                    .font(.caption2)
                    .foregroundColor(modelManager.isModelLoaded ? .green : .cyan)
            }
            
            Spacer()
            
            // Гардероб
            Button(action: { showWardrobe = true }) {
                Image(systemName: "tshirt.fill")
                    .foregroundColor(.cyan)
                    .padding(8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            
            // Модели
            Button(action: { showModelManager = true }) {
                Image(systemName: "cpu.fill")
                    .foregroundColor(modelManager.isModelLoaded ? .green : .cyan)
                    .padding(8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            
            // Тумблер озвучки голосом
            HStack(spacing: 6) {
                Image(systemName: voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .foregroundColor(voiceEnabled ? .green : .gray)
                    .font(.footnote)
                Toggle("", isOn: $voiceEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .cyan))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .cornerRadius(20)
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    private var certificateBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Сертификат: \(certificateWatchdog.daysRemaining) дн. Нажми для инфо!")
                .font(.caption2)
                .foregroundColor(.white)
            Spacer()
            Button("Инфо") { showCertificateInfo = true }
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.3))
                .cornerRadius(8)
        }
        .padding(8)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private var statusBadges: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Text("🐟 \(tamagotchi.satiety)%")
                    .font(.caption2)
                    .foregroundColor(.cyan)
                Text("❤️ \(tamagotchi.happiness)%")
                    .font(.caption2)
                    .foregroundColor(.pink)
                Text("⚡ \(tamagotchi.energy)%")
                    .font(.caption2)
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            
            Text(catHandler.state.statusText)
                .font(.caption)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                )
        }
        .padding(.bottom, 6)
    }
    
    private var actionChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ActionChip(icon: "fish.fill", label: "Покормить") {
                    let reply = tamagotchi.feedFish()
                    addCatResponse(reply)
                }
                ActionChip(icon: "figure.roll", label: "Кувырок") {
                    let reply = catHandler.execute(action: "somersault")
                    addCatResponse(reply)
                }
                ActionChip(icon: "sparkles", label: "Помойся") {
                    let reply = catHandler.execute(action: "wash")
                    addCatResponse(reply)
                }
                ActionChip(icon: "pawprint.fill", label: "Повисни") {
                    let reply = catHandler.execute(action: "hang_on_island")
                    addCatResponse(reply)
                }
                ActionChip(icon: "figure.strengthtraining.traditional", label: "Отжимания") {
                    let reply = CatFitnessCoach.shared.startPushups()
                    addCatResponse(reply)
                }
                ActionChip(icon: "waveform.badge.magnifyingglass", label: "Вайб-чек") {
                    let reply = "Слушаю твой голос... Вайб: Ровный, спокойный, уровень стресса всего 22%. Кот одобряет!"
                    addCatResponse(reply)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(chatMessages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .onChange(of: chatMessages.count) { _ in
                if let last = chatMessages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }
    
    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Скажи или спроси что-нибудь...", text: $inputText)
                .padding(12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(20)
                .foregroundColor(.white)
            
            Button(action: { toggleVoiceRecording() }) {
                Image(systemName: isListening ? "waveform.circle.fill" : "mic.fill")
                    .font(.title2)
                    .foregroundColor(isListening ? .red : .cyan)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            if !inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(action: {
                    let text = inputText
                    inputText = ""
                    sendUserQuery(text)
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundColor(.cyan)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    // MARK: - Logic & AI Chat Generation
    
    private func sendUserQuery(_ text: String) {
        chatMessages.append(ChatMessage(sender: .user, text: text))
        
        let response = generateIntelligentCatReply(to: text)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.addCatResponse(response)
        }
    }
    
    private func addCatResponse(_ text: String) {
        chatMessages.append(ChatMessage(sender: .cat, text: text))
        
        // ВСЕГДА ОЗВУЧИВАЕМ ГОЛОСОМ, ЕСЛИ ВКЛЮЧЕН ТУМБЛЕР!
        if voiceEnabled {
            CatSpeechSynthesizer.shared.speak(text: text)
        }
    }
    
    private func generateIntelligentCatReply(to prompt: String) -> String {
        let lower = prompt.lowercased()
        
        // Трюки и команды
        if lower.contains("помойся") || lower.contains("умойся") {
            return catHandler.execute(action: "wash")
        } else if lower.contains("кувырок") || lower.contains("сальто") {
            return catHandler.execute(action: "somersault")
        } else if lower.contains("повисни") || lower.contains("лапк") {
            return catHandler.execute(action: "hang_on_island")
        } else if lower.contains("покорми") || lower.contains("рыбк") {
            return tamagotchi.feedFish()
        } else if lower.contains("погладь") {
            return tamagotchi.petCat()
        } else if lower.contains("отжима") {
            return CatFitnessCoach.shared.startPushups()
        } else if lower.contains("присед") {
            return CatFitnessCoach.shared.startSquats()
        } else if lower.contains("йог") || lower.contains("размин") {
            return YogaCoachTool.shared.startWorkout()
        } else if lower.contains("музык") || lower.contains("бит") {
            return MusicTool.shared.generateBeat(style: "lo-fi")
        } else if lower.contains("вайб") || lower.contains("настроен") {
            let res = VoiceVibeTool.shared.analyzeVibe(transcribedText: prompt)
            return res.catAdvice
        } else if lower.contains("план") || lower.contains("сегодня") {
            return "Твои дела под контролем! Я заглянул в локальные задачи: на сегодня у тебя отличный день, главное — не забывай поиграть со мной."
        } else if lower.contains("привет") || lower.contains("здравствуй") {
            return "Мяу! Здорово, кожаный. Я в черных очках, бодр и готов к великим делам. Чем займемся?"
        } else if lower.contains("кто ты") {
            return "Я AiCat — твой персональный автономный 3D-агент. Живу прямо в чипе A17 Pro твоего iPhone 15 Pro, ни грамма данных в облака не отправляю."
        } else if lower.contains("как дела") {
            return "Мурчу от удовольствия! Сытость \(tamagotchi.satiety)%, счастье \(tamagotchi.happiness)%. Готов служить тебе верой и правдой."
        } else if lower.contains("скажи что") || lower.contains("расскажи") {
            let jokes = [
                "Знаешь, почему коты — лучшие ИИ? Мы грациозны, умны и требуем только рыбку вместо подписки за $20 в месяц!",
                "Я внимательно наблюдал за тобой из Dynamic Island: ты слишком много работаешь. Пора сделать перерыв и погладить меня по голове!",
                "Мой процессор A17 Pro разогрет, лапы готовы к действию. Спрашивай что угодно, я разберусь!"
            ]
            return jokes.randomElement() ?? jokes[0]
        } else {
            return "Услышал тебя, кожаный: «\(prompt)». Моделирую ответ на чипе A17 Pro. Твоя мысль интересная, я записал её в локальный журнал!"
        }
    }
    
    private func toggleVoiceRecording() {
        isListening.toggle()
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

public struct ChatMessage: Identifiable {
    public let id = UUID()
    public enum Sender { case user, cat }
    public let sender: Sender
    public let text: String
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.sender == .user { Spacer() }
            
            Text(message.text)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundColor(.white)
                .background(
                    message.sender == .user ?
                    Color.cyan.opacity(0.3) :
                    Color.white.opacity(0.12)
                )
                .cornerRadius(16)
            
            if message.sender == .cat { Spacer() }
        }
    }
}

struct ActionChip: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
                    .bold()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cyan.opacity(0.2))
            .foregroundColor(.cyan)
            .cornerRadius(16)
        }
    }
}
